--[[ Resources, mk2.
In this version we'll barebones it, to avoid confusing anyone. ]] 

-- Global cache (locally bound to prevent abuse)
local _resources = {}

-- Global cache (locally bound to prevent abuse)
local _transitions = {}

-- Global namespace-like structuring again.
Resources = {}

-- Gets a pointer of the resource table.
Resources.Get = function(name)
    return _resources[name]
end

-- temporary utilities
local utils = {}
utils.table_has_string_child = function(t, k)
    if t[k] == nil then
        return false
    end

    if type(t[k]) == "string" then
        return true
    end
    return false
end

utils.table_has_number_child = function(t, k)
    if t[k] == nil then
        return false
    end

    if type(t[k]) == "number" then
        return true
    end
    return false
end

utils.table_has_table_child = function(t, k)
    if t[k] == nil then
        return false
    end

    if type(t[k]) == "table" then
        return true
    end
    return false
end

-- Ensure that the transition is valid.  This prevents random crashes.
local __is_valid_transition = function(transition)
    local t = rawget(transition, "_storage")
    if t == nil then
        print("tvalid: 1")
        return false
    end

    --[[ we don't use transition names yet]]
    --[[
    if not utils.table_has_string_child(t, "name") then
        print("tvalid: 2")
        return false
    end ]]

    if not utils.table_has_table_child(t, "conditions") then
        print("tvalid: 3")
        return false
    end

    if not utils.table_has_string_child(t, "source") then
        print("tvalid: 4")
        return false
    end

    if not utils.table_has_string_child(t, "destination") then
        print("tvalid: 5")
        return false
    end


    if not utils.table_has_number_child(t, "temperature") then
        print("tvalid: 6")
        return false
    end

    if not utils.table_has_number_child(t, "energy") then
        print("tvalid: 7")
        return false
    end

    return true
end

local __transition_bilateral_install = function(transition, source, destination)
    if not __is_valid_transition(transition) then
        print("invalid transition")
        return false
    end

    local ss = rawget(source, "_storage")
    local ds = rawget(destination, "_storage")

    --[[ Structure is simple:
    Source -> Destination is always endothermic;
    Destination -> Source is always exothermic. ]]

    function has_transition(t, tt)
        for _, v in pairs(t) do
            if v == tt then
                return true
            end
        end
        return false
    end

    if has_transition(ss.transitions.endothermic._all, transition) then
        if has_transition(ds.transitions.exothermic._all, transition) then
            return true
        end
        return false
    end

    if has_transition(ds.transitions.exothermic._all, transition) then
        return false
    end

    -- Install
    table.insert(ss.transitions.endothermic._all, transition)
    table.insert(ds.transitions.exothermic._all, transition)

    if ss.transitions.endothermic.default == nil then
        ss.transitions.endothermic.default = transition
    end

    if ds.transitions.exothermic.default == nil then
        ds.transitions.exothermic.default = transition
    end

    return true
end

-- Metatable function collection
local _resource_metafunctions = {
    register_transition = function(self, transition)
        if transition == nil then
            print("bad transition")
            return false
        end

        -- For those times when overcoming metatables is a chore.
        local s = rawget(self, "_storage")
        local t = rawget(transition, "_storage")

        -- resource must be be source or dest in transition.
        if not t.source == s.name then
            if not t.destination == s.name then
                print("bad names")
                return false
            end
        end

        -- get source
        local source = Resources.Get(t.source)
        if source == nil then
            print("bad source")
            return false
        end

        -- get destination
        local destination = Resources.Get(t.destination)
        if destination == nil then
            print("bad dest")
            return false
        end

        -- one of these is going to be 's', but it's irrelevant.
        return __transition_bilateral_install(transition, source, destination)
    end,

    --[[ add_energy
    returns (resource_type, final_temperature, spare_energy)

    spare_energy is typically due to incomplete phase shifts. 
    
    This is an example. ]]
    add_energy = function(self, energy, mass, initial_temperature)
        local storage = rawget(self, "_storage")
        local shc = storage.heat_capacity

        local exothermic = storage.transitions.exothermic.default
        if exothermic ~= nil then
            exothermic = rawget(storage.transitions.exothermic.default, "_storage")
        else
            exothermic = nil
        end

        local endothermic = storage.transitions.endothermic.default
        if endothermic ~= nil then
            endothermic = rawget(storage.transitions.endothermic.default, "_storage")
        else
            endothermic = nil
        end

        -- Ensure we have the right starting resource type.
        if exothermic ~= nil then
            if exothermic.temperature > initial_temperature then
                return Resources.Get(exothermic.source):add_energy(energy,
                    mass, initial_temperature)
            end
        end

        if endothermic ~= nil then
            if endothermic.temperature < initial_temperature then
                return Resources.Get(endothermic.destination):add_energy(energy,
                    mass, initial_temperature)
            end
        end

        --[[ These are identical, either way energy flows,
        but if someone does something strange (like making the specific
        heat capacity negative), we want to support their vision,
        as warped as it may be from standard science's view. ]]
        local tmod = energy / (mass * shc)
        local tfinal = initial_temperature + tmod

        -- If it goes down, it's exothermic.
        if tmod < 0 then
            -- Since we're adding energy in a standard sense...
            if exothermic == nil then
                return self, tfinal, 0
            end

            --[[ Otherwise we need to worry about a potential phase change.
            Only if the final projected temperature is below do we worry about
            phase shifting down.  If it's not, we just return with the remaining
            energy. ]]
            if tfinal <= exothermic.temperature then
                --[[ This code block is a little weirder.  Remaining energy
                should *always* be negative. ]]

                -- 1. Get the difference of (initial - exothermic-phase).
                -- For example: 120 C Steam - 100 C water = 20.
                local diff = initial_temperature - exothermic.temperature

                -- 2. Calculate how much the temperature change costs.
                -- Remember: q = mct, as we're in one phase.
                local diff_energy = mass * shc * diff

                -- 3. Remaining energy (total - cost to reach phase)
                local rem_energy = energy + diff_energy

                -- 4. How much does the phase change cost?
                local phase_cost = -(exothermic.energy * mass)

                -- If the cost is less than what we have, we win!
                if phase_cost < rem_energy then
                    --[[ Failed phase change, return energy as negative.
                    We can use negative energy as a solution to mark and
                    incomplete phase change (going downward). ]]
                    return self, exothermic.temperature, rem_energy
                end

                -- If we have the energy we change phases then repeat with the remainder.
                return Resources.Get(exothermic.source):add_energy(
                    rem_energy - phase_cost, mass, exothermic.temperature)
            end
        else -- If it goes up, it's endothermic.
            if endothermic == nil then
                return self, tfinal, 0
            end

            -- Otherwise we need to worry about a potential phase change.
            if tfinal >= endothermic.temperature then
                -- 1. Remove the difference.
                local diff = endothermic.temperature - initial_temperature

                -- 2. Calculate how much the temperature change costs.
                -- Remember: q = mct
                local diff_energy = mass * shc * diff

                -- 3. Remaining energy.
                -- Simple: energy - diff_energy
                local rem_energy = energy - diff_energy

                -- 4. How much does the phase change cost?
                local phase_cost = endothermic.energy * mass

                -- If the cost is less than what we have, we win.
                if phase_cost > rem_energy then
                    --[[ Failed phase change, return energy as positive.
                    We can use negative energy as a solution to mark and
                    incomplete phase change (going upward). ]]
                    return self, endothermic.temperature, rem_energy
                end

                -- If it's greater, phase change, then drop further.
                -- Time to be lazy/modular!
                return Resources.Get(endothermic.source):add_energy(
                    energy - (phase_cost + diff_energy), mass, endothermic.temperature)                
            end
        end
        return self, tfinal, 0
    end
}

local _resource_metatable = {
    -- return t[k]
    __index = function(t, k)
        if t._storage[k] == nil then
            -- Look for functions we want to allow.
            if _resource_metafunctions[k] ~= nil then
                return _resource_metafunctions[k]
            end
        end
        return t._storage[k]
    end,

    -- t[k] = v
    __newindex = function(t, k, v)
        return -- block it
    end
}

--[[ A super-simple implementation of registering a resource.
It changes the previous formulation by making the internal storage structure,
and adds a few functions to the resource. ]]
Resources.Register = function(name, heat_capacity)
    local res = {
        _storage = {
            name = name,
            heat_capacity = heat_capacity,
            transitions = {
                exothermic = {
                    default = nil,
                    _all = {},
                },
                endothermic = {
                    default = nil,
                    _all = {},
                }
            }
        }
    }

    -- Push/clobber
    _resources[name] = res

    -- Metatable registration
    setmetatable(res, _resource_metatable)

    return res
end