local ev = require'ev'
local tinsert = table.insert

local pcall_array = function(arr)
  for _,f in ipairs(arr) do
    local ok,err = pcall(f)
    if not ok then
      print('nexttick callback failed',err)
    end
  end
end

local create_nexttick = function(loop)
  if ev.Idle then
    local on_idle = {}
    local idle_io = ev.Idle.new(
      function(loop,idle_io)
        idle_io:stop(loop)
        pcall_array(on_idle)
        on_idle = {}
      end)
    return function(f)
      tinsert(on_idle,f)
      idle_io:start(loop)
    end
  else
    local eps = 2^-40
    local once
    local on_timeout = {}
    local timer_io = ev.Timer.new(
      function(loop,timer_io)
        once = true
        timer_io:stop(loop)
        pcall_array(on_timeout)
        on_timeout = {}
      end,eps)
    return function(f)
      tinsert(on_timeout,f)
      if once then
        timer_io:again(loop)
      else
        timer_io:start(loop)
      end
    end
  end
end

return {
  nexttick = create_nexttick(ev.Loop.default)
}
