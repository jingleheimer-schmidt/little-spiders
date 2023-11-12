
--[[ factorio mod little spiders control script created by asher_sky --]]

local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid
local new_task_id = general_util.new_task_id

local color_util = require("util/colors")
local color = color_util.color

local rendering_util = require("util/rendering")
local draw_line = rendering_util.draw_line
local draw_dotted_line = rendering_util.draw_dotted_line
local draw_circle = rendering_util.draw_circle
local debug_print = rendering_util.debug_print
local destroy_associated_renderings = rendering_util.destroy_associated_renderings

local math_util = require("util/math")
local maximum_length = math_util.maximum_length
local minimum_length = math_util.minimum_length
local rotate_around_target = math_util.rotate_around_target
local random_position_on_circumference = math_util.random_position_on_circumference
local distance = math_util.distance

local path_request_util = require("util/path_request")
local request_spider_path_to_entity = path_request_util.request_spider_path_to_entity
local request_spider_path_to_position = path_request_util.request_spider_path_to_position
local request_spider_path_to_player = path_request_util.request_spider_path_to_player

local function on_init()
  global.spiders = {} --[[@type table<integer, table<uuid, LuaEntity>>]]
  global.available_spiders = {} --[[@type table<integer, table<integer, LuaEntity[]>>]]
  global.tasks = {
    by_entity = {}, --[[@type table<uuid, task_data>]]
    by_spider = {}, --[[@type table<uuid, task_data>]]
    nudges = {}, --[[@type table<uuid, task_data>]]
  }
  global.spider_path_requests = {} --[[@type table<integer, path_request_data>]]
  global.spider_path_to_position_requests = {} --[[@type table<integer, position_path_request_data>]]
  global.spider_leg_collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask
  global.previous_controller = {} --[[@type table<integer, defines.controllers>]]
  global.previous_player_entity = {} --[[@type table<integer, uuid>]]
  global.previous_color = {} --[[@type table<integer, Color>]]
end
script.on_init(on_init)

local function on_configuration_changed(event)
  global.spiders = global.spiders or {}
  global.available_spiders = global.available_spiders or {}
  global.tasks = global.tasks or {}
  global.tasks.by_entity = global.tasks.by_entity or {}
  global.tasks.by_spider = global.tasks.by_spider or {}
  global.tasks.nudges = global.tasks.nudges or {}
  global.spider_path_requests = global.spider_path_requests or {}
  global.spider_path_to_position_requests = global.spider_path_to_position_requests or {}
  global.spider_leg_collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask
  global.previous_controller = global.previous_controller or {}
  global.previous_player_entity = global.previous_player_entity or {}
  global.previous_color = global.previous_color or {}
end
script.on_configuration_changed(on_configuration_changed)

---@param player LuaPlayer
---@return LuaEntity?
local function get_player_entity(player)
  return player.character or player.vehicle or nil
end

---@param event EventData.on_built_entity
local function on_spider_created(event)
  local spider = event.created_entity
  local player_index = event.player_index
  local surface_index = spider.surface_index
  local player = game.get_player(player_index)

  if player then
    local player_entity = get_player_entity(player)
    if player_entity then
      spider.color = player.color
      spider.follow_target = player_entity
      local uuid = entity_uuid(spider)
      global.spiders[player_index] = global.spiders[player_index] or {}
      global.spiders[player_index][uuid] = spider
      global.available_spiders[player_index] = global.available_spiders[player_index] or {}
      global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
      table.insert(global.available_spiders[player_index][surface_index], spider)
    end
  end
end

local filter = { { filter = "name", name = "little-spidertron" } }
script.on_event(defines.events.on_built_entity, on_spider_created, filter)

---@param event EventData.on_entity_destroyed
local function on_spider_destroyed(event)
  local unit_number = event.unit_number
  if not unit_number then return end
  for player_index, spiders in pairs(global.spiders) do
    if spiders[unit_number] then
      spiders[unit_number] = nil
      break
    end
  end
  for player_index, spider_data in pairs(global.available_spiders) do
    for surface_index, spiders in pairs(spider_data) do
      for i, spider in pairs(spiders) do
        if not spider.valid then
          table.remove(spiders, i)
        end
      end
    end
  end
  local spider_task = global.tasks.by_spider[unit_number]
  if spider_task then
    local entity_id = spider_task.entity_id
    global.tasks.by_entity[entity_id] = nil
    global.tasks.by_spider[unit_number] = nil
  end
end

script.on_event(defines.events.on_entity_destroyed, on_spider_destroyed)

---@param player LuaPlayer
local function relink_following_spiders(player)
  local player_index = player.index
  local spiders = global.spiders[player_index]
  if not spiders then return end
  local player_entity = get_player_entity(player)
  for _, spider in pairs(spiders) do
    if spider.valid then
      if spider.surface_index == player.surface_index then
        local destinations = spider.autopilot_destinations
        if player_entity then
          spider.color = player.color
          spider.follow_target = player_entity
        else
          spider.color = color.white
          spider.follow_target = nil
        end
        local was_nudged = global.tasks.nudges[entity_uuid(spider)]
        if destinations and not was_nudged then
          -- re-add the destinations to the autopilot since they were cleared when assigning a new follow target
          for _, destination in pairs(destinations) do
            spider.add_autopilot_destination(destination)
          end
        end
      end
    end
  end
end

---@param event EventData.on_player_changed_surface
local function on_player_changed_surface(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  relink_following_spiders(player)
end

script.on_event(defines.events.on_player_changed_surface, on_player_changed_surface)

---@param event EventData.on_player_driving_changed_state
local function on_player_driving_changed_state(event)
  local player_index = event.player_index
  local player = game.get_player(player_index)
  if not player then return end
  relink_following_spiders(player)
end

script.on_event(defines.events.on_player_driving_changed_state, on_player_driving_changed_state)

---@param spidertron LuaEntity
---@param spider_id string|integer
---@param player LuaPlayer
local function nudge_spidertron(spidertron, spider_id, player)
  local autopilot_destinations = spidertron.autopilot_destinations
  local destination_count = #autopilot_destinations
  local current_position = spidertron.position
  local new_position = nil
  local surface = spidertron.surface
  for i = 1, 5 do
    if new_position then break end
    local nearby_position = random_position_on_circumference(current_position, 5)
    local non_colliding_position = surface.find_tiles_filtered({
      position = nearby_position,
      radius = 2,
      collision_mask = { "water-tile" },
      invert = true,
      limit = 1,
    })
    new_position = non_colliding_position and non_colliding_position[1] and non_colliding_position[1].position --[[@as MapPosition]]
  end
  new_position = new_position or random_position_on_circumference(current_position, 5)
  if destination_count >= 1 then
    local final_destination = autopilot_destinations[destination_count]
    if destination_count > 1 then
      autopilot_destinations[1] = new_position
    else
      table.insert(autopilot_destinations, 1, new_position)
    end
    request_spider_path_to_position(surface, spider_id, spidertron, new_position, final_destination, player)
    spidertron.autopilot_destination = nil
    for _, destination in pairs(autopilot_destinations) do
      spidertron.add_autopilot_destination(destination)
    end
  else
    spidertron.add_autopilot_destination(new_position)
    request_spider_path_to_position(surface, spider_id, spidertron, new_position, player.position, player)
  end
end

---@param spider_id uuid
---@param entity_id uuid
---@param spider LuaEntity
---@param player LuaPlayer
---@param player_entity LuaEntity?
local function abandon_task(spider_id, entity_id, spider, player, player_entity)
  destroy_associated_renderings(spider_id)
  global.tasks.by_entity[entity_id] = nil
  global.tasks.by_spider[spider_id] = nil
  local player_index = player.index
  local surface_index = player.surface_index
  global.available_spiders[player_index] = global.available_spiders[player_index] or {}
  global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
  table.insert(global.available_spiders[player_index][surface_index], spider)
  spider.color = player.color
  spider.follow_target = player_entity
end

---@param spider_id uuid
---@param entity_id uuid
---@param spider LuaEntity
---@param player LuaPlayer
---@param player_entity LuaEntity?
local function complete_task(spider_id, entity_id, spider, player, player_entity)
  destroy_associated_renderings(spider_id)
  global.tasks.by_entity[entity_id] = nil
  global.tasks.by_spider[spider_id] = nil
  local player_index = player.index
  local surface_index = player.surface_index
  global.available_spiders[player_index] = global.available_spiders[player_index] or {}
  global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
  table.insert(global.available_spiders[player_index][surface_index], spider)
  spider.color = player.color
  spider.follow_target = player_entity
end

---@param event EventData.on_spider_command_completed
local function on_spider_command_completed(event)
  local spider = event.vehicle
  if not (spider.name == "little-spidertron") then return end
  local destinations = spider.autopilot_destinations
  local destination_count = #destinations
  local spider_id = entity_uuid(spider)
  if destination_count == 0 then
    local task_data = global.tasks.nudges[spider_id]
    if task_data then
      local player = task_data.player
      local player_entity = get_player_entity(player)
      spider.color = player.color
      spider.follow_target = player_entity
      global.tasks.nudges[spider_id] = nil
      debug_print("nudge completed", player, spider, color.green)
    else
      task_data = global.tasks.by_spider[spider_id]
      if task_data then
        local entity = task_data.entity
        local entity_id = task_data.entity_id
        local player = task_data.player
        local task_type = task_data.task_type

        if not player.valid then
          abandon_task(spider_id, entity_id, spider, player)
          debug_print("task abandoned: no valid player", player, spider, color.red)
          return
        end

        local player_entity = get_player_entity(player)

        if not (entity and entity.valid) then
          abandon_task(spider_id, entity_id, spider, player, player_entity)
          debug_print("task abandoned: no valid entity", player, spider, color.red)
          return
        end

        if not (player_entity and player_entity.valid) then
          abandon_task(spider_id, entity_id, spider, player, player_entity)
          debug_print("task abandoned: no valid player entity", player, spider, color.red)
          return
        end

        local inventory = player_entity.get_inventory(defines.inventory.character_main)

        if not (inventory and inventory.valid) then
          abandon_task(spider_id, entity_id, spider, player, player_entity)
          debug_print("task abandoned: no valid inventory", player, spider, color.red)
          return
        end

        local retry_task = false

        if task_type == "deconstruct" then
          local entity_position = entity.position
          if entity.to_be_deconstructed() then
            local prototype = entity.prototype
            local products = prototype and prototype.mineable_properties.products
            local result_when_mined = (entity.type == "item-entity" and entity.stack) or (products and products[1] and products[1].name) or nil
            local space_in_stack = result_when_mined and inventory.can_insert(result_when_mined)
            if result_when_mined and space_in_stack then
              while entity.valid do
                local count = 0
                if inventory.can_insert(result_when_mined) then
                  local result = entity.mine { inventory = inventory, force = false, ignore_minable = false, raise_destroyed = true }
                  count = count + 1
                  if not result then break end
                else break
                end
                if count > 4 then break end
              end
              draw_line(spider.surface, player_entity, spider, player.color, 20)
              global.tasks.by_entity[entity_id].status = "completed"
              global.tasks.by_spider[spider_id].status = "completed"
              complete_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("deconstruct task completed", player, spider, color.green)
            else
              abandon_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("task abandoned: no space in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider_id, entity_id, spider, player, player_entity)
            debug_print("task abandoned: entity no longer needs to be deconstructed", player, spider, color.red)
          end

        elseif task_type == "revive" then
          local items = entity.ghost_prototype.items_to_place_this
          local item_stack = items and items[1]
          if item_stack then
            local item_name = item_stack.name
            local item_count = item_stack.count or 1
            if inventory.get_item_count(item_name) >= item_count then
              local dictionary, revived_entity = entity.revive({ return_item_request_proxy = false, raise_revive = true})
              if revived_entity then
                inventory.remove(item_stack)
                draw_line(spider.surface, player_entity, spider, player.color, 20)
                global.tasks.by_entity[entity_id].status = "completed"
                global.tasks.by_spider[spider_id].status = "completed"
                complete_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("revive task completed", player, spider, color.green)
              else
                local ghost_position = entity.position
                local spider_position = spider.position
                for i = 1, 45, 5 do
                  local rotatated_position = rotate_around_target(ghost_position, spider_position, i, maximum_length(entity.bounding_box))
                  spider.add_autopilot_destination(rotatated_position)
                end
                retry_task = true
                debug_print("revive task failed: retrying", player, spider, color.red)
              end
            else
              abandon_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("task abandoned: not enough items in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider_id, entity_id, spider, player, player_entity)
            debug_print("task abandoned: no items_to_place_this", player, spider, color.red)
          end

        elseif task_type == "upgrade" then
          if entity.to_be_upgraded() then
            local upgrade_target = entity.get_upgrade_target()
            local items = upgrade_target and upgrade_target.items_to_place_this
            local item_stack = items and items[1]
            if upgrade_target and item_stack then
              local item_name = item_stack.name
              local item_count = item_stack.count or 1
              if inventory.get_item_count(item_name) >= item_count then
                local entity_type = entity.type
                ---@diagnostic disable:missing-fields
                local upgraded_entity = entity.surface.create_entity {
                  name = upgrade_target.name,
                  position = entity.position,
                  direction = entity.get_upgrade_direction(),
                  player = player,
                  fast_replace = true,
                  force = entity.force,
                  spill = true,
                  type = (entity_type == "underground-belt" and entity.belt_to_ground_type) or
                  ((entity_type == "loader" or entity_type == "loader-1x1") and entity.loader_type) or nil,
                  raise_built = true,
                }
                ---@diagnostic enable:missing-fields
                if upgraded_entity then
                  inventory.remove(item_stack)
                  draw_line(spider.surface, player_entity, spider, player.color, 20)
                  global.tasks.by_entity[entity_id].status = "completed"
                  global.tasks.by_spider[spider_id].status = "completed"
                  complete_task(spider_id, entity_id, spider, player, player_entity)
                  debug_print("upgrade task completed", player, spider, color.green)
                else
                  local upgrade_position = entity.position
                  local spider_position = spider.position
                  local length = maximum_length(entity.bounding_box) + 1
                  for i = 1, 45, 5 do
                    local rotatated_position = rotate_around_target(upgrade_position, spider_position, i, length)
                    spider.add_autopilot_destination(rotatated_position)
                  end
                  retry_task = true
                  debug_print("upgrade task failed: retrying", player, spider, color.red)
                end
              else
                abandon_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("task abandoned: not enough items in inventory", player, spider, color.red)
              end
            else
              abandon_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("task abandoned: no upgrade_target or item_stack", player, spider, color.red)
            end
          else
            abandon_task(spider_id, entity_id, spider, player, player_entity)
            debug_print("task abandoned: entity no longer needs to be upgraded", player, spider, color.red)
          end
        elseif task_type == "item_proxy" then
          local proxy_target = entity.proxy_target
          if proxy_target then
            local items = entity.item_requests
            local item_name, item_count = next(items)
            if inventory.get_item_count(item_name) >= item_count then
              local item_to_insert = { name = item_name, count = item_count }
              local request_fulfilled = false
              if proxy_target.can_insert(item_to_insert) then
                proxy_target.insert(item_to_insert)
                inventory.remove(item_to_insert)
                entity.destroy()
                request_fulfilled = true
              end
              if request_fulfilled then
                complete_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("item_proxy task completed", player, spider, color.green)
              else
                abandon_task(spider_id, entity_id, spider, player, player_entity)
                debug_print("proxy task abandoned: could not insert", player, spider, color.red)
              end
            else
              abandon_task(spider_id, entity_id, spider, player, player_entity)
              debug_print("proxy task abandoned: not enough items in inventory", player, spider, color.red)
            end
          else
            abandon_task(spider_id, entity_id, spider, player, player_entity)
            debug_print("proxy task abandoned: no proxy_target", player, spider, color.red)
          end
        end
      end
    end
  else
    local nudge_task_data = global.tasks.nudges[spider_id]
    if not nudge_task_data then return end
    local active_task = global.tasks.by_spider[spider_id]
    if active_task then return end
    local final_destination = destinations[destination_count]
    local player = nudge_task_data.player
    local player_entity = get_player_entity(player)
    if not player.valid then
      global.tasks.nudges[spider_id] = nil
      return
    end
    if not (player_entity and player_entity.valid) then
      global.tasks.nudges[spider_id] = nil
      return
    end
    local distance_to_player = distance(player_entity.position, final_destination)
    if distance_to_player > 15 then
      request_spider_path_to_position(player.surface, spider_id, spider, spider.position, player.position, player)
    end
  end
end

script.on_event(defines.events.on_spider_command_completed, on_spider_command_completed)

  --[[ 
  This function is called when a spider finishes its path request. It updates the spider's status and 
  performs the necessary actions based on the path request result. 
  --]]
---@param event EventData.on_script_path_request_finished
local function on_script_path_request_finished(event)
  local path_request_id = event.id
  local path = event.path
  if global.spider_path_requests[path_request_id] then
    local spider = global.spider_path_requests[path_request_id].spider
    local entity = global.spider_path_requests[path_request_id].entity
    local player = global.spider_path_requests[path_request_id].player
    local spider_id = global.spider_path_requests[path_request_id].spider_id
    local entity_id = global.spider_path_requests[path_request_id].entity_id
    local player_entity = get_player_entity(player)
    if (spider and spider.valid and entity and entity.valid and player_entity and player_entity.valid) then

      -- Set the spider's follow target to the player's entity
      spider.follow_target = player_entity

      if path then
        -- If a path was found, set the spider's autopilot destination to nil and update its color based on the task type
        spider.autopilot_destination = nil
        local task_type = global.tasks.by_entity[entity_id].task_type
        local task_color = (task_type == "deconstruct" and color.red) or (task_type == "revive" and color.blue) or (task_type == "upgrade" and color.green) or color.white
        spider.color = task_color or color.black

        -- Add each waypoint in the path as an autopilot destination for the spider
        for _, waypoint in pairs(path) do
          spider.add_autopilot_destination(waypoint.position)
        end

        -- Update the task status and draw a line between the spider and the entity
        global.tasks.by_entity[entity_id].status = "on_the_way"
        global.tasks.by_spider[spider_id].status = "on_the_way"
        local render_id = draw_line(spider.surface, entity, spider, task_color)
        if render_id then
          global.tasks.by_entity[entity_id].render_ids[render_id] = true
          global.tasks.by_spider[spider_id].render_ids[render_id] = true
        end

      else
        -- If no path was found, add a random nearby destination for the spider autopilot and update the available spiders table
        if math.random() < 0.125 then
          spider.add_autopilot_destination(random_position_on_circumference(spider.position, 3))
        end
        local player_index = player.index
        local surface_index = player.surface_index
        global.available_spiders[player_index] = global.available_spiders[player_index] or {}
        global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
        table.insert(global.available_spiders[player_index][surface_index], spider)
        spider.color = player.color

        -- Draw dotted lines between the spider and the entity to indicate failure to find a path
        draw_dotted_line(spider.surface, spider, entity, color.white, 30)
        draw_dotted_line(spider.surface, spider, entity, color.red, 30, true)

        -- Destroy the render IDs associated with the spider and entity, and remove the task from the global tasks table
        destroy_associated_renderings(spider_id)
        global.tasks.by_entity[entity_id] = nil
        global.tasks.by_spider[spider_id] = nil
      end
    end
    global.spider_path_requests[path_request_id] = nil
  elseif global.spider_path_to_position_requests[path_request_id] then
    local spider = global.spider_path_to_position_requests[path_request_id].spider
    local final_position = global.spider_path_to_position_requests[path_request_id].final_position
    local start_position = global.spider_path_to_position_requests[path_request_id].start_position
    local player = global.spider_path_to_position_requests[path_request_id].player
    local spider_id = global.spider_path_to_position_requests[path_request_id].spider_id
    local player_entity = get_player_entity(player)
    if (spider and spider.valid and player_entity and player_entity.valid) then

      -- Set the spider's follow target to the player's entity
      spider.follow_target = player_entity
      local surface = spider.surface

      if path then
        -- If a path was found, set the spider's autopilot destination to nil and draw lines between the spider and each waypoint in the path
        spider.autopilot_destination = nil
        local previous_position = spider.position
        for _, waypoint in pairs(path) do
          local new_position = waypoint.position
          spider.add_autopilot_destination(waypoint.position)
          draw_circle(surface, new_position, color.white, 0.33, 90)
          if previous_position then
            draw_line(surface, previous_position, new_position, color.white, 90)
          end
          previous_position = new_position
        end

        -- Add the task to the nudges table and update its status
        local render_id = draw_line(spider.surface, final_position, spider, color.white, 10)
        global.tasks.nudges[spider_id] = {
          spider = spider,
          spider_id = spider_id,
          task_type = "nudge",
          player = player,
          entity = player_entity,
          entity_id = entity_uuid(player_entity),
          status = "on_the_way",
          render_ids = {},
        }
      else
        -- If no path was found, add a random autopilot destination for the spider and update the available spiders table
        if math.random() < 0.125 then
          spider.add_autopilot_destination(random_position_on_circumference(spider.position, 3))
        end
        -- local player_index = player.index
        -- local surface_index = player.surface_index
        -- global.available_spiders[player_index] = global.available_spiders[player_index] or {}
        -- global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
        -- table.insert(global.available_spiders[player_index][surface_index], spider)
        spider.color = player.color

        -- Draw dotted lines between the spider and the start and final positions to indicate failure to find a path
        draw_dotted_line(surface, spider, start_position, color.white, 30)
        draw_dotted_line(surface, spider, start_position, color.red, 30, true)
        draw_dotted_line(surface, start_position, final_position, color.white, 30)
        draw_dotted_line(surface, start_position, final_position, color.red, 30, true)
      end
    end
    global.spider_path_to_position_requests[path_request_id] = nil
  end
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param type string
---@param entity_id string|integer
---@param entity LuaEntity
---@param spider LuaEntity
---@param player LuaPlayer
---@param surface LuaSurface
local function assign_new_task(type, entity_id, entity, spider, player, surface)
  local spider_id = entity_uuid(spider)
  spider.color = color.white
  request_spider_path_to_entity(surface, spider_id, spider, entity_id, entity, player)
  local task_data = {
    entity = entity,
    entity_id = entity_id,
    spider = spider,
    spider_id = spider_id,
    task_type = type,
    player = player,
    status = "path_requested",
    render_ids = {},
  }
  global.tasks.by_entity[entity_id] = task_data
  global.tasks.by_spider[spider_id] = task_data
  global.tasks.nudges[spider_id] = nil

  debug_print("task assigned", player, spider)
end

---@param event EventData.on_tick
local function on_tick(event)
  for _, player in pairs(game.connected_players) do
    local player_index = player.index
    local surface_index = player.surface_index
    global.available_spiders[player_index] = global.available_spiders[player_index] or {}
    global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
    if #global.available_spiders[player_index][surface_index] == 0 then goto next_player end

    local controller_type = player.controller_type
    global.previous_controller[player_index] = global.previous_controller[player_index] or controller_type
    if global.previous_controller[player_index] ~= controller_type then
      relink_following_spiders(player)
      global.previous_controller[player_index] = controller_type
    end

    local player_entity = get_player_entity(player)

    if not (player_entity and player_entity.valid) then goto next_player end

    local player_entity_id = entity_uuid(player_entity)
    global.previous_player_entity[player_index] = global.previous_player_entity[player_index] or player_entity_id
    if global.previous_player_entity[player_index] ~= player_entity_id then
      relink_following_spiders(player)
      global.previous_player_entity[player_index] = player_entity_id
    end

    global.previous_color[player_index] = global.previous_color[player_index] or player.color
    local current = player.color
    local previous = global.previous_color[player_index]
    if (previous.r ~= current.r) or (previous.g ~= current.g) or (previous.b ~= current.b) or (previous.a ~= current.a) then
      local spiders = global.spiders[player_index]
      if spiders then
        for spider_id, spider in pairs(spiders) do
          if spider.valid then
            spider.color = current
          else
            spiders[spider_id] = nil
          end
        end
      end
      global.previous_color[player_index] = current
    end

    local surface = player_entity.surface
    local inventory = player.get_main_inventory()
    local character_position_x = player_entity.position.x
    local character_position_y = player_entity.position.y
    local area = {
      { character_position_x - 20, character_position_y - 20 },
      { character_position_x + 20, character_position_y + 20 },
    }
    local to_be_deconstructed = surface.find_entities_filtered({
      area = area,
      to_be_deconstructed = true,
    })
    local decon_ordered = false
    local revive_ordered = false
    local upgrade_ordered = false
    local item_proxy_ordered = false

    while #global.available_spiders[player_index][surface_index] > 0 do
      if not upgrade_ordered then
        local entity_count = #to_be_deconstructed
        for i = 1, entity_count do
          local index = math.random(1, entity_count)
          local decon_entity = to_be_deconstructed[index]
          if decon_entity then
            if #global.available_spiders[player_index][surface_index] == 0 then break end
            local entity_id = entity_uuid(decon_entity)
            if not global.tasks.by_entity[entity_id] then
              local prototype = decon_entity.prototype
              local products = prototype and prototype.mineable_properties.products
              local result_when_mined = (decon_entity.type == "item-entity" and decon_entity.stack) or (products and products[1] and products[1].name) or nil
              local space_in_stack = result_when_mined and inventory and inventory.can_insert(result_when_mined)
              if space_in_stack then
                local spider = table.remove(global.available_spiders[player_index][surface_index])
                if spider then
                  assign_new_task("deconstruct", entity_id, decon_entity, spider, player, surface)
                  decon_ordered = true
                end
              else break
              end
            end
            to_be_deconstructed[index] = nil
          end
        end
      end

      if not decon_ordered then
        local to_be_revived = surface.find_entities_filtered({
          area = area,
          type = "entity-ghost",
        })
        local entity_count = #to_be_revived
        for i = 1, entity_count do
          local index = math.random(1, entity_count)
          local revive_entity = to_be_revived[index]
          if revive_entity then
            if #global.available_spiders[player_index][surface_index] == 0 then break end
            local entity_id = entity_uuid(revive_entity)
            if not global.tasks.by_entity[entity_id] then
              local items = revive_entity.ghost_prototype.items_to_place_this
              local item_stack = items and items[1]
              if item_stack then
                local item_name = item_stack.name
                local item_count = item_stack.count or 1
                if inventory and inventory.get_item_count(item_name) >= item_count then
                  local spider = table.remove(global.available_spiders[player_index][surface_index])
                  if spider then
                    assign_new_task("revive", entity_id, revive_entity, spider, player, surface)
                    revive_ordered = true
                  end
                end
              end
            end
            to_be_revived[index] = nil
          end
        end
      end

      if not revive_ordered then
        local to_be_upgraded = surface.find_entities_filtered({
          area = area,
          to_be_upgraded = true,
        })
        local entity_count = #to_be_upgraded
        for i = 1, entity_count do
          local index = math.random(1, entity_count)
          local upgrade_entity = to_be_upgraded[index]
          if upgrade_entity then
            if #global.available_spiders[player_index][surface_index] == 0 then break end
            local entity_id = entity_uuid(upgrade_entity)
            if not global.tasks.by_entity[entity_id] then
              local upgrade_target = upgrade_entity.get_upgrade_target()
              local items = upgrade_target and upgrade_target.items_to_place_this
              local item_stack = items and items[1]
              if upgrade_target and item_stack then
                local item_name = item_stack.name
                local item_count = item_stack.count or 1
                if inventory and inventory.get_item_count(item_name) >= item_count then
                  local spider = table.remove(global.available_spiders[player_index][surface_index])
                  if spider then
                    assign_new_task("upgrade", entity_id, upgrade_entity, spider, player, surface)
                    upgrade_ordered = true
                  end
                end
              end
            end
            to_be_upgraded[index] = nil
          end
        end
      end

      if not upgrade_ordered then
        local item_proxy_requests = surface.find_entities_filtered({
          area = area,
          type = "item-request-proxy",
        })
        local entity_count = #item_proxy_requests
        for i = 1, entity_count do
          local index = math.random(1, entity_count)
          local item_proxy_request = item_proxy_requests[index]
          if item_proxy_request then
            if #global.available_spiders[player_index][surface_index] == 0 then break end
            local entity_id = entity_uuid(item_proxy_request)
            if not global.tasks.by_entity[entity_id] then
              local proxy_target = item_proxy_request.proxy_target
              local items = item_proxy_request.item_requests
              local item_name, item_count = next(items)
              if inventory and inventory.get_item_count(item_name) >= item_count then
                local spider = table.remove(global.available_spiders[player_index][surface_index])
                if spider then
                  assign_new_task("item_proxy", entity_id, item_proxy_request, spider, player, surface)
                  item_proxy_ordered = true
                end
              end
            end
            item_proxy_requests[index] = nil
          end
        end
      end
      break
    end

    for spider_id, spider in pairs(global.spiders[player_index]) do
      if spider.speed == 0 then
        if distance(spider.position, player.position) > 25 then
          nudge_spidertron(spider, spider_id, player)
        end
      end
    end
    ::next_player::
  end
end

script.on_nth_tick(45, on_tick)

local function toggle_debug()
  global.debug = not global.debug
  for _, player in pairs(game.connected_players) do
    player.print("Little Spiders debug mode " .. (global.debug and "enabled" or "disabled"))
  end
end

local function add_commands()
  commands.add_command("little-spider-debug", "- toggles debug mode for the little spiders, showing task targets and path request renderings", toggle_debug)
end

script.on_init(add_commands)
script.on_load(add_commands)
