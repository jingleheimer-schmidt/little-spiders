
local little_spider_arguments = {
    scale = 1/3,
    leg_scale = 0.75,
    name = "little-spidertron",
    leg_thickness = 1.5,
    leg_movement_speed = 5,
}
create_spidertron(little_spider_arguments)
local little_spider_entity = data.raw["spider-vehicle"]["little-spidertron"]
little_spider_entity.guns = nil
little_spider_entity.inventory_size = 0
little_spider_entity.trash_inventory_size = 0
little_spider_entity.equipment_grid = nil
little_spider_entity.allow_passengers = false
little_spider_entity.is_military_target = false
little_spider_entity.collision_box = {{-0.005, -0.005}, {0.005, 0.005}}
-- little_spider_entity.collision_mask = {"object-layer", "water-tile", "rail-layer"}

for i = 1, 8 do
    local leg = data.raw["spider-leg"]["little-spidertron-leg-" .. i]
    leg.collision_mask = {"object-layer", "water-tile", "rail-layer"}
end

local little_spider_recipe = table.deepcopy(data.raw["recipe"]["spidertron"])
little_spider_recipe.name = "little-spidertron"
little_spider_recipe.ingredients = {
    {"electronic-circuit", 4},
    {"iron-plate", 12},
    {"inserter", 8},
    {"raw-fish", 1},
}
little_spider_recipe.result = "little-spidertron"
little_spider_recipe.enabled = true
data:extend{little_spider_recipe}

local little_spider_item = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
little_spider_item.name = "little-spidertron"
little_spider_item.place_result = "little-spidertron"
data:extend{little_spider_item}
