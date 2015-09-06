
-- Rat by PilzAdam

mobs:register_mob("mobs:rat", {
	type = "animal",
	passive = true,
	hp_min = 1,
	hp_max = 4,
	armor = 200,
	collisionbox = {-0.2, -1, -0.2, 0.2, -0.8, 0.2},
	visual = "mesh",
	mesh = "mobs_rat.b3d",
	textures = {
		"mobs_rat.png",
		"mobs_rat2.png"
	},
	makes_footstep_sound = false,
	sounds = {
		random = "mobs_rat",
	},
	walk_velocity = 1,
	jump = true,
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
	on_rightclick = function(self, clicker)
		mobs:capture_mob(self, clicker, 25, 80, 0, true, nil)
	end,
	hunger = 1,
  horny = false,
  biome_food_types = {"farming:pumpkin_8","farming_plus:tomato","farming:coffee_5","farming:rhubarb_3", 
                      "farming_plus:rhubarb", "farming_plus:carrot",  "trunks:moss_fungus",
                      "farming_plus:carrot", "farming_plus:orange", "farming:raspberry_4"}
})

mobs:register_spawn("mobs:rat", {"default:stone", "woodsoils:dirt_with_leaves_1", "woodsoils:dirt_with_leaves_2"}, 20, 10, 15000, 1, 31000)

mobs:register_egg("mobs:rat", "Rat", "mobs_rat_inventory.png", 0)
	
-- cooked rat, yummy!
minetest.register_craftitem("mobs:rat_cooked", {
	description = "Cooked Rat",
	inventory_image = "mobs_cooked_rat.png",
	on_use = minetest.item_eat(3),
})

minetest.register_craft({
	type = "cooking",
	output = "mobs:rat_cooked",
	recipe = "mobs:rat",
	cooktime = 5,
})