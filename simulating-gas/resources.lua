--[[ As with all Lua I write here, we'll let users break it if they want.
Since we're only going to use protected calls (pcalls) for certain code,
any breakage will result in the simulation failing to execute
(or halting on bad code).  This means we have to be careful as well, but
it removes the need to write debug handling everywhere. ]]

--[[ Global cache which exists only in the scope of this file.
The leading underscore is just to ensure we never collide with it
within function scopes. ]]
local _resources = {}

--[[ This is the final form/cache of resources, it is rebuilt whenever
Resources.Finalise is called. ]]
local _resources_final = {}

-- Resource (working state) metatable (TODO)
local _resource_meta_working = {}

-- Resource (final state) metatable (TODO)
local _resource_meta_final = {}

--[[ Global table acting as a namespace.  We install into it below,
as it's easier to read (though we pay an initialiation cost).

Eventually all of these functions can be moved to the Lua C API if
performance is required, or the table definition can be crammed into the
table below cleanly.  Either way, this has a minor performance penalty
in its current form.  (Again, it's only for initial data loading, so
I'm not worried; function over premature optimisation.)]]
Resources = {}

-- This function resets the resource cache.
Resources.Reset = function()
  -- Old table should be garbage collected once the next line executes.
  _resources = {}
end

-- Attempt to finalise the resources
Resources.Finalise = function()
  -- todo, we'll talk about this.
end

-- Used to check if we need to finalise.
Resources.AreFinalised = function()
  -- If there are resources in the final table we have finalised.
  return #_resources_final > 0
end

-- Gets a pointer of the resource table.
Resources.Get = function(name)
    return _resources[name]
end

--[[ Registers a resource, by name, building a wrapped working copy.
This isn't particularly simple code, so I'll document it heavily.

If the name collides with a previous definition it will be clobbered.

The general idea here is to create a resource and determine if
it can transition up (right) or down (left); exothermic transitions
are the loss of energy (so water -> ice) and endothermic are gain
(so water -> steam, or ice -> water).  If the transition isn't allowed
then we can ignore it.  Special transitions (caused by magic, machines,
and so on) can be handled in special state transitions; what we're defining
is normal transitions, that happen as part the resource or tile tick.

name is the working name, but it should also be the locale/translation unit
value (e.g. "Oxygen" can be translated from "Oxygen" to whatever locale;
or you could use RAW_RESOURCE_OXYGEN_GAS, or RAW_RESOURCE_WATER_LIQUID).
The naming convention is up to you.

transition_exothermic and transition_endothermic should be two value tables
containing a string and a floating point value.  The string should be
the name of the resource, and the value should be the temperature in
Kelvins.

For example, consider a typical (and simplified) water set:

    -- no exothermic reaction.
    -- Ice -(en)-> Water
    Resources.Register("Ice", nil, {"Water", 273.15})

    -- Water -(ex)-> Ice;
    -- Water -(en)-> Steam
    Resources.Register("Water", {"Ice", 273.15}, {"Steam", 373.15})

    -- Steam -(ex)-> Water
    Resources.Register("Steam", {"Water", 373.15}, nil)

We will talk about transitions later, but they will belong in this file too.
Since we only want basic types to be stored here, and we will typically limit
technology (or make it border of magic or be well into the fantastical), the
special transitions can cover things like carbon <-> diamond instead of
carbon <-> graphite or carbon <-> soot (for example). ]]
Resources.Register = function(name, transition_exothermic, transition_endothermic)

  -- This is a closure to validate an argument, later it may be moved out.
  function validate_transition(alias, res_name, tbl)

    -- Ignore nil types, this is by design.
    if tbl == nil then
        return nil
    end

    -- Make it invalid
    if type(tbl) ~= "table" then
      print(([[%s for '%s' is not a table (got '%s' type instead))]]):format(alias, res_name, type(tbl)))
      return nil
    end

    -- It is a table, validate [1] and [2]
    if #tbl ~= 2 then
        if #tbl < 2 then
            print(([[%s for '%s' is a table which is too short (needed 2 values, got '%d' type instead))]]):format(alias, name, #tbl))
            return nil
        end
        print(([[%s for '%s' is a table which is too long (needed 2 values, got '%d' type instead))]]):format(alias, name, #tbl))
        return nil
    end


    if type(tbl[1]) ~= "string" then
      print(([[%s[1] for '%s' is not a string (got '%s' type instead))]]):format(alias, res_name, type(tbl)))
      return nil
    end

    if type(tbl[2]) ~= "number" then
      print(([[%s[1] for '%s' is not a number (got '%s' type instead))]]):format(alias, res_name, type(tbl)))
      return nil
    end

    return tbl
  end

  ex = validate_transition("transition_exothermic", name, transition_exothermic)
  en = validate_transition("transition_endothermic", name, transition_endothermic)

  -- `resource` is a table containing the information we have.
  local resource = {
    name = name,

    -- The name of the resource we transition to exothermically.
    exo_form = ex,

    -- The name of the resource we transition to endothermically.
    endo_form = en,
  }

  --[[ Lua tables are hashed and indexed;
  to allow for updates (without necessarily maintaining names) it's easiest to
  use the hash format. ]]
  _resources[name] = resource

  -- Assign the working metatable to the resource here.
  setmetatable(resource, _resource)

  -- Finally, return the new (wrapped) resource pointer.
  return resource
end