-- Mobs Api (28th August 2015)
mobs = {}
mobs.mod = "redo"

-- Load settings
local damage_enabled = minetest.setting_getbool("enable_damage")
local peaceful_only = minetest.setting_getbool("only_peaceful_mobs")
local disable_blood = minetest.setting_getbool("mobs_disable_blood")
mobs.protected = tonumber(minetest.setting_get("mobs_spawn_protected")) or 1
mobs.remove = minetest.setting_getbool("remove_far_mobs")

function mobs:register_mob(name, def)
	minetest.register_entity(name, {
		stepheight = def.stepheight or 0.6,
		name = name,
		fly = def.fly,
		fly_in = def.fly_in or "air",
		owner = def.owner or "",
		order = def.order or "",
		on_die = def.on_die,
		do_custom = def.do_custom,
		jump_height = def.jump_height or 6,
		jump_chance = def.jump_chance or 0,
		rotate = math.rad(def.rotate or 0), --  0=front, 90=side, 180=back, 270=side2
		lifetimer = def.lifetimer or 360, -- 6 minutes
		hp_min = def.hp_min or 5,
		hp_max = def.hp_max or 10,
		physical = true,
		collisionbox = def.collisionbox,
		visual = def.visual,
		visual_size = def.visual_size or {x = 1, y = 1},
		mesh = def.mesh,
		makes_footstep_sound = def.makes_footstep_sound or false,
		view_range = def.view_range or 5,
		walk_velocity = def.walk_velocity or 1,
		run_velocity = def.run_velocity or 2,
		damage = def.damage,
		light_damage = def.light_damage or 0,
		water_damage = def.water_damage or 0,
		lava_damage = def.lava_damage or 0,
		fall_damage = def.fall_damage or 1,
		fall_speed = def.fall_speed or -10, -- must be lower than -2 (default: -10)
		drops = def.drops or {},
		armor = def.armor,
		on_rightclick = def.on_rightclick,
		type = def.type,
		attack_type = def.attack_type,
		arrow = def.arrow,
		shoot_interval = def.shoot_interval,
		sounds = def.sounds or {},
		animation = def.animation,
		follow = def.follow, -- or "",
		jump = def.jump or true,
		walk_chance = def.walk_chance or 50,
		attacks_monsters = def.attacks_monsters or false,
		group_attack = def.group_attack or false,
		--fov = def.fov or 120,
		passive = def.passive or false,
		recovery_time = def.recovery_time or 0.5,
		knock_back = def.knock_back or 3,
		blood_amount = def.blood_amount or 5,
		blood_texture = def.blood_texture or "mobs_blood.png",
		shoot_offset = def.shoot_offset or 0,
		floats = def.floats or 1, -- floats in water by default
		replace_rate = def.replace_rate,
		replace_what = def.replace_what,
		replace_with = def.replace_with,
		replace_offset = def.replace_offset or 0,
		timer = 0,
		env_damage_timer = 0, -- only if state = "attack"
		attack = {player = nil, dist = nil},
		state = "stand",
		tamed = false,
		pause_timer = 0,
		horny = false,
		hornytimer = 0,
		child = false,
		gotten = false,
		health = 0,
		textures = def.textures,
		child_texture = def.child_texture,
		hunger = def.hunger,
    npc_food_types = def.npc_food_types,
    biome_food_types = def.biome_food_types,
    mate_timer = 3,
    offspring = 3,
    -- Callbacks
		do_attack = api_do_attack,
		set_velocity = api_set_velocity,
		on_step = api_on_step,
		get_staticdata = api_get_staticdata,
		on_punch = api_on_punch,
	})
end

mobs.spawning_mobs = {}

function mobs:spawn_specific(name, nodes, neighbors, min_light, max_light, interval, chance, active_object_count, min_height, max_height)
	mobs.spawning_mobs[name] = true
	minetest.register_abm({
		nodenames = nodes,
		neighbors = neighbors,
		interval = interval,
		chance = chance,
		action = function(pos, node, _, active_object_count_wider)
			-- do not spawn if too many active entities in area
			if active_object_count_wider > active_object_count
			or not mobs.spawning_mobs[name] then
			--or not pos then
				return
			end

			-- spawn above node
			pos.y = pos.y + 1

			-- mobs cannot spawn inside protected areas if enabled
			if mobs.protected == 1
			and minetest.is_protected(pos, "") then
				return
			end

			-- check if light and height levels are ok to spawn
			local light = minetest.get_node_light(pos)
			if not light
			or light > max_light
			or light < min_light
			or pos.y > max_height
			or pos.y < min_height then
				return
			end

			-- are we spawning inside a solid node?
			local nod = minetest.get_node_or_nil(pos)
			if not nod
			or not nod.name
			or not minetest.registered_nodes[nod.name]
			or minetest.registered_nodes[nod.name].walkable == true then
				return
			end

			pos.y = pos.y + 1

			nod = minetest.get_node_or_nil(pos)
			if not nod
			or not nod.name
			or not minetest.registered_nodes[nod.name]
			or minetest.registered_nodes[nod.name].walkable == true then
				return
			end

			if minetest.setting_getbool("display_mob_spawn") then
				minetest.chat_send_all("[mobs] Add "..name.." at "..minetest.pos_to_string(pos))
			end

			-- spawn mob half block higher
			pos.y = pos.y - 0.5
			minetest.add_entity(pos, name)
			--print ("Spawned "..name.." at "..minetest.pos_to_string(pos).." on "..node.name.." near "..neighbors[1])

		end
	})
end

-- compatibility with older mob registration
function mobs:register_spawn(name, nodes, max_light, min_light, chance, active_object_count, max_height)
	mobs:spawn_specific(name, nodes, {"air"}, min_light, max_light, 60, chance, active_object_count, -31000, max_height)
end

-- particle effects
function effect(pos, amount, texture, max_size)
	minetest.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x = -0, y = -2, z = -0},
		maxvel = {x = 2,  y = 2,  z = 2},
		minacc = {x = -4, y = -4, z = -4},
		maxacc = {x = 4, y = 4, z = 4},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = 0.5,
		maxsize = (max_size or 1),
		texture = texture,
	})
end

-- explosion
function mobs:explosion(pos, radius, fire, smoke, sound)
	-- node hit, bursts into flame (cannot blast through unbreakable/specific nodes)
	if not fire then fire = 0 end
	if not smoke then smoke = 0 end
	local pos = vector.round(pos)
	local vm = VoxelManip()
	local minp, maxp = vm:read_from_map(vector.subtract(pos, radius), vector.add(pos, radius))
	local a = VoxelArea:new({MinEdge = minp, MaxEdge = maxp})
	local data = vm:get_data()
	local p = {}
	local c_air = minetest.get_content_id("air")
	local c_ignore = minetest.get_content_id("ignore")
	local c_obsidian = minetest.get_content_id("default:obsidian")
	local c_brick = minetest.get_content_id("default:obsidianbrick")
	local c_chest = minetest.get_content_id("default:chest_locked")
	if sound
	and sound ~= "" then
		minetest.sound_play(sound, {
			pos = pos,
			gain = 1.0,
			max_hear_distance = 16
		})
	end
	-- if area protected then no blast damage
	if minetest.is_protected(pos, "") then
		return
	end
	for z = -radius, radius do
	for y = -radius, radius do
	local vi = a:index(pos.x + (-radius), pos.y + y, pos.z + z)
	for x = -radius, radius do
		p.x = pos.x + x
		p.y = pos.y + y
		p.z = pos.z + z
		if data[vi] ~= c_air
		and data[vi] ~= c_ignore
		and data[vi] ~= c_obsidian
		and data[vi] ~= c_brick
		and data[vi] ~= c_chest then
			local n = minetest.get_node(p).name
			if minetest.get_item_group(n, "unbreakable") ~= 1 then
				-- if chest then drop items inside
				if n == "default:chest"
				or n == "3dchest:chest" then
					local meta = minetest.get_meta(p)
					local inv  = meta:get_inventory()
					for i = 1,32 do
						local m_stack = inv:get_stack("main", i)
						local obj = minetest.add_item(p, m_stack)
						if obj then
							obj:setvelocity({
								x = math.random(-2, 2),
								y = 7,
								z = math.random(-2, 2)
							})
						end
					end
				end
				if fire > 0
				and (minetest.registered_nodes[n].groups.flammable
				or math.random(1, 100) <= 30) then
					minetest.set_node(p, {name = "fire:basic_flame"})
				else
					minetest.remove_node(p)
				end
				if smoke > 0 then
					effect(p, 2, "tnt_smoke.png", 5)
				end
			end
		end
		vi = vi + 1
	end
	end
	end
end

-- register arrow for shoot attack
function mobs:register_arrow(name, def)
	if not name or not def then return end -- errorcheck
	minetest.register_entity(name, {
		physical = false,
		visual = def.visual,
		visual_size = def.visual_size,
		textures = def.textures,
		velocity = def.velocity,
		hit_player = def.hit_player,
		hit_node = def.hit_node,
		hit_mob = def.hit_mob,
		drop = def.drop or false,
		collisionbox = {0, 0, 0, 0, 0, 0}, -- remove box around arrows

		on_step = function(self, dtime)
			self.timer = (self.timer or 0) + 1
			if self.timer > 150 then self.object:remove() return end

			local engage = 10 - (self.velocity / 2) -- clear entity before arrow becomes active
			local pos = self.object:getpos()
			local node = minetest.get_node_or_nil(self.object:getpos())
			if node then node = node.name else node = "air" end

			if self.hit_node
			and minetest.registered_nodes[node]
			and minetest.registered_nodes[node].walkable then
				self.hit_node(self, pos, node)
				if self.drop == true then
					pos.y = pos.y + 1
					self.lastpos = (self.lastpos or pos)
					minetest.add_item(self.lastpos, self.object:get_luaentity().name)
				end
				self.object:remove() ; -- print ("hit node")
				return
			end

			if (self.hit_player or self.hit_mob)
			and self.timer > engage then
				for _,player in pairs(minetest.get_objects_inside_radius(pos, 1.0)) do
					if self.hit_player
					and player:is_player() then
						self.hit_player(self, player)
						self.object:remove() ; -- print ("hit player")
						return
					end
					if self.hit_mob
					and player:get_luaentity().name ~= self.object:get_luaentity().name
					and player:get_luaentity().name ~= "__builtin:item"
					and player:get_luaentity().name ~= "gauges:hp_bar"
					and player:get_luaentity().name ~= "signs:text" then
						self.hit_mob(self, player)
						self.object:remove() ; -- print ("hit mob")
						return
					end
				end
			end
			self.lastpos = pos
		end
	})
end

-- Spawn Egg
function mobs:register_egg(mob, desc, background, addegg)
	local invimg = background
	if addegg == 1 then
		invimg = invimg.."^mobs_chicken_egg.png"
	end
	minetest.register_craftitem(mob, {
		description = desc,
		inventory_image = invimg,
		on_place = function(itemstack, placer, pointed_thing)
			local pos = pointed_thing.above
			if pointed_thing.above
			and not minetest.is_protected(pos, placer:get_player_name()) then
				pos.y = pos.y + 0.5
				local mob = minetest.add_entity(pos, mob)
				local ent = mob:get_luaentity()
				if ent.type ~= "monster" then
					-- set owner
					ent.owner = placer:get_player_name()
					ent.tamed = true
				end
				itemstack:take_item()
			end
			return itemstack
		end,
	})
end

-- capture critter (thanks to blert2112 for idea)
function mobs:capture_mob(self, clicker, chance_hand, chance_net, chance_lasso, force_take, replacewith)
	if clicker:is_player()
	and clicker:get_inventory()
	and not self.child then
		-- get name of clicked mob
		local mobname = self.name
		-- if not nil change what will be added to inventory
		if replacewith then
			mobname = replacewith
		end
		local name = clicker:get_player_name()
		-- is mob tamed?
		if self.tamed == false
		and force_take == false then
			minetest.chat_send_player(name, "Not tamed!")
			return
		end
		-- cannot pick up if not owner
		if self.owner ~= name
		and force_take == false then
			minetest.chat_send_player(name, self.owner.." is owner!")
			return
		end

		if clicker:get_inventory():room_for_item("main", mobname) then
			-- was mob clicked with hand, net, or lasso?
			local tool = clicker:get_wielded_item()
			local chance = 0
			if tool:is_empty() then
				chance = chance_hand
			elseif tool:get_name() == "mobs:net" then
				chance = chance_net
				tool:add_wear(4000) -- 17 uses
				clicker:set_wielded_item(tool)
			elseif tool:get_name() == "mobs:magic_lasso" then
				-- pick up if owner
				chance = chance_lasso
				tool:add_wear(650) -- 100 uses
				clicker:set_wielded_item(tool)
			end
			-- return if no chance
			if chance == 0 then return end
			-- calculate chance.. was capture successful?
			if math.random(100) <= chance then
				-- successful capture.. add to inventory
				clicker:get_inventory():add_item("main", mobname)
				self.object:remove()
			else
				minetest.chat_send_player(name, "Missed!")
			end
		end
	end
end

-- feeding, taming and breeding (thanks blert2112)
function mobs:feed_tame(self, clicker, feed_count, breed)

	if not self.follow then return false end

	-- can eat/tame with item in hand
	if follow_holding(self, clicker) then
--print ("mmm, tasty")
		-- take item
		if not minetest.setting_getbool("creative_mode") then
			local item = clicker:get_wielded_item()
			item:take_item()
			clicker:set_wielded_item(item)
		end

		-- heal health
		local hp = self.object:get_hp()
		hp = math.min(hp + 4, self.hp_max)
		self.object:set_hp(hp)
		self.health = hp

		-- make children grow quicker
		if self.child == true then
			self.hornytimer = self.hornytimer + 20
			return true
		end

		-- feed and tame
		self.food = (self.food or 0) + 1
		if self.food == feed_count then
			self.food = 0
			if breed and self.hornytimer == 0 then
				self.horny = true
			end
			self.gotten = false
			self.tamed = true
			if not self.owner or self.owner == "" then
				self.owner = clicker:get_player_name()
			end

			-- make sound when fed so many times
			if self.sounds.random then
				minetest.sound_play(self.sounds.random, {
					object = self.object,
					max_hear_distance = self.sounds.distance
				})
			end
		end
		return true
	else
		return false
	end
end