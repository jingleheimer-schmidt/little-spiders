
--[[ factorio mod little spiders control script created by asher_sky --]]

local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid
local randomize_table = general_util.randomize_table
local random_pairs = general_util.random_pairs

local color_util = require("util/colors")
local color = color_util.color

local rendering_util = require("util/rendering")
local draw_line = rendering_util.draw_line

local math_util = require("util/math")
local maximum_length = math_util.maximum_length
local minimum_length = math_util.minimum_length
local rotate_around_target = math_util.rotate_around_target

local function on_init()
  global.spiders = {} --[[@type table<integer, table<uuid, LuaEntity>>]]
  global.available_spiders = {} --[[@type table<integer, table<integer, LuaEntity>>]]
  global.tasks = {
    by_entity = {}, --[[@type table<uuid, task_data>]]
    by_spider = {}, --[[@type table<uuid, task_data>]]
  }
  global.spider_path_requests = {} --[[@type table<integer, path_request_data>]]
end
script.on_init(on_init)

---@param event EventData.on_built_entity
local function on_spider_created(event)

  local spider = event.created_entity
  local player_index = event.player_index
  local player = game.get_player(player_index)
  local character = player and player.character

  if player and character then
    spider.color = player.color
    spider.follow_target = character
    local uuid = entity_uuid(spider)
    global.spiders[player_index] = global.spiders[player_index] or {}
    global.spiders[player_index][uuid] = spider
    global.available_spiders[player_index] = global.available_spiders[player_index] or {}
    table.insert(global.available_spiders[player_index], spider)
  end

  script.register_on_entity_destroyed(spider)

end

local filter = {{ filter = "name", name = "little-spidertron" }}
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
  for player_index, spiders in pairs(global.available_spiders) do
    for i, spider in pairs(spiders) do
      if not spider.valid then
        table.remove(spiders, i)
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

---@param event EventData.on_spider_command_completed
local function on_spider_reached_entity(event)
  local spider = event.vehicle
  if not (spider.name == "little-spidertron") then return end
  local destinations = spider.autopilot_destinations
  if #destinations == 0 then

    local spider_id = entity_uuid(spider)
    local task_data = global.tasks.by_spider[spider_id]
    local entity = task_data.entity
    local entity_id = task_data.entity_id
    local player = task_data.player
    local task_type = task_data.task_type
    local character = player and player.valid and player.character

    if not (character and character.valid and entity and entity.valid) then
      global.tasks.by_entity[entity_id] = nil
      global.tasks.by_spider[spider_id] = nil
      table.insert(global.available_spiders[player.index], spider)
      spider.color = player.color
      spider.follow_target = character and character.valid and character or nil
      return
    end

    local inventory = character.get_inventory(defines.inventory.character_main)

    if not (inventory and inventory.valid) then
      global.tasks.by_entity[entity_id] = nil
      global.tasks.by_spider[spider_id] = nil
      table.insert(global.available_spiders[player.index], spider)
      spider.color = player.color
      spider.follow_target = character
      return
    end

    local retry_task = false

    if task_type == "deconstruct" then
      local entity_position = entity.position
      while entity.valid do
        local result = entity.mine{inventory = inventory, force = true, ignore_minable = false, raise_destroyed = true}
      end
      local render_id = draw_line(spider.surface, character, spider, player.color, 20)
      global.tasks.by_entity[entity_id].render_ids[render_id] = true
      global.tasks.by_spider[spider_id].render_ids[render_id] = true
      global.tasks.by_entity[entity_id].status = "completed"
      global.tasks.by_spider[spider_id].status = "completed"

    elseif task_type == "revive" then
      local items = entity.ghost_prototype.items_to_place_this
      local item_stack = items and items[1]
      if item_stack then
        local item_name = item_stack.name
        local item_count = item_stack.count or 1
        if inventory.get_item_count(item_name) >= item_count then
          local dictionary, revived_entity = entity.revive({false, true})
          if revived_entity then
            inventory.remove(item_stack)
            local render_id = draw_line(spider.surface, character, spider, player.color, 20)
            global.tasks.by_entity[entity_id].render_ids[render_id] = true
            global.tasks.by_spider[spider_id].render_ids[render_id] = true
            global.tasks.by_entity[entity_id].status = "completed"
            global.tasks.by_spider[spider_id].status = "completed"
          else
            local ghost_position = entity.position
            local spider_position = spider.position
            local distance = maximum_length(entity.bounding_box) + 1
            for i = 1, 45, 5 do
              local rotatated_position = rotate_around_target(ghost_position, spider_position, i, distance)
              spider.add_autopilot_destination(rotatated_position)
            end
            retry_task = true
          end
        end
      end
      for render_id, bool in pairs(global.tasks.by_entity[entity_id].render_ids) do
        rendering.destroy(render_id)
      end

    elseif task_type == "upgrade" then
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
            type = (entity_type == "underground-belt" and entity.belt_to_ground_type) or ((entity_type == "loader" or entity_type == "loader-1x1") and entity.loader_type) or nil,
            raise_built = true,
          }
          ---@diagnostic enable:missing-fields
          if upgraded_entity then
            inventory.remove(item_stack)
            local render_id = draw_line(spider.surface, character, spider, player.color, 20)
            global.tasks.by_entity[entity_id].render_ids[render_id] = true
            global.tasks.by_spider[spider_id].render_ids[render_id] = true
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
      for render_id, bool in pairs(global.tasks.by_entity[entity_id].render_ids) do
        rendering.destroy(render_id)
      end
    end
    if not retry_task then
      global.tasks.by_entity[entity_id] = nil
      global.tasks.by_spider[spider_id] = nil
      table.insert(global.available_spiders[player.index], spider)
      spider.color = player.color
      spider.follow_target = character
    end
  end
end

script.on_event(defines.events.on_spider_command_completed, on_spider_reached_entity)

---@param event EventData.on_script_path_request_finished
local function on_script_path_request_finished(event)
  local path_request_id = event.id
  local path = event.path
  if not global.spider_path_requests[path_request_id] then return end
  local spider = global.spider_path_requests[path_request_id].spider
  local entity = global.spider_path_requests[path_request_id].entity
  local player = global.spider_path_requests[path_request_id].player
  local spider_id = global.spider_path_requests[path_request_id].spider_id
  local entity_id = global.spider_path_requests[path_request_id].entity_id
  local character = player.character
  if (spider and spider.valid and entity and entity.valid and character and character.valid) then
    if path then
      spider.autopilot_destination = nil
      for _, waypoint in pairs(path) do
        spider.add_autopilot_destination(waypoint.position)
      end
      global.tasks.by_entity[entity_id].status = "on_the_way"
      global.tasks.by_spider[spider_id].status = "on_the_way"
      local task_type = global.tasks.by_entity[entity_id].task_type
      local task_color = task_type == "deconstruct" and color.red or task_type == "revive" and color.blue or task_type == "upgrade" and color.green
      spider.color = task_color or color.black
      draw_line(spider.surface, entity, spider, task_color or color.white)
    else
      table.insert(global.available_spiders[player.index], spider)
      spider.color = player.color
      global.tasks.by_entity[entity_id] = nil
      global.tasks.by_spider[spider_id] = nil
    end
  end
  global.spider_path_requests[path_request_id] = nil
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param spider LuaEntity
---@param entity_id string|integer
---@param entity LuaEntity
---@param player LuaPlayer
local function request_spider_path(spider, entity_id, entity, player)
  local surface = spider.surface
  local request_parameters = {
    bounding_box = spider.bounding_box,
    collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask,
    start = spider.position,
    goal = entity.position,
    force = spider.force,
    radius = 5,
    can_open_gates = true,
    path_resolution_modifier = 1,
    pathfind_flags = {
      cache = false,
      low_priority = true,
    },
  }
  local path_request_id = surface.request_path(request_parameters)
  global.spider_path_requests[path_request_id] = {
    spider = spider,
    spider_id = entity_uuid(spider),
    entity = entity,
    entity_id = entity_id,
    player = player
  }
end

---@param type string
---@param entity_id string
---@param entity LuaEntity
---@param spider LuaEntity
---@param player LuaPlayer
local function assign_new_task(type, entity_id, entity, spider, player)
  request_spider_path(spider, entity_id, entity, player)
  spider.color = color.white
  local spider_id = entity_uuid(spider)
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

---@param event EventData.on_tick
local function on_tick(event)
  for _, player in pairs(game.connected_players) do
    local character = player.character
    if not character then goto next_player end
    local player_index = player.index
    local surface = character.surface
    local inventory = character.get_inventory(defines.inventory.character_main)
    local character_position_x = character.position.x
    local character_position_y = character.position.y
    local nearby_entities = character.surface.find_entities({
      {character_position_x - 20, character_position_y - 20},
      {character_position_x + 20, character_position_y + 20},
    })
    -- local nearby_entities = surface.find_entities_filtered({
    --   area = {
    --     {character_position_x - 20, character_position_y - 20},
    --     {character_position_x + 20, character_position_y + 20},
    --   },
    --   force = player.force,
    --   limit = #global.available_spiders[player_index] + 1,
    -- })
    local to_be_deconstructed = {}
    local to_be_upgraded = {}
    local to_be_revived = {}
    for _, entity in pairs(nearby_entities) do
      local entity_id = entity_uuid(entity)
      if entity.to_be_deconstructed() then
        to_be_deconstructed[entity_id] = entity
      elseif entity.to_be_upgraded() then
        to_be_upgraded[entity_id] = entity
      elseif entity.type == "entity-ghost" then
        to_be_revived[entity_id] = entity
      end
    end
    local decon_ordered = false
    local revive_ordered = false
    local upgrade_ordered = false
    if not decon_ordered then
      for entity_id, decon_entity in pairs(to_be_deconstructed) do
        if not global.tasks.by_entity[entity_id] then
          if inventory and inventory.count_empty_stacks() > 0 then
            local spider = table.remove(global.available_spiders[player_index])
            if spider then
              assign_new_task("deconstruct", entity_id, decon_entity, spider, player)
              decon_ordered = true
            end
          end
        end
      end
    end
    if not decon_ordered then
      for entity_id, revive_entity in pairs(to_be_revived) do
        if not global.tasks.by_entity[entity_id] then
          local items = revive_entity.ghost_prototype.items_to_place_this
          local item_stack = items and items[1]
          if item_stack then
            local item_name = item_stack.name
            local item_count = item_stack.count or 1
            if inventory and inventory.get_item_count(item_name) >= item_count then
              local spider = table.remove(global.available_spiders[player_index])
              if spider then
                assign_new_task("revive", entity_id, revive_entity, spider, player)
                revive_ordered = true
              end
            end
          end
        end
      end
    end
    if not revive_ordered then
      for entity_id, upgrade_entity in pairs(to_be_upgraded) do
        if not global.tasks.by_entity[entity_id] then
          local upgrade_target = upgrade_entity.get_upgrade_target()
          local items = upgrade_target and upgrade_target.items_to_place_this
          local item_stack = items and items[1]
          if upgrade_target and item_stack then
            local item_name = item_stack.name
            local item_count = item_stack.count or 1
            if inventory and inventory.get_item_count(item_name) >= item_count then
              local spider = table.remove(global.available_spiders[player_index])
              if spider then
                assign_new_task("upgrade", entity_id, upgrade_entity, spider, player)
                upgrade_ordered = true
              end
            end
          end
        end
      end
    end
    ::next_player::
  end
end

-- script.on_event(defines.events.on_tick, on_tick)
script.on_nth_tick(20, on_tick)
