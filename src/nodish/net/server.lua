local nextTick = require'nodish.process'.nextTick
local S = require'syscall'
local h = require "syscall.helpers"
local emitter = require'nodish.emitter'
local ev = require'ev'
local nsocket = require'nodish.net.socket'
local util = require'nodish._util'

local loop = ev.Loop.default

local INADDR_ANY = 0

local inaddr = function(port,addr)
  local inaddr = S.t.sockaddr_in()
  inaddr.family = S.c.AF.INET
  inaddr.port = port
  if host then
    inaddr.addr = addr
  else
    inaddr.sin_addr = h.htonl(INADDR_ANY)
  end
  return inaddr
end

--- creates and binds a listening socket for
-- ipv4 and (if available) ipv6.
local sbind = function(host,port,backlog)
  local server = S.socket('inet','stream')
  server:nonblock(true)
  server:setsockopt('socket','reuseaddr',true)
  -- TODO respect host
  local hostAddr = dns.getaddrinfo(host)[1].addr --maybe nil
  server:bind(inaddr(port,hostAddr))
  server:listen(backlog or 511)
  return server
end

local new = function(options)
  local self = emitter.new()
  local conCount = 0
  local lsock
  local listenIo
  
  self.listen = function(_,port,host,backlog,callback)
    lsock = sbind(host or '*',port,backlog or 511)
    nextTick(function()
        self:emit('listening',self)
      end)
    if callback then
      self:once('listening',callback)
    end
    listenIo = ev.IO.new(
      function()
        local ss = S.types.t.sockaddr_storage()
        local sock,err = lsock:accept()
        if sock then
          local s = nsocket.new({
              fd = sock,
              allowHalfOpen = options.allowHalfOpen
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
          self:emit('error',err)
        end
      end,
      lsock:getfd(),
    ev.READ)
    listenIo:start(loop)
    
  end
  
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

local createServer = function(...)
  local args = {...}
  local options
  local connectionListener
  if type(args[1]) == 'table' then
    options = args[1]
  elseif type(args[1]) == 'function' then
    connectionListener = args[1]
  end
  if #args > 1 then
    connectionListener = args[2]
  end
  
  local server = new(options)
  server:on('connection',connectionListener)
  return server
end

return {
  createServer = createServer
}
