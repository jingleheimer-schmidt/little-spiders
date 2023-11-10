
-- /c local function request_ammo(event)
--   local entity = event.created_entity or event.entity --[[@type LuaEntity]]
--   if not (entity and entity.valid) then return end
--   if entity.type ~= "ammo-turret" then return end
--   if entity.force.name ~= "player" then return end
--   entity.surface.create_entity{
--     name = "item-request-proxy",
--     position = entity.position,
--     force = entity.force,
--     target = entity,
--     modules = {["firearm-magazine"] = 25},
--     raise_built = true
--   }
-- end
-- script.on_event(defines.events.on_built_entity, request_ammo)
-- script.on_event(defines.events.on_robot_built_entity, request_ammo)
-- script.on_event(defines.events.script_raised_built, request_ammo)

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

local math_util = require("util/math")
local maximum_length = math_util.maximum_length
local minimum_length = math_util.minimum_length
local rotate_around_target = math_util.rotate_around_target
local random_position_on_circumference = math_util.random_position_on_circumference

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
  global.previous_entity = {} --[[@type table<integer, uuid>]]
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
  global.previous_entity = global.previous_entity or {}
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

  script.register_on_entity_destroyed(spider)
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
  local character = player.character
  local vehicle = player.vehicle
  for _, spider in pairs(spiders) do
    if spider.valid then
      if spider.surface_index == player.surface_index then
        local destinations = spider.autopilot_destinations
        spider.follow_target = character or vehicle or nil
        local was_nudged = global.tasks.nudges[entity_uuid(spider)]
        if destinations and not was_nudged then
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

---@param event EventData.on_spider_command_completed
local function on_spider_reached_entity(event)
  local spider = event.vehicle
  if not (spider.name == "little-spidertron") then return end
  local destinations = spider.autopilot_destinations
  if #destinations == 0 then
    local spider_id = entity_uuid(spider)
    local task_data = global.tasks.nudges[spider_id]
    if task_data then
      local player = task_data.player
      local player_entity = get_player_entity(player)
      spider.color = player.color
      spider.follow_target = player_entity
      global.tasks.nudges[spider_id] = nil
    else
      task_data = global.tasks.by_spider[spider_id]
      if task_data then
        local entity = task_data.entity
        local entity_id = task_data.entity_id
        local player = task_data.player
        local task_type = task_data.task_type

        if not player.valid then return end
        local player_entity = get_player_entity(player)

        if not (player_entity and player_entity.valid and entity and entity.valid) then
          for render_id, bool in pairs(global.tasks.by_spider[spider_id].render_ids) do
            if bool then
              rendering.destroy(render_id)
            end
          end
          global.tasks.by_entity[entity_id] = nil
          global.tasks.by_spider[spider_id] = nil
          local player_index = player.index
          local surface_index = player.surface_index
          global.available_spiders[player_index] = global.available_spiders[player_index] or {}
          global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
          table.insert(global.available_spiders[player_index][surface_index], spider)
          spider.color = player.color
          spider.follow_target = player_entity
          return
        end

        local inventory = player_entity.get_main_inventory()

        if not (inventory and inventory.valid) then
          for render_id, bool in pairs(global.tasks.by_spider[spider_id].render_ids) do
            if bool then
              rendering.destroy(render_id)
            end
          end
          global.tasks.by_entity[entity_id] = nil
          global.tasks.by_spider[spider_id] = nil
          local player_index = player.index
          local surface_index = player.surface_index
          global.available_spiders[player_index] = global.available_spiders[player_index] or {}
          global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
          table.insert(global.available_spiders[player_index][surface_index], spider)
          spider.color = player.color
          spider.follow_target = player_entity
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
              local render_id = draw_line(spider.surface, player_entity, spider, player.color, 20)
              global.tasks.by_entity[entity_id].render_ids[render_id] = false
              global.tasks.by_spider[spider_id].render_ids[render_id] = false
              global.tasks.by_entity[entity_id].status = "completed"
              global.tasks.by_spider[spider_id].status = "completed"
            end
          end

        elseif task_type == "revive" then
          local items = entity.ghost_prototype.items_to_place_this
          local item_stack = items and items[1]
          if item_stack then
            local item_name = item_stack.name
            local item_count = item_stack.count or 1
            if inventory.get_item_count(item_name) >= item_count then
              local dictionary, revived_entity = entity.revive({ false, true })
              if revived_entity then
                inventory.remove(item_stack)
                local render_id = draw_line(spider.surface, player_entity, spider, player.color, 20)
                global.tasks.by_entity[entity_id].render_ids[render_id] = false
                global.tasks.by_spider[spider_id].render_ids[render_id] = false
                global.tasks.by_entity[entity_id].status = "completed"
                global.tasks.by_spider[spider_id].status = "completed"
              else
                local ghost_position = entity.position
                local spider_position = spider.position
                local distance = maximum_length(entity.bounding_box)
                for i = 1, 45, 5 do
                  local rotatated_position = rotate_around_target(ghost_position, spider_position, i, distance)
                  spider.add_autopilot_destination(rotatated_position)
                end
                retry_task = true
              end
            end
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
                  local render_id = draw_line(spider.surface, player_entity, spider, player.color, 20)
                  global.tasks.by_entity[entity_id].render_ids[render_id] = false
                  global.tasks.by_spider[spider_id].render_ids[render_id] = false
                  global.tasks.by_entity[entity_id].status = "completed"
                  global.tasks.by_spider[spider_id].status = "completed"
                else
                  local upgrade_position = entity.position
                  local spider_position = spider.position
                  local distance = maximum_length(entity.bounding_box) + 1
                  for i = 1, 45, 5 do
                    local rotatated_position = rotate_around_target(upgrade_position, spider_position, i, distance)
                    spider.add_autopilot_destination(rotatated_position)
                  end
                  retry_task = true
                end
              end
            end
          end
        end

        if not retry_task then
          for render_id, bool in pairs(global.tasks.by_spider[spider_id].render_ids) do
            if bool then
              rendering.destroy(render_id)
            end
          end
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
      end
    end
  end
end

script.on_event(defines.events.on_spider_command_completed, on_spider_reached_entity)

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

      spider.follow_target = player_entity

      if path then
        spider.autopilot_destination = nil
        local task_type = global.tasks.by_entity[entity_id].task_type
        local task_color = (task_type == "deconstruct" and color.red) or (task_type == "revive" and color.blue) or (task_type == "upgrade" and color.green) or color.white
        spider.color = task_color or color.black
        for _, waypoint in pairs(path) do
          spider.add_autopilot_destination(waypoint.position)
        end
        global.tasks.by_entity[entity_id].status = "on_the_way"
        global.tasks.by_spider[spider_id].status = "on_the_way"
        local render_id = draw_line(spider.surface, entity, spider, task_color)
        global.tasks.by_entity[entity_id].render_ids[render_id] = true
        global.tasks.by_spider[spider_id].render_ids[render_id] = true

      else
        if math.random() < 0.125 then
          spider.add_autopilot_destination(random_position_on_circumference(spider.position, 3))
        end
        local player_index = player.index
        local surface_index = player.surface_index
        global.available_spiders[player_index] = global.available_spiders[player_index] or {}
        global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
        table.insert(global.available_spiders[player_index][surface_index], spider)
        spider.color = player.color
        draw_dotted_line(spider.surface, spider, entity, color.white, 60)
        draw_dotted_line(spider.surface, spider, entity, color.red, 60, 2)
        for render_id, bool in pairs(global.tasks.by_spider[spider_id].render_ids) do
          if bool then
            rendering.destroy(render_id)
          end
        end
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

      spider.follow_target = player_entity
      local surface = spider.surface

      if path then
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
        if math.random() < 0.125 then
          spider.add_autopilot_destination(random_position_on_circumference(spider.position, 3))
        end
        local player_index = player.index
        local surface_index = player.surface_index
        global.available_spiders[player_index] = global.available_spiders[player_index] or {}
        global.available_spiders[player_index][surface_index] = global.available_spiders[player_index][surface_index] or {}
        table.insert(global.available_spiders[player_index][surface_index], spider)
        spider.color = player.color
        draw_dotted_line(surface, spider, start_position, color.white, 60)
        draw_dotted_line(surface, spider, start_position, color.red, 60, 1)
        draw_dotted_line(surface, start_position, final_position, color.white, 60)
        draw_dotted_line(surface, start_position, final_position, color.red, 60, 1)
      end
    end
    global.spider_path_to_position_requests[path_request_id] = nil
  end
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param surface LuaSurface
---@param spider_id string|integer
---@param spider LuaEntity
---@param entity_id string|integer
---@param entity LuaEntity
---@param player LuaPlayer
local function request_spider_path_to_entity(surface, spider_id, spider, entity_id, entity, player)
  local request_parameters = {
    bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = { "water-tile", "colliding-with-tiles-only", "consider-tile-transitions" },
    start = spider.position,
    goal = entity.position,
    force = spider.force,
    radius = maximum_length(entity.bounding_box) + 1,
    can_open_gates = true,
    path_resolution_modifier = -1,
    pathfind_flags = {
      cache = false,
      low_priority = true,
    },
  }
  local path_request_id = surface.request_path(request_parameters)
  global.spider_path_requests[path_request_id] = {
    spider = spider,
    spider_id = spider_id,
    entity = entity,
    entity_id = entity_id,
    player = player
  }
end

---@param surface LuaSurface
---@param spider_id string|integer
---@param spider LuaEntity
---@param starting_position MapPosition
---@param position MapPosition
---@param player LuaPlayer
local function request_spider_path_to_position(surface, spider_id, spider, starting_position, position, player)
  local request_parameters = {
    bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
    collision_mask = { "water-tile", "colliding-with-tiles-only", "consider-tile-transitions" },
    start = starting_position,
    goal = position,
    force = spider.force,
    radius = 3,
    can_open_gates = true,
    path_resolution_modifier = -1,
    pathfind_flags = {
      cache = false,
      low_priority = true,
    },
  }
  local path_request_id = surface.request_path(request_parameters)
  global.spider_path_to_position_requests[path_request_id] = {
    spider = spider,
    spider_id = spider_id,
    start_position = starting_position,
    final_position = position,
    player = player
  }
end

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
end

---@param pos_1 MapPosition
---@param pos_2 MapPosition
---@return number
local function distance(pos_1, pos_2)
  local x_1 = pos_1.x
  local y_1 = pos_1.y
  local x_2 = pos_2.x
  local y_2 = pos_2.y
  local x = x_1 - x_2
  local y = y_1 - y_2
  return math.sqrt(x * x + y * y)
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
    global.previous_entity[player_index] = global.previous_entity[player_index] or player_entity_id
    if global.previous_entity[player_index] ~= player_entity_id then
      relink_following_spiders(player)
      global.previous_entity[player_index] = player_entity_id
    end

    global.previous_color[player_index] = global.previous_color[player_index] or player.color
    local current = player.color
    local previous = global.previous_color[player_index]
    if (previous.r ~= current.r) or (previous.g ~= current.g) or (previous.b ~= current.b) or (previous.a ~= current.a) then
      local spiders = global.spiders[player_index]
      if spiders then
        for _, spider in pairs(spiders) do
          if spider.valid then
            spider.color = current
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
