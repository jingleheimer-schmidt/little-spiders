
---@param surface LuaSurface
---@param from LuaEntity|MapPosition
---@param to LuaEntity|MapPosition
---@param color Color
---@param time_to_live integer?
---@return integer
local function draw_line(surface, from, to, color, time_to_live)
    local render_id = rendering.draw_line({
        color = color,
        width = 1.25,
        from = from,
        to = to,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
    })
    return render_id
end

---@param surface LuaSurface
---@param from LuaEntity|MapPosition
---@param to LuaEntity|MapPosition
---@param color Color
---@param time_to_live integer?
---@param dash_offset boolean?
---@return integer
local function draw_dotted_line(surface, from, to, color, time_to_live, dash_offset)
    local render_id = rendering.draw_line({
        color = color,
        width = 2,
        from = from,
        to = to,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
        gap_length = 1,
        dash_length = 1,
        dash_offset = dash_offset and 1 or 0,
    })
    return render_id
end

---@param surface LuaSurface
---@param position MapPosition
---@param color Color
---@param radius number
---@param time_to_live integer?
---@return integer
local function draw_circle(surface, position, color, radius, time_to_live)
    local render_id = rendering.draw_circle({
        color = color,
        radius = radius,
        width = 1,
        filled = true,
        target = position,
        surface = surface,
        time_to_live = time_to_live or nil,
        draw_on_ground = true,
        only_in_alt_mode = true,
    })
    return render_id
end

return {
    draw_line = draw_line,
    draw_dotted_line = draw_dotted_line,
    draw_circle = draw_circle,
}
