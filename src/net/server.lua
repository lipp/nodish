local nexttick = require'nexttick'.nexttick
local socket = require'socket'
assert(socket._VERSION:match('^LuaSocket 3%.'))
local emitter = require'emitter'
local ev = require'ev'
local nsocket = require'net.socket'

local loop = ev.Loop.default

--- creates and binds a listening socket for
-- ipv4 and (if available) ipv6.
local sbind = function(host,port,backlog)
  local server = socket.tcp6()
  assert(server:setoption('ipv6-v6only',false))
  assert(server:setoption('reuseaddr',true))
  assert(server:bind(host,port))
  assert(server:listen())
  return server
end

local listen = function(port,host,backlog,cb)
  local self = emitter.new()
  local lsock = sbind(host or '*',port,backlog or 511)
  lsock:settimeout(0)
  nexttick(function()
      self:emit('listening',self)
    end)
  if cb then
    self:once('listening',cb)
  end
  local con_count = 0
  local listen_io = ev.IO.new(
    function()
      local sock,err = lsock:accept()
      if sock then
        local s = nsocket.new()
        s:_transfer(sock)
        con_count = con_count + 1
        s:once('close',function()
            con_count = con_count - 1
            if con_count == 0 then
              self:emit('close')
            end
          end)
        self:emit('connection',s)
      else
        assert(err)
        self:emit('error',err)
      end
    end,
    lsock:getfd(),
  ev.READ)
  listen_io:start(loop)
  
  self.close = function(_,cb)
    listen_io:stop(loop)
    lsock:close()
    if cb then
      self:once('close',cb)
    end
    if con_count == 0 then
      self:emit('close')
    end
  end
  return self
end

return {
  listen = listen
}
