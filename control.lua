
--[[ factorio mod little spiders control script created by asher_sky --]]

local general_util = require("util/general")
local entity_uuid = general_util.entity_uuid

end

---@param spider LuaEntity
local function on_little_spider_built(spider)
  local player = spider.last_user
  if not (player and player.character) then return end
  spider.follow_target = player.character
  spider.color = player.chat_color
  global.little_spiders = global.little_spiders or {}
  global.little_spiders[player.index] = global.little_spiders[player.index] or {}
  global.little_spiders[player.index][spider.unit_number] = spider
  global.available_spiders = global.available_spiders or {} --[[@type table<integer, LuaEntity>]]
  global.available_spiders[player.index] = global.available_spiders[player.index] or {}
  table.insert(global.available_spiders[player.index], spider)
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built
local function on_entity_created(event)
  local entity = event.created_entity or event.entity
  if entity.name == "little-spidertron" then
    on_little_spider_built(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_entity_created)
script.on_event(defines.events.on_robot_built_entity, on_entity_created)
script.on_event(defines.events.script_raised_built, on_entity_created)

---@param event EventData.on_script_path_request_finished
local function on_script_path_request_finished(event)
  local path_request_id = event.id
  local path = event.path
  global.spider_path_requests = global.spider_path_requests or {}
  if not global.spider_path_requests[path_request_id] then return end
  local spider = global.spider_path_requests[path_request_id].spider --[[@type LuaEntity]]
  local entity = global.spider_path_requests[path_request_id].entity --[[@type LuaEntity]]
  local player = global.spider_path_requests[path_request_id].player --[[@type LuaPlayer]]
  local character = player.character
  if (spider and spider.valid and entity and entity.valid and character and character.valid) then
    local character_inventory = character.get_main_inventory()
    if not character_inventory then return end
    if entity.type == "entity-ghost" then
      if character_inventory.get_item_count(entity.ghost_name) > 0 then
        spider.color = { r = 0, g = 0, b = 1, a = 0.5}
        global.ghosts_to_build = global.ghosts_to_build or {}
        global.ghosts_to_build[spider.unit_number] = entity
      end
    elseif entity.to_be_deconstructed() then
      spider.color = { r = 1, g = 0, b = 0, a = 0.5 }
      global.entities_to_deconstruct = global.entities_to_deconstruct or {}
      global.entities_to_deconstruct[spider.unit_number] = entity
    elseif entity.to_be_upgraded() then
      spider.color = { r = 0, g = 1, b = 0, a = 0.5 }
      global.entities_to_upgrade = global.entities_to_upgrade or {}
      global.entities_to_upgrade[spider.unit_number] = entity
    end
    if path then
      for _, waypoint in pairs(path) do
        spider.add_autopilot_destination(waypoint.position)
      end
    else
      table.insert(global.available_spiders[spider.last_user.index], spider)
      spider.color = player.chat_color
    end
  end
  local entity_id = entity and entity.valid and entity.unit_number or 1
  global.spider_on_the_way = global.spider_on_the_way or {}
  global.spider_on_the_way[entity_id] = true
  global.spider_path_requested = global.spider_path_requested or {}
  global.spider_path_requested[entity_id] = nil
  global.spider_path_requests[path_request_id] = nil
end

script.on_event(defines.events.on_script_path_request_finished, on_script_path_request_finished)

---@param event EventData.on_spider_command_completed
local function on_spider_reached_entity(event)
  local spider = event.vehicle
  if not spider.name == "little-spidertron" then return end
  if spider.autopilot_destination and not spider.autopilot_destinations[1] then

    global.ghosts_to_build = global.ghosts_to_build or {}
    local ghost = global.ghosts_to_build[spider.unit_number] --[[@type LuaEntity]]
    if ghost and ghost.valid then
      local ghost_id = ghost.unit_number
      local character_inventory = spider.last_user.character.get_inventory(defines.inventory.character_main)
      if character_inventory and character_inventory.get_item_count(ghost.ghost_name) > 0 then
        rendering.draw_line{
          color = spider.color,
          width = 2,
          from = spider,
          to = ghost.position,
          surface = spider.surface,
          time_to_live = 10,
          draw_on_ground = true,
        }
        rendering.draw_line{
          color = spider.last_user.chat_color,
          width = 2,
          from = spider,
          to = spider.last_user.character,
          surface = spider.surface,
          time_to_live = 10,
          draw_on_ground = true,
        }
        local ghost_name = ghost.ghost_name
        local dictionary, revived_entity = ghost.revive({false, true})
        if revived_entity then
          character_inventory.remove{name = ghost_name, count = 1}
        end
      end
      global.spider_on_the_way = global.spider_on_the_way or {}
      global.spider_on_the_way[ghost_id] = nil
      spider.color = spider.last_user.chat_color
    end

    global.entities_to_deconstruct = global.entities_to_deconstruct or {}
    local decon_entity = global.entities_to_deconstruct[spider.unit_number] --[[@type LuaEntity]]
    if decon_entity and decon_entity.valid then
      local entity_id = decon_entity.unit_number
      rendering.draw_line{
        color = spider.color,
        width = 2,
        from = spider,
        to = decon_entity.position,
        surface = spider.surface,
        time_to_live = 10,
        draw_on_ground = true,
      }
      rendering.draw_line{
        color = spider.last_user.chat_color,
        width = 2,
        from = spider,
        to = spider.last_user.character,
        surface = spider.surface,
        time_to_live = 10,
        draw_on_ground = true,
      }
      local character_inventory = spider.last_user.character.get_inventory(defines.inventory.character_main)
      while decon_entity.valid do
        local result = decon_entity.mine{inventory = character_inventory, force = true, ignore_minable = false, raise_destroyed = true}
      end
      global.spider_on_the_way = global.spider_on_the_way or {}
      global.spider_on_the_way[entity_id] = nil
      spider.color = spider.last_user.chat_color
    end

    global.entities_to_upgrade = global.entities_to_upgrade or {}
    local upgrade_entity = global.entities_to_upgrade[spider.unit_number] --[[@type LuaEntity]]
    if upgrade_entity and upgrade_entity.valid then
      local entity_id = upgrade_entity.unit_number
      local character_inventory = spider.last_user.character.get_inventory(defines.inventory.character_main)
      local upgrade_target = upgrade_entity.get_upgrade_target()
      local upgrade_name = upgrade_target and upgrade_target.items_to_place_this and upgrade_target.items_to_place_this[1].name
      if character_inventory and character_inventory.get_item_count(upgrade_name) > 0 then
        rendering.draw_line{
          color = spider.color,
          width = 2,
          from = spider,
          to = upgrade_entity.position,
          surface = spider.surface,
          time_to_live = 10,
          draw_on_ground = true,
        }
        rendering.draw_line{
          color = spider.last_user.chat_color,
          width = 2,
          from = spider,
          to = spider.last_user.character,
          surface = spider.surface,
          time_to_live = 10,
          draw_on_ground = true,
        }
        local entity_type = upgrade_entity.type
        local upgraded_entity = upgrade_name and upgrade_entity.surface.create_entity {
          name = upgrade_name,
          position = upgrade_entity.position,
          direction = upgrade_entity.get_upgrade_direction(),
          fast_replace = true,
          force = upgrade_entity.force,
          spill = false,
          type = (entity_type == "underground-belt" and upgrade_entity.belt_to_ground_type) or ((entity_type == "loader" or entity_type == "loader-1x1") and upgrade_entity.loader_type),
          raise_built = true,
        }
        if upgraded_entity then
          character_inventory.remove{name = upgrade_name, count = 1}
        end
      end
      global.spider_on_the_way = global.spider_on_the_way or {}
      global.spider_on_the_way[entity_id] = nil
      spider.color = spider.last_user.chat_color
    end

    global.ghosts_to_build[spider.unit_number] = nil
    global.entities_to_deconstruct[spider.unit_number] = nil
    global.entities_to_upgrade[spider.unit_number] = nil
    global.available_spiders = global.available_spiders or {}
    table.insert(global.available_spiders[spider.last_user.index], spider)
  end
end

script.on_event(defines.events.on_spider_command_completed, on_spider_reached_entity)

---@param spider LuaEntity
---@param entity LuaEntity
---@param player LuaPlayer
local function request_spider_path(spider, entity, player)
  local surface = spider.surface
  local request_parameters = {
    bounding_box = spider.bounding_box,
    collision_mask = game.entity_prototypes["little-spidertron-leg-1"].collision_mask,
    start = spider.position,
    goal = entity.position,
    force = spider.force,
    radius = 5,
    can_open_gates = true,
    path_resolution_modifier = -1,
  }
  spider.color = { r = 1, g = 1, b = 1, a = 0.5 }
  local path_request_id = surface.request_path(request_parameters)
  global.spider_path_requests = global.spider_path_requests or {}
  global.spider_path_requests[path_request_id] = {spider = spider, entity = entity, player = player}
end

---@param event EventData.on_tick
local function on_tick(event)
  local tick = event.tick
  for _, player in pairs(game.connected_players) do
    local character = player.character
    if character then
      local nearby_deconstructions = character.surface.find_entities_filtered{
        area = {{character.position.x - 20, character.position.y - 20}, {character.position.x + 20, character.position.y + 20}},
        to_be_deconstructed = true,
      }
      local decon_ordered = false
      local revive_ordered = false
      local upgrade_ordered = false
      for _, decon_entity in pairs(nearby_deconstructions) do
        local decon_id = decon_entity.unit_number
        -- if not decon_id then decon_id = decon_entity.position.x * 100000000 + decon_entity.position.y end
        global.spider_path_requested = global.spider_path_requested or {}
        global.spider_on_the_way = global.spider_on_the_way or {}
        if not (global.spider_on_the_way[decon_id] or global.spider_path_requested[decon_id]) then
          global.available_spiders = global.available_spiders or {}
          local available_spiders = global.available_spiders[player.index]
          local spider = table.remove(available_spiders) --[[@type LuaEntity?]]
          if spider and spider.valid then
            request_spider_path(spider, decon_entity, player)
            global.spider_path_requested[decon_id] = true
            -- spider.color = { r = 1, g = 1, b = 1, a = 0.5 }
            decon_ordered = true
          end
        end
      end
      if not decon_ordered then
        local nearby_ghosts = character.surface.find_entities_filtered{
          area = {{character.position.x - 20, character.position.y - 20}, {character.position.x + 20, character.position.y + 20}},
          type = "entity-ghost",
        }
        for _, ghost in pairs(nearby_ghosts) do
          local ghost_id = ghost.unit_number
          -- if not ghost_id then ghost_id = ghost.position.x * 100000000 + ghost.position.y end
          global.spider_path_requested = global.spider_path_requested or {}
          global.spider_on_the_way = global.spider_on_the_way or {}
          if not (global.spider_on_the_way[ghost_id] or global.spider_path_requested[ghost_id]) then
            local character_inventory = character.get_main_inventory()
            if character_inventory and character_inventory.get_item_count(ghost.ghost_name) > 0 then
              global.available_spiders = global.available_spiders or {}
              local available_spiders = global.available_spiders[player.index]
              local spider = table.remove(available_spiders) --[[@type LuaEntity?]]
              if spider and spider.valid then
                request_spider_path(spider, ghost, player)
                global.spider_path_requested[ghost_id] = true
                -- spider.color = { r = 1, g = 1, b = 1, a = 0.5 }
                revive_ordered = true
              end
            end
          end
        end
        if not revive_ordered then
          local nearby_upgrades = character.surface.find_entities_filtered{
            area = {{character.position.x - 20, character.position.y - 20}, {character.position.x + 20, character.position.y + 20}},
            to_be_upgraded = true,
          }
          for _, upgrade_entity in pairs(nearby_upgrades) do
            local upgrade_id = upgrade_entity.unit_number
            -- if not upgrade_id then upgrade_id = upgrade_entity.position.x * 100000000 + upgrade_entity.position.y end
            global.spider_path_requested = global.spider_path_requested or {}
            global.spider_on_the_way = global.spider_on_the_way or {}
            if not (global.spider_on_the_way[upgrade_id] or global.spider_path_requested[upgrade_id]) then
              local upgrade_target = upgrade_entity.get_upgrade_target()
              local upgrade_name = upgrade_target and upgrade_target.items_to_place_this and upgrade_target.items_to_place_this[1].name
              local character_inventory = character.get_main_inventory()
              if character_inventory and character_inventory.get_item_count(upgrade_name) > 0 then
                global.available_spiders = global.available_spiders or {}
                local available_spiders = global.available_spiders[player.index]
                local spider = table.remove(available_spiders) --[[@type LuaEntity?]]
                if spider and spider.valid then
                  request_spider_path(spider, upgrade_entity, player)
                  global.spider_path_requested[upgrade_id] = true
                  -- spider.color = { r = 1, g = 1, b = 1, a = 0.5 }
                  upgrade_ordered = true
                end
              end
            end
          end
        end
      end
    end
  end
end

script.on_event(defines.events.on_tick, on_tick)
