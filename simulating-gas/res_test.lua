-- We'll catch it here for the sake of keeping it useful
water = {}

-- Ice -(ex)-> Water
table.insert(water, Resources.Register("Ice", nil, {"Water", 273.15}))

-- Water -(ex)-> Ice;
-- Water -(en)-> Steam
table.insert(water, Resources.Register("Water", {"Ice", 273.15}, {"Steam", 373.15}))

-- Steam -(ex)-> Water
table.insert(water, Resources.Register("Steam", {"Water", 373.15}, nil))


--- Grab an example base type.
example = water[math.random(#water)]

--- Generate a random temperature, so we can determine the proper type.
temp = math.random(0, math.ceil(water[2].exo_form[2] + 100))

-- Gets the temperature bounds as a string.
function get_bounds(r)
    local rr = ""

    if r.exo_form == nil then
        s = "0.00 K - "
    else
        s = ([[%4.2f - ]]):format(r.exo_form[2])
    end

    if r.endo_form == nil then
        s = ([[%s infinity]]):format(s)
    else
        s = ([[%s %4.2f]]):format(s, r.endo_form[2])
    end
    return s
end

-- Quick hacky function
function solve_type_chain(res, temperature)

  -- Shifts up forever until it peaks.
  function shift_up(r, t)
    if r.endo_form == nil then
      return r
    end

    if r.endo_form[2] < t then
      return shift_up(Resources.Get(r.endo_form[1]), t)
    end
    return r
  end

  -- Shifts down forever until it bottoms out.
  function shift_down(r, t)
    if r.exo_form == nil then
      return r
    end

    if r.exo_form[2] > t then
      return shift_down(Resources.Get(r.exo_form[1]), t)
    end
    return r
  end

  return shift_down(shift_up(res, temperature), temperature)
end

solved = solve_type_chain(example, temp)

solved_bounds = get_bounds(solved)

print(([[
Initial type:            %s (%s)
Starting temperature:    %d K
Determined type:         %s (%s)]]):format(
        example.name, get_bounds(example),
        temp,
        solved.name, get_bounds(solved)
    )
)
