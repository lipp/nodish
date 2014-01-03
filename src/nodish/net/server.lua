local nextTick = require'nodish.process'.nextTick
local S = require'syscall'
local h = require "syscall.helpers"
local emitter = require'nodish.emitter'
local ev = require'ev'
local nsocket = require'nodish.net.socket'
local util = require'nodish._util'
local dns = require'nodish.dns'
local ffi = require'ffi'

local loop = ev.Loop.default

local INADDR_ANY = 0x0

local inaddr = function(port,addr)
  local inaddr = S.t.sockaddr_in()
  inaddr.family = S.c.AF.INET
  inaddr.port = port
  if host then
    inaddr.addr = addr
  else
    inaddr.sin_addr.s_addr = INADDR_ANY--h.htonl(INADDR_ANY)
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
  local hostAddr
  if host then
    hostAddr = dns.getaddrinfo(host)[1].addr --maybe nil
  end
  server:bind(inaddr(port,hostAddr))
  server:listen(backlog or 511)
  return server
end

local new = function(options)
  local allowHalfOpen = options and options.allowHalfOpen
  local self = emitter.new()
  local conCount = 0
  local lsock
  local listenIo
  local closing
  
  self:once('error',function(err)
      if lsock then
        lsock:close()
      end
      self:emit('close',err)
    end)
  
  self.listen = function(_,port,host,backlog,callback)
    assert(_ == self)
    lsock = sbind(host,port,backlog)
    nextTick(function()
        self:emit('listening',self)
      end)
    if callback then
      self:once('listening',callback)
    end
    listenIo = ev.IO.new(
      function()
        local sock,err = lsock:accept()
        if sock then
          local s = nsocket.new({
              fd = sock,
              allowHalfOpen = allowHalfOpen
          })
          conCount = conCount + 1
          assert(conCount > 0)
          s:once('close',function()
              assert(conCount > 0)
              conCount = conCount - 1
              if closing and conCount == 0 then
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
    closing = true
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
