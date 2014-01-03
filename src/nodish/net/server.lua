local nextTick = require'nodish.process'.nextTick
local S = require'syscall'
local emitter = require'nodish.emitter'
local ev = require'ev'
local nsocket = require'nodish.net.socket'
local util = require'nodish._util'

local loop = ev.Loop.default

--- creates and binds a listening socket for
-- ipv4 and (if available) ipv6.
local sbind = function(host,port,backlog)
  local server = S.socket('inet','stream')
  server:nonblock(true)
  server:setsockopt('socket','reuseaddr',true)
  -- TODO respect host
  server:bind(S.t.sockaddr_in(port,'127.0.0.1'))
  server:listen(backlog)
  return server
end

local listen = function(port,host,backlog,cb)
  local self = emitter.new()
  local lsock = sbind(host or '*',port,backlog or 511)
  nextTick(function()
      self:emit('listening',self)
    end)
  if cb then
    self:once('listening',cb)
  end
  local conCount = 0
  local listenIo = ev.IO.new(
    function()
      local ss = S.types.t.sockaddr_storage()
      local sock,err = lsock:accept()--ss,nil,'nonblock')
      if sock then
        local s = nsocket.new({
            fd = sock,
        })
        conCount = conCount + 1
        s:once('close',function()
            conCount = conCount - 1
            if conCount == 0 then
              self:emit('close')
            end
          end)
        self:emit('connection',s)
      else
        assert(err)
        self:emit('error',tostring(err))
      end
    end,
    lsock:getfd(),
  ev.READ)
  listenIo:start(loop)
  
  self.unref = function()
    util.unref(listenIo)
  end
  
  self.ref = function()
    util.ref(listenIo)
  end
  
  self.address = function()
    if lsock then
      local addr = lsock:getsockname()
      local resObj = {
        address = tostring(addr.addr),
        port = addr.port,
        family = family[addr.family],
      }
      return resObj
    end
  end
  
  self.close = function(_,cb)
    listenIo:stop(loop)
    lsock:close()
    if cb then
      self:once('close',cb)
    end
    if conCount == 0 then
      self:emit('close')
    end
  end
  return self
end

return {
  listen = listen
}
