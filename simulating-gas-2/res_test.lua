-- require Resources.lua
require("Resources")

-- Rebuild out water table.
local water = {}
table.insert(water, Resources.Register("Ice", 2.010))
table.insert(water, Resources.Register("Water", 4.186))
table.insert(water, Resources.Register("Steam", 2.080))

-- Install the now missing transitions.
water[1]:register_transition(
    -- Transition.  No metatable for it yet.    
    {
        _storage = {
            source = "Ice",
            destination = "Water",
            temperature = 273.15,
            energy = 334,

            -- not yet used
            conditions = {},
        }
    }
)

-- Install the now missing transitions.
water[2]:register_transition(
    -- Transition.  No metatable for it yet.    
    {
        _storage = {
            source = "Water",
            destination = "Steam",
            temperature = 373.15,
            energy = 2257,

            -- not yet used
            conditions = {},
        }
    }
)

--[[ Add energy to a resource with a given mass.
Return the temperature and the new type (if it changed). ]]
function add_energy(res, energy, mass, initial_temperature)
    local q = energy
    local m = mass
    local c = rawget(res, "_storage").heat_capacity

    -- t = q/(mc)
    return (q / (m * c)) + initial_temperature
end

function do_test(starting_resource, energy, mass, temp)

    print(([[
    In both cases we'll start with:
        -- %s --
        Mass:                  % 10.2f grams
        Temperature:           % 10.2f Kelvin
        Energy:                % 10.2f joules.
]]):format(starting_resource.name, mass, temp, energy))

    local quick = add_energy(starting_resource, energy, mass, temp)
    print(([[
    Quick output:
        -- %s --
        Final temperature:    % 10.2f K
        Remaining energy:     % 10.2f]]
):format(starting_resource.name, quick, 0))
    if quick < 0 then
        print("        -- That's broken!\n\n")
    end

    local resource, final, rem_energy = starting_resource:add_energy(energy, mass, temp)
    print(([[
    In-depth output:
        -- %s --
        Final temperature:    % 10.2f K (% 10.2f C)
        Remaining energy:     % 10.2f]]
):format(resource.name, final, final-273.15, rem_energy))
    if rem_energy > 0 then
        print("        (Phase change up is incomplete.)")
    else
        if rem_energy < 0 then
            print("        (Phase change down is incomplete.)")
        end
    end
end

print("Water at 80 K")
do_test(water[2], 87015.16, 100, 80)

print("\nWater at 80 C")
do_test(water[2], 87015.16, 100, 80+273.15)

--[[
T_{initial} = 112 C
q = -228729.2 J
m = 100 g
s_steam = 2.080
h_vap = 2257

12 C drop needed, so 12 * 2.080 -> 24.96
24.96 * mass (100) -> 2496 J
(remainder: -226233.2)

cost to phase up would be: 100 * 2257 -> 225700 J
(remainder: -533.2)

533.2 / 419.6 = ~1.3 C drop,
so ~98.73 C
]]
print("\nWater at 112 C - 228729.2 J")
do_test(water[2], -228729.2, 100, (112+273.15))