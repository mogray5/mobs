function life_step(theMob, dtime)

  if theMob.type ~= "animal" then
    return
  end

 -- print("life: dtime is " .. dtime)

  theMob.mate_timer = theMob.mate_timer - dtime

  if not theMob.hunger or theMob.hunger < 1 then
    theMob.hunger = 1
  end
  

  -- Increase hunger by chance
  if math.random(1, 10) <= 3 and theMob.hunger < 10 then
    theMob.hunger = theMob.hunger + 1
  end
  
  --print("life: mob " .. theMob.name .. " hunger is: " .. theMob.hunger .. " mate_timer is " .. theMob.mate_timer .. " offspring is " .. theMob.offspring)

  theMob.horny = (theMob.hunger <= 5 and math.random(1, 10) <= 4 and theMob.mate_timer <= .001 and theMob.offspring > 0)

  -- Hungry or horny
  if theMob.hunger > 5 or theMob.horny then


    --NPC Hunt--------------------------------

    local inradius = minetest.get_objects_inside_radius(theMob.object:getpos(),12)
    local ft = 0
    local obj = nil

    for _,oir in ipairs(inradius) do

      obj = oir:get_luaentity()

      if theMob.npc_food_types and theMob.hunger  > 5  and obj ~= nil then

        --print("life: Checking food type " .. string.gsub(obj.name, ":", "_"))

        ft = FOOD_TYPES[string.gsub(obj.name, ":", "_")]
        if ft then
          --print("life: " .. obj.name .. " food type: " .. ft)
          if theMob.npc_food_types and ft then
            if theMob.npc_food_types["type_" .. ft] and theMob.hunger > 7 then

              -- Eat npc
              --print("life: " .. obj.name .. " consumed")

              obj.object:remove()

              if ft == 1 then
                theMob.hunger = theMob.hunger - 15
              else 
                if ft == 4 then
                  theMob.hunger = theMob.hunger - 2
                else
                  theMob.hunger = theMob.hunger - 5
                end
              end
            end
          end
        end

      else

        --Mating-------------------------------------------

        if theMob.horny and obj ~= nil then

          --print ("life: mob " .. theMob.name .. " looking for mate")

          local selfpos = theMob.object:getpos()
          local matepos = obj.object:getpos()


          if obj.horny
            and obj.name == theMob.name
            and (matepos.x + matepos.y + matepos.z) ~= (selfpos.x + selfpos.y + selfpos.z) then

            if math.random(1, 10) < 5 then
              --print("life: mating " .. theMob.name)
              theMob.offspring = theMob.offspring - 1
              local mob = minetest.add_entity(theMob.object:getpos(), theMob.name)

              -- setup the hp, armor, drops, etc... for this specific mob
              if mob then
                local ent2 = mob:get_luaentity()
                --local newHP = mob.hp_max
                --mob.set_hp( newHP )
                ent2.horny = false
                ent2.mate_timer = 5
                ent2.offspring = 3
              end
              theMob.horny = false
              theMob.mate_timer = 2
              obj.horny = false
              obj.mate_timer = 2
            else
              --print("life: mate chance failed")
            end --end chance
          else
            --print("life: obj horny?: " .. tostring(obj.horny))
          end --end obj horny
        end

        --END Mating-------------------------------------------

      end --npc food check / mating

    end


    --END NPC Hunt and mating--------------------------------

    if theMob.biome_food_types and theMob.hunger > 5 then

      --Biome Food Search-------------------------------

      local pos = theMob.object:getpos()
      local fooditem = minetest.find_node_near(pos, 2, theMob.biome_food_types)

      if fooditem ~= nil and fooditem.y <= pos.y then

        --print("life: " .. theMob.name .. " consuming food item")

        local node = minetest.get_node(fooditem)

        -- Replace node if replacement exists, else remove
        local replaceItem = REPLACEMENT_TYPES[string.gsub(node.name, ":", "_")]
        if replaceItem then
          minetest.set_node(fooditem, {name=replaceItem})
        else
          minetest.remove_node(fooditem)
        end

        theMob.hunger = theMob.hunger - 2

      end

    end --end biome_food_types

    --END Biome Food Search-----------------------------

    --END Food Block

    -- Die from hunger?
    if theMob.hunger >= 10 then
      if math.random(1, 20) <= 5 then
        --print("life: " .. theMob.name .. " died of hunger")
        theMob.object:remove()
        return
      end
    end

  end --end hunger/horny block
end

