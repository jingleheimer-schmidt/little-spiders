
local floor = math.floor

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
        local x = floor(position.x * 1000)
        local y = floor(position.y * 1000)
        local uuid = string.format("[%s][%s][%d][%d]", name, surface, x, y)
        return uuid
    end
end

---@param sorted_table table
---@return table
local function randomize_table(sorted_table)
    local randomized = {}
    for _, value in pairs(sorted_table) do
        local index = math.random(1, #randomized + 1)
        table.insert(randomized, index, value)
    end
    return randomized
end

local function random_pairs(t)
    -- Create a table of keys
    local keys = {}
    for key = 1, #t do
        keys[key] = key
    end

    -- Shuffle the keys
    for i = #t, 2, -1 do
        local j = math.random(i)
        keys[i], keys[j] = keys[j], keys[i]
    end

    -- Iterator function
    local index = 0
    return function()
        index = index + 1
        if keys[index] then
            return keys[index], t[keys[index]]
        end
    end
end

local function shuffle_array(array)
    local length = #array
    for i = length, 2, -1 do
        local j = math.random(i)
        array[i], array[j] = array[j], array[i]
    end

end

return {
    entity_uuid = entity_uuid,
    randomize_table = randomize_table,
    random_pairs = random_pairs,
    shuffle_array = shuffle_array,
}
