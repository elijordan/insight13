--

local Insight = {}

Insight.functions = {
  join = {
    name = "Join",
    description = "Adds last recorded and newly reported values together",
    type = "transform",
    history = {
      limit = {
        value = "1"
      }
    },
    inlets = {
      {
        name = "Input Signal 1",
        description = "Input signal 1",
        primitive_type = "NUMBER"
      },
      {
        name = "Input Signal 2",
        description = "Input signal 2",
        primitive_type = "NUMBER"
      },
    },
    outlets = {
      data_type = "NUMBER"
    },
    fn = function(request)
      local data_in = request.data
      local constants = request.args.constants
      local history = request.history
      local data_out = {}

      log.debug("Request: " .. to_json(request))
      log.debug("Data In: " .. to_json(data_in))

      -- Iterate over new datapoints ("array")
      for _, dp in ipairs(data_in) do
        -- Iterate to each signal's history object (table)
        for key, object in pairs(history) do
          -- Iterate through given signal's data history ("array")
          for i, val in ipairs(object) do
            -- Assume desired value comes in the second array index from an inlet (not outlet)
            if val.tags.inlet == "0" then
              dp.value = dp.value + val.value
            end
            -- Each signal value in dataOUT should keep the incoming metadata
            table.insert(data_out, dp)
          end
        end
      end

      log.debug("Join DataOut: " .. to_json({data_out}))

      return {data_out}
    end
  },
  thresholds = {
    name = "Min/max thresholds",
    description = "Sets threshold bounds beyond which an alert state is generated",
    type = "rule",
    constants = {
      {
        name = "Max",
        description = "Maximum allowed value",
        type = "number"
      },
      {
        name = "Min",
        description = "Minimum allowed value",
        type = "number"
      },
      {
        name = "level",
        description = "The alert level if the bounds are breached",
        type = "number",
        enum = {1,2,3,4},
        default = 1
      }
    },
    inlets = {
      name = "Input Signal",
      description = "Input signal",
      primitive_type = "NUMBER"
    },
    outlets = {
      data_type = "STATUS"
    },
    fn = function(request)
      -- Datapoint is first & only item in data array
      local dp = request.data[1]
      local constants = request.args.constants
      local data_out = {}

      -- Copy relevant content from ingest object
      data_out.ts = dp.ts
      data_out.gts = dp.gts
      data_out.origin = dp.origin
      data_out.generated = dp.generated
      data_out.ttl = dp.ttl
      data_out.value = { value = dp.value }
      data_out.tags = {}

      if dp.value  >= constants.Max then
        data_out.value.level = constants.level
        data_out.value.type = "Maximum threshold breach"
      elseif dp.value <= constants.Min then
        data_out.value.level = constants.level
        data_out.value.type = "Minimum threshold breach"
      else
        data_out.value.level = 0
        data_out.value.type = "Within threshold bounds"
      end

      -- Retrieve previous level
      local previous_state = Keystore.get({key = data_out.generated}).value

      -- If the state has not changed, do nothing, else, set new state and push
      if tonumber(previous_state) == tonumber(data_out.value.level) then
        return {{}}
      else
        Keystore.set({key = data_out.generated, value = data_out.value.level})
        return {{data_out}}
      end
    end
  }
}

function Insight.info()
  info = {
    name = "13 Insights",
    description = "Eli's custom insights",
    group_id_required = false,
    wants_lifecycle_events = false
  }
  return info
end

function Insight.listInsights()
  local insights = {}
  for k,v in pairs(Insight.functions) do
    v.fn = nil
    v.id = k
    table.insert(insights, v)
  end
  list = {
    total = #insights,
    count = #insights,
    insights = insights,
  }
  log.debug("LIST: " .. to_json(list))
  return list
end

function Insight.infoInsight(request)
  local found = Insight.functions[request.function_id]
  if found == nil then
    return nil, {
      name = "Not Implemented",
      message = "Function \"" .. tostring(request.function_id) .. "\" is not implemented"
    }
  end
  found.id = request.function_id
  found.fn = nil
  return found
end

function Insight.lifecycle(request)
  log.debug("LIFECYCLE: " .. to_json(request))
  return {}
end

function Insight.process(request)
  local found = Insight.functions[request.args.function_id]
  if found == nil then
    return nil, {
      name = "Not Implemented",
      message = "Function \"" .. tostring(request.args.function_id) .. "\" is not implemented"
    }
  end
  return found.fn(request)
end

return Insight
