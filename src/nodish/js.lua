local process = require'nodish.process'
local ev = require'ev'
local loop = ev.Loop.default
local timers = {}
local timerCount = 0

setTimeout = function(f,msecs)
  timerCount = timerCount + 1
  local timer = ev.Timer.new(function()
      f()
      timers[timerCount] = nil
    end,msecs*1000)
  timer:start(loop)
  timers[timerCount] = timer
  return timerCount
end

clearTimeout = function(id)
  if timers[id] then
    timers[id]:stop(loop)
  end
end

setInterval = function(f,msecs)
  timerCount = timerCount + 1
  local timer = ev.Timer.new(function()
      f()
    end,msecs*1000,msecs*1000)
  timer:start(loop)
  timers[timerCount] = timer
  return timerCount
end

clearInterval = function(id)
  if timers[id] then
    timers[id]:stop(loop)
  end
end

local table_print
-- from http://lua-users.org/wiki/TableSerialization
table_print = function (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    if not getmetatable(tt) or not getmetatable(tt).__tostring then
      local sb = {}
      for key, value in pairs (tt) do
        table.insert(sb, string.rep (" ", indent)) -- indent it
        if type (value) == "table" and not done [value] then
          done [value] = true
          table.insert(sb, "{\n");
          table.insert(sb, table_print (value, indent + 2, done))
          table.insert(sb, string.rep (" ", indent)) -- indent it
          table.insert(sb, "}\n");
        elseif "number" == type(key) then
          table.insert(sb, string.format("\"%s\"\n", tostring(value)))
        else
          table.insert(sb, string.format(
          "%s = \"%s\"\n", tostring (key), tostring(value)))
        end
      end
      return table.concat(sb)
    else
      return tostring(tt)
    end
  else
    return tt .. "\n"
  end
end

local to_string = function( tbl )
  if  "nil"       == type( tbl ) then
    return tostring(nil)
  elseif  "table" == type( tbl ) then
    return table_print(tbl)
  elseif  "string" == type( tbl ) then
    return tbl
  else
    return tostring(tbl)
  end
end

console = {}

console.log = function(...)
  local args = {...}
  for i,arg in ipairs(args) do
    process.stdout:write(to_string(arg)..'\t')
  end
  process.stdout:write('\n')
end
