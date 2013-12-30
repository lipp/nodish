local ev = require'ev'
local tinsert = table.insert

local pcallArray = function(arr)
  for _,f in ipairs(arr) do
    local ok,err = pcall(f)
    if not ok then
      print('process.nextTick callback failed',err)
    end
  end
end

local createNexttick = function(loop)
  if ev.Idle then
    local onIdle = {}
    local idleIo = ev.Idle.new(
      function(loop,idleIo)
        idleIo:stop(loop)
        pcallArray(onIdle)
        onIdle = {}
      end)
    return function(f)
      tinsert(onIdle,f)
      idleIo:start(loop)
    end
  else
    local eps = 2^-40
    local once
    local onTimeout = {}
    local timerIo = ev.Timer.new(
      function(loop,timerIo)
        once = true
        timerIo:stop(loop)
        pcallArray(onTimeout)
        onTimeout = {}
      end,eps,eps)
    return function(f)
      tinsert(onTimeout,f)
      if once then
        timerIo:again(loop)
      else
        timerIo:start(loop)
      end
    end
  end
end

return {
  nextTick = createNexttick(ev.Loop.default)
}
