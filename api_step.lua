function api_on_step(theMob, dtime)

    -- life step 
    
    theMob.life_step_timer =  theMob.life_step_timer + dtime
    
  if theMob.life_step_timer > 4 then
    theMob.life_step_timer = 0
    life_step(theMob, dtime)
  end
    
  if theMob.type == "monster"
    and peaceful_only then
    theMob.object:remove()
    return
  end

  -- if lifetimer run out and not npc; tamed or attacking then remove mob
  if not theMob.tamed then
    theMob.lifetimer = theMob.lifetimer - dtime
    if theMob.lifetimer <= 0
      and theMob.state ~= "attack" then
      minetest.log("action","lifetimer expired, removed "..theMob.name)
      effect(theMob.object:getpos(), 15, "tnt_smoke.png")
      theMob.object:remove()
      return
    end
  end

  -- check for mob drop/replace (used for chicken egg and sheep eating grass/wheat)
  if theMob.replace_rate
    and theMob.child == false
    and math.random(1,theMob.replace_rate) == 1 then
    local pos = theMob.object:getpos()
    pos.y = pos.y + theMob.replace_offset
    -- print ("replace node = ".. minetest.get_node(pos).name, pos.y)
    if theMob.replace_what
      and theMob.object:getvelocity().y == 0
      and #minetest.find_nodes_in_area(pos, pos, theMob.replace_what) > 0 then
      --and theMob.state == "stand" then
      minetest.set_node(pos, {name = theMob.replace_with})
    end
  end

  local yaw = 0

  if not theMob.fly then
    -- floating in water (or falling)
    local pos = theMob.object:getpos()
    local nod = minetest.get_node_or_nil(pos)
    if nod then nod = nod.name else nod = "default:dirt" end
    local nodef = minetest.registered_nodes[nod]

    local v = theMob.object:getvelocity()
    if v.y > 0.1 then
      theMob.object:setacceleration({
        x = 0,
        y= theMob.fall_speed,
        z = 0
      })
    end
    if nodef.groups.water then
      if theMob.floats == 1 then
        theMob.object:setacceleration({
          x = 0,
          y = -theMob.fall_speed / (math.max(1, v.y) ^ 2),
          z = 0
        })
      end
    else
      theMob.object:setacceleration({
        x = 0,
        y = theMob.fall_speed,
        z = 0
      })

      -- fall damage
      if theMob.fall_damage == 1
        and theMob.object:getvelocity().y == 0 then
        local d = (theMob.old_y or 0) - theMob.object:getpos().y
        if d > 5 then
          theMob.object:set_hp(theMob.object:get_hp() - math.floor(d - 5))
          effect(theMob.object:getpos(), 5, "tnt_smoke.png")
          check_for_death(theMob)
        end
        theMob.old_y = theMob.object:getpos().y
      end
    end
  end

  -- knockback timer
  if theMob.pause_timer > 0 then
    theMob.pause_timer = theMob.pause_timer - dtime
    if theMob.pause_timer < 1 then
      theMob.pause_timer = 0
    end
    return
  end

  -- attack timer
  theMob.timer = theMob.timer + dtime
  if theMob.state ~= "attack" then
    if theMob.timer < 1 then
      return
    end
    theMob.timer = 0
  end

  if theMob.sounds.random
    and math.random(1, 100) <= 1 then
    minetest.sound_play(theMob.sounds.random, {
      object = theMob.object,
      max_hear_distance = theMob.sounds.distance
    })
  end

  local do_env_damage = function(theMob)

    local pos = theMob.object:getpos()
    local tod = minetest.get_timeofday()

    -- daylight above ground
    if theMob.light_damage ~= 0
      and pos.y > 0
      and tod > 0.2
      and tod < 0.8
      and (minetest.get_node_light(pos) or 0) > 12 then
      theMob.object:set_hp(theMob.object:get_hp() - theMob.light_damage)
      effect(pos, 5, "tnt_smoke.png")
      if check_for_death(theMob) then return end
    end

    pos.y = pos.y + theMob.collisionbox[2] -- foot level
    local nod = minetest.get_node_or_nil(pos)
    if not nod then return end ;  -- print ("standing in "..nod.name)
    local nodef = minetest.registered_nodes[nod.name]
    pos.y = pos.y + 1

    -- water
    if theMob.water_damage ~= 0
      and nodef.groups.water then
      theMob.object:set_hp(theMob.object:get_hp() - theMob.water_damage)
      effect(pos, 5, "bubble.png")
      if check_for_death(theMob) then return end
    end

    -- lava or fire
    if theMob.lava_damage ~= 0
      and (nodef.groups.lava or nod.name == "fire:basic_flame") then
      theMob.object:set_hp(theMob.object:get_hp() - theMob.lava_damage)
      effect(pos, 5, "fire_basic_flame.png")
      if check_for_death(theMob) then return end
    end

  end

  local do_jump = function(theMob)
    if theMob.fly then
      return
    end

    theMob.jumptimer = (theMob.jumptimer or 0) + 1
    if theMob.jumptimer < 3 then
      local pos = theMob.object:getpos()
      pos.y = (pos.y + theMob.collisionbox[2]) - 0.2
      local nod = minetest.get_node(pos)
      --print ("standing on:", nod.name, pos.y)
      if not nod
        or not minetest.registered_nodes[nod.name]
        or minetest.registered_nodes[nod.name].walkable == false then
        return
      end
      if theMob.direction then
        pos.y = pos.y + 0.5
        local nod = minetest.get_node_or_nil({
          x = pos.x + theMob.direction.x,
          y = pos.y,
          z = pos.z + theMob.direction.z
        })
        --print ("in front:", nod.name, pos.y)
        if nod and nod.name and
          (nod.name ~= "air"
          or theMob.walk_chance == 0) then
          local def = minetest.registered_items[nod.name]
          if (def
            and def.walkable
            and not nod.name:find("fence"))
            or theMob.walk_chance == 0 then
            local v = theMob.object:getvelocity()
            v.y = theMob.jump_height + 1
            v.x = v.x * 2.2
            v.z = v.z * 2.2
            theMob.object:setvelocity(v)
            if theMob.sounds.jump then
              minetest.sound_play(theMob.sounds.jump, {
                object = theMob.object,
                max_hear_distance = theMob.sounds.distance
              })
            end
          end
        end
      end
    else
      theMob.jumptimer = 0
    end
  end

  -- environmental damage timer (every 1 second)
  theMob.env_damage_timer = theMob.env_damage_timer + dtime
  if theMob.state == "attack"
    and theMob.env_damage_timer > 1 then
    theMob.env_damage_timer = 0
    do_env_damage(theMob)
    -- custom function (defined in mob lua file)
    if theMob.do_custom then
      theMob.do_custom(theMob)
    end
  elseif theMob.state ~= "attack" then
    do_env_damage(theMob)
    -- custom function
    if theMob.do_custom then
      theMob.do_custom(theMob)
    end
  end

  -- find someone to attack
  if theMob.type == "monster"
    and damage_enabled
    and theMob.state ~= "attack" then

    local s = theMob.object:getpos()
    local p, sp, dist
    local player = nil
    local type = nil
    local obj = nil
    local min_dist = theMob.view_range + 1
    local min_player = nil

    for _,oir in ipairs(minetest.get_objects_inside_radius(s, theMob.view_range)) do

      if oir:is_player() then
        player = oir
        type = "player"
      else
        obj = oir:get_luaentity()
        if obj then
          player = obj.object
          type = obj.type
        end
      end

      if type == "player"
        or type == "npc" then
        s = theMob.object:getpos()
        p = player:getpos()
        sp = s
        p.y = p.y + 1
        sp.y = sp.y + 1 -- aim higher to make looking up hills more realistic
        dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
        if dist < theMob.view_range then
          -- and theMob.in_fov(theMob,p) then
          -- choose closest player to attackours 
          if minetest.line_of_sight(sp, p, 2) == true
            and dist < min_dist then
            min_dist = dist
            min_player = player
          end
        end
      end
    end
    -- attack player
    if min_player then
      theMob.do_attack(theMob, min_player, min_dist)
    end
  end

  -- npc, find closest monster to attack
  local min_dist = theMob.view_range + 1
  local min_player = nil

  if theMob.type == "npc"
    and theMob.attacks_monsters
    and theMob.state ~= "attack" then
    local s = theMob.object:getpos()
    local obj = nil
    for _, oir in pairs(minetest.get_objects_inside_radius(s,theMob.view_range)) do
      obj = oir:get_luaentity()
      if obj
        and obj.type == "monster" then
        -- attack monster
        p = obj.object:getpos()
        dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
        if dist < min_dist then
          min_dist = dist
          min_player = obj.object
        end
      end
    end
    if min_player then
      theMob.do_attack(theMob, min_player, min_dist)
    end
  end

  -- find player to follow
  if (theMob.follow ~= ""
    or theMob.order == "follow")
    and not theMob.following
    and theMob.state ~= "attack" then
    local s, p, dist
    for _,player in pairs(minetest.get_connected_players()) do
      s = theMob.object:getpos()
      p = player:getpos()
      dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
      if dist < theMob.view_range then
        theMob.following = player
        break
      end
    end
  end

  if theMob.type == "npc"
    and theMob.order == "follow"
    and theMob.state ~= "attack"
    and theMob.owner ~= "" then
    -- npc stop following player if not owner
    if theMob.following
      and theMob.owner
      and theMob.owner ~= theMob.following:get_player_name() then
      theMob.following = nil
    end
  else
    -- stop following player if not holding specific item
    if theMob.following
      and theMob.following.is_player
      --and theMob.following:get_wielded_item():get_name() ~= theMob.follow then
      and follow_holding(theMob, theMob.following) == false then
      theMob.following = nil
    end
  end

  -- follow player or mob
  if theMob.following then
    local s = theMob.object:getpos()
    local p

    if theMob.following.is_player
      and theMob.following:is_player() then
      p = theMob.following:getpos()
    elseif theMob.following.object then
      p = theMob.following.object:getpos()
    end

    if p then
      local dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
      if dist > theMob.view_range then
        theMob.following = nil
      else
        local vec = {x = p.x - s.x, y = p.y - s.y, z = p.z - s.z}
        yaw = (math.atan(vec.z / vec.x) + math.pi / 2) - theMob.rotate
        if p.x > s.x then
          yaw = yaw + math.pi
        end
        theMob.object:setyaw(yaw)

        -- anyone but standing npc's can move along
        if dist > 2
          and theMob.order ~= "stand" then
          if (theMob.jump
            and api_get_velocity(theMob) <= 0.5
            and theMob.object:getvelocity().y == 0)
            or (theMob.object:getvelocity().y == 0
            and theMob.jump_chance > 0) then
            theMob.direction = {
              x = math.sin(yaw) * -1,
              y = -20,
              z = math.cos(yaw)
            }
            do_jump(theMob)
          end
          api_set_velocity(theMob, theMob.walk_velocity)
          if theMob.walk_chance ~= 0 then
            api_set_animation(theMob, "walk")
          end
        else
          api_set_velocity(theMob, 0)
          api_set_animation(theMob, "stand")
        end
        return
      end
    end
  end

  if theMob.state == "stand" then
  
  
    -- randomly turn
    if math.random(1, 4) == 1 then
      -- if there is a player nearby look at them
      local lp = nil
      local s = theMob.object:getpos()

      if theMob.type == "npc" then
        local o = minetest.get_objects_inside_radius(theMob.object:getpos(), 3)

        local yaw = 0
        for _,o in ipairs(o) do
          if o:is_player() then
            lp = o:getpos()
            break
          end
        end
      end

      if lp ~= nil then
        local vec = {x = lp.x - s.x, y = lp.y - s.y, z = lp.z - s.z}
        yaw = (math.atan(vec.z / vec.x) + math.pi / 2) - theMob.rotate
        if lp.x > s.x then
          yaw = yaw + math.pi
        end
      else
        yaw = theMob.object:getyaw() + ((math.random(0, 360) - 180) / 180 * math.pi)
      end
      theMob.object:setyaw(yaw)
    end

    api_set_velocity(theMob, 0)
    api_set_animation(theMob, "stand")

    -- npc's ordered to stand stay standing
    if theMob.type == "npc"
      and theMob.order == "stand" then
      api_set_velocity(theMob, 0)
      theMob.state = "stand"
      api_set_animation(theMob, "stand")
    else
      if theMob.walk_chance ~= 0
        and math.random(1, 100) <= theMob.walk_chance then
        api_set_velocity(theMob, theMob.walk_velocity)
        theMob.state = "walk"
        api_set_animation(theMob, "walk")
      end

      -- jumping mobs only
      --          if theMob.jump and math.random(1, 100) <= theMob.jump_chance then
      --            theMob.direction = {x = 0, y = 0, z = 0}
      --            do_jump(theMob)
      --            theMob.set_velocity(theMob, theMob.walk_velocity)
      --          end
    end

  elseif theMob.state == "walk" then
    local s = theMob.object:getpos()
    local lp = minetest.find_node_near(s, 1, {"group:water"})

    -- water swimmers cannot move out of water
    if theMob.fly
      and theMob.fly_in == "default:water_source"
      and not lp then
      print ("out of water")
      api_set_velocity(theMob, 0)
      theMob.state = "flop" -- change to undefined state so nothing more happens
      api_set_animation(theMob, "stand")
      return
    end
    -- if water nearby then turn away
    if lp then
      local vec = {x = lp.x - s.x, y = lp.y - s.y, z = lp.z - s.z}
      yaw = math.atan(vec.z / vec.x) + 3 * math.pi / 2 - theMob.rotate
      if lp.x > s.x then
        yaw = yaw + math.pi
      end
      theMob.object:setyaw(yaw)

      -- otherwise randomly turn
    elseif math.random(1, 100) <= 30 then
      theMob.object:setyaw(theMob.object:getyaw() + ((math.random(0, 360) - 180) / 180 * math.pi))
    end
    if theMob.jump and api_get_velocity(theMob) <= 0.5
      and theMob.object:getvelocity().y == 0 then
      theMob.direction = {
        x = math.sin(yaw) * -1,
        y = -20,
        z = math.cos(yaw)
      }
      do_jump(theMob)
    end

    api_set_animation(theMob, "walk")
    api_set_velocity(theMob, theMob.walk_velocity)
    if math.random(1, 100) <= 30 then
      api_set_velocity(theMob, 0)
      theMob.state = "stand"
      api_set_animation(theMob, "stand")
    end

    -- exploding mobs
  elseif theMob.state == "attack" and theMob.attack_type == "explode" then
    if not theMob.attack.player
      or not theMob.attack.player:is_player() then
      theMob.state = "stand"
      api_set_animation(theMob, "stand")
      theMob.timer = 0
      theMob.blinktimer = 0
      return
    end
    local s = theMob.object:getpos()
    local p = theMob.attack.player:getpos()
    local dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
    if dist > theMob.view_range or theMob.attack.player:get_hp() <= 0 then
      theMob.state = "stand"
      theMob.v_start = false
      theMob.set_velocity(theMob, 0)
      theMob.timer = 0
      theMob.blinktimer = 0
      theMob.attack = {player = nil, dist = nil}
      api_set_animation(theMob, "stand")
      return
    else
      api_set_animation(theMob, "walk")
      theMob.attack.dist = dist
    end

    local vec = {x = p.x - s.x, y = p.y - s.y, z = p.z - s.z}
    yaw = math.atan(vec.z / vec.x) + math.pi / 2 - theMob.rotate
    if p.x > s.x then
      yaw = yaw + math.pi
    end
    theMob.object:setyaw(yaw)
    if theMob.attack.dist > 3 then
      if not theMob.v_start then
        theMob.v_start = true
        api_set_velocity(theMob, theMob.run_velocity)
        theMob.timer = 0
        theMob.blinktimer = 0
      else
        theMob.timer = 0
        theMob.blinktimer = 0
        if api_get_velocity(theMob) <= 0.5
          and theMob.object:getvelocity().y == 0 then
          local v = theMob.object:getvelocity()
          v.y = 5
          theMob.object:setvelocity(v)
        end
        api_set_velocity(theMob, theMob.run_velocity)
      end
      api_set_animation(theMob, "run")
    else
      api_set_velocity(theMob, 0)
      theMob.timer = theMob.timer + dtime
      theMob.blinktimer = (theMob.blinktimer or 0) + dtime
      if theMob.blinktimer > 0.2 then
        theMob.blinktimer = 0
        if theMob.blinkstatus then
          theMob.object:settexturemod("")
        else
          theMob.object:settexturemod("^[brighten")
        end
        theMob.blinkstatus = not theMob.blinkstatus
      end
      if theMob.timer > 3 then
        local pos = vector.round(theMob.object:getpos())
        entity_physics(pos, 3) -- hurt player/mobs caught in blast area
        if minetest.find_node_near(pos, 1, {"group:water"})
          or minetest.is_protected(pos, "") then
          theMob.object:remove()
          if theMob.sounds.explode ~= "" then
            minetest.sound_play(theMob.sounds.explode, {
              pos = pos,
              gain = 1.0,
              max_hear_distance = 16
            })
          end
          effect(pos, 15, "tnt_smoke.png", 5)
          return
        end
        theMob.object:remove()
        pos.y = pos.y - 1
        mobs:explosion(pos, 2, 0, 1, theMob.sounds.explode)
      end
    end
    -- end of exploding mobs

  elseif theMob.state == "attack"
    and theMob.attack_type == "dogfight" then
    if not theMob.attack.player
      or not theMob.attack.player:getpos() then
      print("stop attacking")
      theMob.state = "stand"
      api_set_animation(theMob, "stand")
      return
    end
    local s = theMob.object:getpos()
    local p = theMob.attack.player:getpos()
    local dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5

    -- fly bit modified from BlockMens creatures mod
    if theMob.fly
      and dist > 2 then

      local nod = minetest.get_node_or_nil(s)
      local p1 = s
      local me_y = math.floor(p1.y)
      local p2 = p
      local p_y = math.floor(p2.y + 1)
      local v = theMob.object:getvelocity()
      if nod
        and nod.name == theMob.fly_in then
        if me_y < p_y then
          theMob.object:setvelocity({
            x = v.x,
            y = 1 * theMob.walk_velocity,
            z = v.z
          })
        elseif me_y > p_y then
          theMob.object:setvelocity({
            x = v.x,
            y = -1 * theMob.walk_velocity,
            z = v.z
          })
        end
      else
        if me_y < p_y then
          theMob.object:setvelocity({
            x = v.x,
            y = 0.01,
            z = v.z
          })
        elseif me_y > p_y then
          theMob.object:setvelocity({
            x = v.x,
            y = -0.01,
            z = v.z
          })
        end
      end

    end
    -- end fly bit

    if dist > theMob.view_range
      or theMob.attack.player:get_hp() <= 0 then
      theMob.state = "stand"
      theMob.set_velocity(theMob, 0)
      theMob.attack = {player = nil, dist = nil}
      api_set_animation(theMob, "stand")
      return
    else
      theMob.attack.dist = dist
    end

    local vec = {x = p.x - s.x, y = p.y - s.y, z = p.z - s.z}
    yaw = (math.atan(vec.z / vec.x) + math.pi / 2) - theMob.rotate
    if p.x > s.x then
      yaw = yaw + math.pi
    end
    theMob.object:setyaw(yaw)
    -- attack distance is 2 + half of mob width so the bigger mobs can attack (like slimes)
    if theMob.attack.dist > ((-theMob.collisionbox[1] + theMob.collisionbox[4]) / 2) + 2 then
      -- jump attack
      if (theMob.jump
        and api_get_velocity(theMob) <= 0.5
        and theMob.object:getvelocity().y == 0)
        or (theMob.object:getvelocity().y == 0
        and theMob.jump_chance > 0) then
        theMob.direction = {
          x = math.sin(yaw) * -1,
          y = -20,
          z = math.cos(yaw)
        }
        do_jump(theMob)
      end
      api_set_velocity(theMob, theMob.run_velocity)
      api_set_animation(theMob, "run")
    else
      api_set_velocity(theMob, 0)
      api_set_animation(theMob, "punch")
      if theMob.timer > 1 then
        theMob.timer = 0
        local p2 = p
        local s2 = s
        p2.y = p2.y + 1.5
        s2.y = s2.y + 1.5
        if minetest.line_of_sight(p2, s2) == true then
          if theMob.sounds.attack then
            minetest.sound_play(theMob.sounds.attack, {
              object = theMob.object,
              max_hear_distance = theMob.sounds.distance
            })
          end
          theMob.attack.player:punch(theMob.object, 1.0,  {
            full_punch_interval=1.0,
            damage_groups = {fleshy=theMob.damage}
          }, vec)
          if theMob.attack.player:get_hp() <= 0 then
            theMob.state = "stand"
            api_set_animation(theMob, "stand")
          end
        end
      end
    end

  elseif theMob.state == "attack"
    and theMob.attack_type == "shoot" then

    local s = theMob.object:getpos()
    local p = theMob.attack.player:getpos()
    if not p then
      theMob.state = "stand"
      return
    end
    p.y = p.y - .5
    s.y = s.y + .5
    local dist = ((p.x - s.x) ^ 2 + (p.y - s.y) ^ 2 + (p.z - s.z) ^ 2) ^ 0.5
    if dist > theMob.view_range
      or theMob.attack.player:get_hp() <= 0 then
      theMob.state = "stand"
      api_set_velocity(theMob, 0)
      api_set_animation(theMob, "stand")
      return
    else
      theMob.attack.dist = dist
    end

    local vec = {x = p.x - s.x, y = p.y - s.y, z = p.z - s.z}
    yaw = (math.atan(vec.z / vec.x) + math.pi / 2) - theMob.rotate
    if p.x > s.x then
      yaw = yaw + math.pi
    end
    theMob.object:setyaw(yaw)
    api_set_velocity(theMob, 0)

    if theMob.shoot_interval
      and theMob.timer > theMob.shoot_interval
      and math.random(1, 100) <= 60 then
      theMob.timer = 0

      api_set_animation(theMob, "punch")

      if theMob.sounds.attack then
        minetest.sound_play(theMob.sounds.attack, {
          object = theMob.object,
          max_hear_distance = theMob.sounds.distance
        })
      end

      local p = theMob.object:getpos()
      p.y = p.y + (theMob.collisionbox[2] + theMob.collisionbox[5]) / 2
      local obj = minetest.add_entity(p, theMob.arrow)
      local amount = (vec.x ^ 2 + vec.y ^ 2 + vec.z ^ 2) ^ 0.5
      local v = obj:get_luaentity().velocity
      vec.y = vec.y + theMob.shoot_offset -- this makes shoot aim accurate
      vec.x = vec.x *v / amount
      vec.y = vec.y *v / amount
      vec.z = vec.z *v / amount
      obj:setvelocity(vec)
    end
  end
end
