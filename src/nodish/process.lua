local ev = require'ev'
local S = require'syscall'
local emitter = require'nodish.emitter'
local stream = require'nodish.stream'
local tinsert = table.insert

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
  nexttick = require'nodish.nexttick'.nexttick,
  stdin = stdin(),
  stdout = stdout(),
  loop = loop,
  unloop = unloop,
}
