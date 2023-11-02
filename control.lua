
--[[ factorio mod little spiders control script created by asher_sky --]]

---@param message string
local function chatty_print(message)
  global.chatty_print = false
  -- global.chatty_print = true
  if not global.chatty_print then return end
  game.print("[" .. game.tick .. "] " .. message)
end

---@param entity LuaEntity?
---@return string
local function get_chatty_name(entity)
  if not entity then return "" end
  local id = entity.entity_label or entity.backer_name or entity.unit_number or script.register_on_entity_destroyed(entity)
  if entity.type == "character" and entity.player then
    id = entity.player.name
  end
  local name = entity.name .. " " .. id
  local color = entity.color
  if color then
    name = "[color=" .. color.r .. "," .. color.g .. "," .. color.b .. "]" .. name .. "[/color]"
  end
  return "[" .. name .. "]"
end

---@param entity LuaEntity|MapPosition|TilePosition
---@return string
local function get_chatty_position(entity)
  local position = serpent.line(entity.position or entity)
  return position
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

---@param event EventData.on_built_entity
local function on_built_entity(event)
  local entity = event.created_entity
  if entity.name == "little-spidertron" then
    on_little_spider_built(entity)
  end
end

---@param event EventData.on_robot_built_entity
local function on_robot_built_entity(event)
  local entity = event.created_entity
  if entity.name == "little-spidertron" then
    on_little_spider_built(entity)
  end
end

---@param event EventData.script_raised_built
local function script_raised_built(event)
  local entity = event.entity
  if entity.name == "little-spidertron" then
    on_little_spider_built(entity)
  end
end

script.on_event(defines.events.on_built_entity, on_built_entity)
script.on_event(defines.events.on_robot_built_entity, on_robot_built_entity)
script.on_event(defines.events.script_raised_built, script_raised_built)

---@param event EventData.on_script_path_request_finished
local function on_script_path_request_finished(event)
  local path_request_id = event.id
  local path = event.path
  if not path then return end
  global.spider_path_requests = global.spider_path_requests or {}
  if not global.spider_path_requests[path_request_id] then return end
  local spider = global.spider_path_requests[path_request_id].spider --[[@type LuaEntity]]
  local entity = global.spider_path_requests[path_request_id].entity --[[@type LuaEntity]]
  local player = global.spider_path_requests[path_request_id].player --[[@type LuaPlayer]]
  local character = player.character
  if not (spider and spider.valid and entity and entity.valid and character and character.valid) then return end
  local character_inventory = character.get_main_inventory()
  if not character_inventory then return end
  -- local spider_inventory = spider.get_inventory(defines.inventory.spider_trunk)
  -- if not spider_inventory then return end
  -- for i = 1, 10 do
  --   local item_stack = spider_inventory[i]
  --   spider_inventory.remove(item_stack)
  --   if character_inventory.can_insert(item_stack) then
  --     character_inventory.insert(item_stack)
  --   else
  --     character.surface.spill_item_stack(character.position, item_stack, true, nil, false)
  --   end
  -- end
  if entity.type == "entity-ghost" then
    if character_inventory.get_item_count(entity.ghost_name) > 0 then
      -- character_inventory.remove{name = entity.ghost_name, count = 1}
      -- spider_inventory.insert{name = entity.ghost_name, count = 1}
      -- rendering.draw_line{
      --   color = player.chat_color,
      --   width = 2,
      --   from = spider,
      --   to = character,
      --   surface = spider.surface,
      --   time_to_live = 10,
      --   draw_on_ground = true,
      -- }
      spider.color = { r = 0, g = 0, b = 1, a = 0.5}
      global.ghosts_to_build = global.ghosts_to_build or {}
      global.ghosts_to_build[spider.unit_number] = entity
    end
  elseif entity.to_be_deconstructed() then
    -- rendering.draw_line{
    --   color = { r = 1, g = 0, b = 0 },
    --   width = 2,
    --   from = spider,
    --   to = character,
    --   surface = spider.surface,
    --   time_to_live = 10,
    --   draw_on_ground = true,
    -- }
    spider.color = { r = 1, g = 0, b = 0, a = 0.5 }
    global.entities_to_deconstruct = global.entities_to_deconstruct or {}
    global.entities_to_deconstruct[spider.unit_number] = entity
  elseif entity.to_be_upgraded() then
    -- rendering.draw_line{
    --   color = { r = 0, g = 1, b = 0 },
    --   width = 2,
    --   from = spider,
    --   to = character,
    --   surface = spider.surface,
    --   time_to_live = 10,
    --   draw_on_ground = true,
    -- }
    spider.color = { r = 0, g = 1, b = 0, a = 0.5 }
    global.entities_to_upgrade = global.entities_to_upgrade or {}
    global.entities_to_upgrade[spider.unit_number] = entity
  end
  for _, waypoint in pairs(path) do
    spider.add_autopilot_destination(waypoint.position)
  end
  local entity_id = entity.unit_number or entity.position.x * 100000000 + entity.position.y
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
      local ghost_id = ghost.unit_number or ghost.position.x * 100000000 + ghost.position.y
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
      local character_inventory = spider.last_user.character.get_inventory(defines.inventory.character_main)
      if character_inventory and character_inventory.get_item_count(ghost.ghost_name) > 0 then
        local ghost_name = ghost.ghost_name
        local dictionary, revived_entity, request_proxy = ghost.revive()
        if revived_entity then
          character_inventory.remove{name = ghost_name, count = 1}
        end
      end
      global.spider_on_the_way = global.spider_on_the_way or {}
      global.spider_on_the_way[ghost_id] = nil
      global.ghosts_to_build[spider.unit_number] = nil
      spider.color = spider.last_user.chat_color
    end

    global.entities_to_deconstruct = global.entities_to_deconstruct or {}
    local decon_entity = global.entities_to_deconstruct[spider.unit_number] --[[@type LuaEntity]]
    if decon_entity and decon_entity.valid then
      local entity_id = decon_entity.unit_number or decon_entity.position.x * 100000000 + decon_entity.position.y
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
      -- local spider_inventory = spider.get_inventory(defines.inventory.spider_trunk)
      local character_inventory = spider.last_user.character.get_inventory(defines.inventory.character_main)
      while decon_entity.valid do
        local result = decon_entity.mine{inventory = character_inventory, force = true, ignore_minable = false, raise_destroyed = true}
      end
      global.spider_on_the_way = global.spider_on_the_way or {}
      global.spider_on_the_way[entity_id] = nil
      global.entities_to_deconstruct[spider.unit_number] = nil
      spider.color = spider.last_user.chat_color
    end

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
    path_resolution_modifier = 3,
  }
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
      for _, decon_entity in pairs(nearby_deconstructions) do
        local decon_id = decon_entity.unit_number
        if not decon_id then decon_id = decon_entity.position.x * 100000000 + decon_entity.position.y end
        global.spider_path_requested = global.spider_path_requested or {}
        global.spider_on_the_way = global.spider_on_the_way or {}
        if not (global.spider_on_the_way[decon_id] or global.spider_path_requested[decon_id]) then
          global.available_spiders = global.available_spiders or {}
          local available_spiders = global.available_spiders[player.index]
          local spider = table.remove(available_spiders) --[[@type LuaEntity?]]
          if spider and spider.valid then
            request_spider_path(spider, decon_entity, player)
            global.spider_path_requested[decon_id] = true
            spider.color = { r = 1, g = 0, b = 0, a = 0.5 }
          end
        end
      end
      if not nearby_deconstructions[1] then
        local nearby_ghosts = character.surface.find_entities_filtered{
          area = {{character.position.x - 20, character.position.y - 20}, {character.position.x + 20, character.position.y + 20}},
          type = "entity-ghost",
        }
        for _, ghost in pairs(nearby_ghosts) do
          local ghost_id = ghost.unit_number
          if not ghost_id then ghost_id = ghost.position.x * 100000000 + ghost.position.y end
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
                spider.color = { r = 0, g = 0, b = 1, a = 0.5 }
              end
            end
          end
        end
      end
    end
  end
end

script.on_event(defines.events.on_tick, on_tick)
