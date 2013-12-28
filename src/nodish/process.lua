local ev = require'ev'
local S = require'syscall'
local emitter = require'nodish.emitter'
local stream = require'nodish.stream'
local tinsert = table.insert

local pcall_array = function(arr)
  for _,f in ipairs(arr) do
    local ok,err = pcall(f)
    if not ok then
      print('nexttick callback failed',er)
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

local stdin = function()
  local self = emitter.new()
  self.watchers = {}
  stream.readable(self)
  S.stdin:nonblock(true)
  self._read = function()
    return S.stdin:read()
  end
  self:add_read_watcher(S.stdin:getfd())
  return self
end

local stdout = function()
  local self = emitter.new()
  self.watchers = {}
  stream.writable(self)
  S.stdout:nonblock(true)
  self._write = function(_,data)
    return S.stdout:write(data)
  end
  self:add_write_watcher(S.stdout:getfd())
  return self
end

local unloop = function()
  print('quitting')
  ev.Loop.default:unloop()
end

local loop = function()
  local sigkill = 9
  local sigint = 2
  local sigquit = 3
  local sighup = 1
  for _,sig in ipairs({sigkill,sigint,sigquit,sighup}) do
    ev.Signal.new(
      unloop,
    sig):start(ev.Loop.default,true)
  end
  
  local sigpipe = 13
  ev.Signal.new(
    function()
      print('SIGPIPE ignored')
    end,
  sigpipe):start(ev.Loop.default,true)
  
  ev.Loop.default:loop()
end

return {
  new = create_nexttick,
  nexttick = create_nexttick(ev.Loop.default),
  stdin = stdin(),
  stdout = stdout(),
  loop = loop,
  unloop = unloop,
}
