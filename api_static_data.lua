function api_get_staticdata(theMob)

  -- remove mob when out of range unless tamed
  if mobs.remove and theMob.remove_ok and not theMob.tamed then
    print ("REMOVED", theMob.remove_ok, theMob.name)
    theMob.object:remove()
  end
  theMob.remove_ok = true
  theMob.attack = nil
  theMob.following = nil

  local tmp = {}
  for _,stat in pairs(theMob) do
    local t = type(stat)
    if  t ~= 'function'
      and t ~= 'nil'
      and t ~= 'userdata' then
      tmp[_] = theMob[_]
    end
  end
  -- print('===== '..self.name..'\n'.. dump(tmp)..'\n=====\n')
  return minetest.serialize(tmp)
end

    