
---@param entity LuaEntity
---@return string|integer
local function entity_uuid(entity)
    local unit_number = entity.unit_number
    if unit_number then
        return unit_number
    else
        local name = entity.name
        local surface = entity.surface_index
        local position = entity.position
        local x = math.floor(position.x * 1000)
        local y = math.floor(position.y * 1000)
        local uuid = string.format("[%s][%s][%d][%d]", name, surface, x, y)
        return uuid
    end
end

return {
    entity_uuid = entity_uuid,
}