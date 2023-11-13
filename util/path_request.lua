
local math_util = require("util/math")
local maximum_length = math_util.maximum_length

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
    global.path_requested[spider_id] = true
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
            cache = true,
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
    global.path_requested[spider_id] = true
end

---@param surface LuaSurface
---@param spider_id string|integer
---@param spider LuaEntity
---@param starting_position MapPosition
---@param player LuaPlayer
local function request_spider_path_to_player(surface, spider_id, spider, starting_position, player)
    local request_parameters = {
        bounding_box = { { -0.01, -0.01 }, { 0.01, 0.01 } },
        collision_mask = { "water-tile", "colliding-with-tiles-only", "consider-tile-transitions" },
        start = starting_position,
        goal = player.position,
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
    global.spider_path_to_player_requests[path_request_id] = {
        spider = spider,
        spider_id = spider_id,
        start_position = starting_position,
        final_position = player.position,
        player = player
    }
    global.path_requested[spider_id] = true
end

return {
    request_spider_path_to_entity = request_spider_path_to_entity,
    request_spider_path_to_position = request_spider_path_to_position,
    request_spider_path_to_player = request_spider_path_to_player,
}
