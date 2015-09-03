function api_do_attack(theMob, player, dist)
  if theMob.state ~= "attack" then
    if math.random(0,100) < 90
      and theMob.sounds.war_cry then
      minetest.sound_play(theMob.sounds.war_cry,{
        object = theMob.object,
        max_hear_distance = theMob.sounds.distance
      })
    end
    theMob.state = "attack"
    theMob.attack.player = player
    theMob.attack.dist = dist
  end
end


function api_set_velocity(theMob, v)
  v = (v or 0)
  if theMob.drawtype
    and theMob.drawtype == "side" then
    theMob.rotate = math.rad(90)
  end
  local yaw = theMob.object:getyaw() + theMob.rotate
  local x = math.sin(yaw) * -v
  local z = math.cos(yaw) * v
  theMob.object:setvelocity({x = x, y = theMob.object:getvelocity().y, z = z})
end

function api_get_velocity(theMob)
  local v = theMob.object:getvelocity()
  return (v.x ^ 2 + v.z ^ 2) ^ (0.5)
end

function api_set_animation(theMob, type)
  if not theMob.animation then
    return
  end
  if not theMob.animation.current then
    theMob.animation.current = ""
  end
  if type == "stand"
    and theMob.animation.current ~= "stand" then
    if theMob.animation.stand_start
      and theMob.animation.stand_end
      and theMob.animation.speed_normal then
      theMob.object:set_animation({
        x = theMob.animation.stand_start,
        y = theMob.animation.stand_end},
      theMob.animation.speed_normal, 0)
      theMob.animation.current = "stand"
    end
  elseif type == "walk"
    and theMob.animation.current ~= "walk"  then
    if theMob.animation.walk_start
      and theMob.animation.walk_end
      and theMob.animation.speed_normal then
      theMob.object:set_animation({
        x = theMob.animation.walk_start,
        y = theMob.animation.walk_end},
      theMob.animation.speed_normal, 0)
      theMob.animation.current = "walk"
    end
  elseif type == "run"
    and theMob.animation.current ~= "run"  then
    if theMob.animation.run_start
      and theMob.animation.run_end
      and theMob.animation.speed_run then
      theMob.object:set_animation({
        x = theMob.animation.run_start,
        y = theMob.animation.run_end},
      theMob.animation.speed_run, 0)
      theMob.animation.current = "run"
    end
  elseif type == "punch"
    and theMob.animation.current ~= "punch"  then
    if theMob.animation.punch_start
      and theMob.animation.punch_end
      and theMob.animation.speed_normal then
      theMob.object:set_animation({
        x = theMob.animation.punch_start,
        y = theMob.animation.punch_end},
      theMob.animation.speed_normal, 0)
      theMob.animation.current = "punch"
    end
  end
end

function api_on_punch(theMob, hitter, tflp, tool_capabilities, dir)
  -- weapon wear
  local weapon = hitter:get_wielded_item()
  if weapon:get_definition().tool_capabilities ~= nil then
    local wear = ( (weapon:get_definition().tool_capabilities.full_punch_interval or 1.4) / 75 ) * 9000
    weapon:add_wear(wear)
    hitter:set_wielded_item(weapon)
  end

  -- weapon sounds
  if weapon:get_definition().sounds ~= nil then
    local s = math.random(0, #weapon:get_definition().sounds)
    minetest.sound_play(weapon:get_definition().sounds[s], {
      object=hitter,
      max_hear_distance = 8
    })
  else
    minetest.sound_play("default_punch", {
      object = hitter,
      max_hear_distance = 5
    })
  end

  -- exit here if dead
  if check_for_death(theMob) then
    return
  end

  -- blood_particles
  if theMob.blood_amount > 0
    and not disable_blood then
    local pos = theMob.object:getpos()
    pos.y = pos.y + (-theMob.collisionbox[2] + theMob.collisionbox[5]) / 2
    effect(pos, theMob.blood_amount, theMob.blood_texture)
  end

  -- knock back effect
  if theMob.knock_back > 0 then
    local kb = theMob.knock_back
    local r = theMob.recovery_time
    local v = theMob.object:getvelocity()
    if tflp < tool_capabilities.full_punch_interval then
      if kb > 0 then
        kb = kb * ( tflp / tool_capabilities.full_punch_interval )
      end
      r = r * ( tflp / tool_capabilities.full_punch_interval )
    end
    theMob.object:setvelocity({x = dir.x * kb,y = 0,z = dir.z * kb})
    theMob.pause_timer = r
  end

  -- attack puncher and call other mobs for help
  if theMob.passive == false
    and not theMob.tamed then
    if theMob.state ~= "attack" then
      theMob.do_attack(theMob, hitter, 1)
    end
    -- alert others to the attack
    local obj = nil
    for _, oir in pairs(minetest.get_objects_inside_radius(hitter:getpos(), 5)) do
      obj = oir:get_luaentity()
      if obj then
        if obj.group_attack == true
          and obj.state ~= "attack" then
          obj.do_attack(obj, hitter, 1)
        end
      end
    end
  end
end

-- modified from TNT mod
function entity_physics(pos, radius)
  radius = radius * 2
  local objs = minetest.get_objects_inside_radius(pos, radius)
  local obj_pos, obj_vel, dist
  for _, obj in pairs(objs) do
    obj_pos = obj:getpos()
    obj_vel = obj:getvelocity()
    dist = math.max(1, vector.distance(pos, obj_pos))
    if obj_vel ~= nil then
      obj:setvelocity(calc_velocity(pos, obj_pos, obj_vel, radius * 10))
    end
    local damage = (4 / dist) * radius
    obj:set_hp(obj:get_hp() - damage)
  end
end


-- from TNT mod
function calc_velocity(pos1, pos2, old_vel, power)
  local vel = vector.direction(pos1, pos2)
  vel = vector.normalize(vel)
  vel = vector.multiply(vel, power)
  local dist = vector.distance(pos1, pos2)
  dist = math.max(dist, 1)
  vel = vector.divide(vel, dist)
  vel = vector.add(vel, old_vel)
  return vel
end

-- on mob death drop items
function check_for_death(theMob)
  local hp = theMob.object:get_hp()
  if hp > 0 then
    theMob.health = hp
    if theMob.sounds.damage ~= nil then
      minetest.sound_play(theMob.sounds.damage,{
        object = theMob.object,
        max_hear_distance = theMob.sounds.distance
      })
    end
    return false
  end
  local pos = theMob.object:getpos()
  theMob.object:remove()
  local obj = nil
  for _,drop in ipairs(theMob.drops) do
    if math.random(1, drop.chance) == 1 then
      obj = minetest.add_item(pos,
        ItemStack(drop.name.." "..math.random(drop.min, drop.max)))
      if obj then
        obj:setvelocity({
          x = math.random(-1, 1),
          y = 5,
          z = math.random(-1, 1)
        })
      end
    end
  end
  if theMob.sounds.death ~= nil then
    minetest.sound_play(theMob.sounds.death,{
      object = theMob.object,
      max_hear_distance = theMob.sounds.distance
    })
  end
  if theMob.on_die then
    theMob.on_die(theMob, pos)
  end
  return true
end

-- follow what I'm holding ?
function follow_holding(theMob, clicker)
  local item = clicker:get_wielded_item()
  local t = type(theMob.follow)

  -- single item
  if t == "string"
  and item:get_name() == theMob.follow then
    return true

  -- multiple items
  elseif t == "table" then
    for no = 1, #theMob.follow do
      if theMob.follow[no] == item:get_name() then
        return true
      end
    end
  end

  return false
end
