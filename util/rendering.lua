
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

return {
    draw_line = draw_line,
}
