local S = require'syscall'
local events = require'nodish.events'
local stream = require'nodish.stream'
local nextTick = require'nodish.nexttick'.nextTick
local util = require'nodish._util'
local ev = require'ev'
local ffi = require'ffi'
local dns = require'nodish.dns'
local buffer = require'nodish.buffer'

local loop = ev.Loop.default

-- TODO: employ ljsyscall
local isIP = function(ip)
  return dns.getaddrinfo(ip)
end

-- TODO: employ ljsyscall
local isIPv6 = function(ip)
  local addrinfo,err = luasocket.dns.getaddrinfo(ip)
  if addrinfo then
    assert(#addrinfo > 0)
    if addrinfo[1].family == 'IPv6' then
      return true
    end
  end
  return false
end

-- TODO: employ ljsyscall
local isIPv4 = function(ip)
  return isIP(ip) and not isIPv6(ip)
end

local new = function(options)
  options = options or {}
  local readable = options.readable or true
  local writable = options.writable or true
  local allowHalfOpen = options.allowHalfOpen or false
  local sock = options.fd or nil
  local self = events.EventEmitter()
  local watchers = {}
  self.watchers = watchers
  
  if readable then
    stream.readable(self)
  end
  
  if writable then
    stream.writable(self)
  end
  
  local connecting = false
  local connected = false
  local closing = false
  
  self:once('error',function(err)
      local hadError = err and true
      self:destroy(hadError)
    end)
  
  if readable then
    self:once('fin',function()
        if not allowHalfOpen then
          -- socket.fin has not been called yet
          if writable then
            self:once('finish',function()
                self:destroy()
              end)
            
            self:fin()
          else
            self:destroy()
          end
        end
      end)
  end
  
  -- TODO: use metatable __index access for lazy loading
  local addAddressesToSelf = function()
    local remoteAddr = sock:getpeername()
    
    self.remoteAddress = tostring(remoteAddr.addr)
    self.remotePort = remoteAddr.port
    
    local localAddr = sock:getsockname()
    self.localAddress = tostring(localAddr.addr)
    self.localPort = localAddr.port
  end
  
  local onConnect = function()
    connecting = false
    connected = true
    
    addAddressesToSelf()
    if readable then
      local chunkSize = 4096*20 -- about 100k
      local buf
      -- provide read mehod for stream
      self._read = function()
        if not sock then
          return '',nil,true
        end
        if not buf or not buf:isReleased() then
          buf = buffer.Buffer(chunkSize)
        end
        local ret,err = sock:read(buf.buf,chunkSize)
        local data
        if ret then
          data = buf:toString('utf8',0,ret)
        end
        return data,err
      end
      self:addReadWatcher(sock:getfd())
      self:resume()
    end
    
    if writable then
      -- provide write method for stream
      self._write = function(_,data)
        return sock:write(data)
      end
      self:addWriteWatcher(sock:getfd())
    end
    self:emit('connect',self)
  end
  
  if sock then
    sock:nonblock(true)
    onConnect()
  end
  
  self.connect = function(_,port,ip)
    ip = ip or '127.0.0.1'
    if not isIP(ip) then
      onError(err)
    end
    if sock and closing then
      self:once('close',function(self)
          self:_connect(port,ip)
        end)
    elseif not connecting then
      self:_connect(port,ip)
    end
  end
  
  self._connect = function(_,port,ip)
    local addrinfo = dns.getaddrinfo(ip)[1]
    local addr
    if addrinfo.family == 'IPv6' then
      sock = S.socket('inet6','stream')
      addr = S.types.t.sockaddr_in6(port,addrinfo.addr)
    else
      sock = S.socket('inet','stream')
      addr = S.types.t.sockaddr_in(port,addrinfo.addr)
    end
    sock:nonblock(true)
    connecting = true
    closing = false
    local _,err = sock:connect(addr)
    if not err or err.errno == S.c.E.ISCONN then
      onConnect()
    elseif err.errno == S.c.E.INPROGRESS then
      watchers.connect = ev.IO.new(function(loop,io)
          io:stop(loop)
          local _,err = sock:connect(addr)
          if not err or err.errno == S.c.E.ISCONN then
            watchers.connect = nil
            onConnect()
          else
            self:emit('error',tostring(err))
          end
        end,sock:getfd(),ev.WRITE)
      watchers.connect:start(loop)
    else
      nextTick(function()
          self:emit('error',tostring(err))
        end)
    end
  end
  
  local writableWrite = self.write
  
  self.write = function(_,data)
    if not writable then
      error('socket is not writable')
    end
    if connecting then
      self:once('connect',function()
          writableWrite(_,data)
        end)
    else
      assert(connected)
      writableWrite(_,data)
    end
    return self
  end
  
  local writableFin = self.fin
  
  self.fin = function(_,data)
    if not writable then
      return
    end
    writable = false
    self:once('finish',function()
        if sock then
          sock:shutdown(S.c.SHUT.WR)
        end
      end)
    writableFin(_,data)
    return self
  end
  
  self.destroy = function(_,hadError)
    writable = false
    readable = false
    for _,watcher in pairs(watchers) do
      watcher:stop(loop)
    end
    if sock then
      sock:close()
      sock = nil
      self:emit('close',hadError)
    end
  end
  
  local family = {
    [S.c.AF.INET] = 'IPv4',
    [S.c.AF.INET6] = 'IPv6',
  }
  
  self.address = function()
    if sock then
      local addr = sock:getsockname()
      local resObj = {
        address = tostring(addr.addr),
        port = addr.port,
        family = family[addr.family],
      }
      return resObj
    end
  end
  
  self.setTimeout = function(_,msecs,callback)
    if msecs > 0 and type(msecs) == 'number' then
      if watchers.timer then
        watchers.timer:stop(loop)
      end
      local secs = msecs / 1000
      watchers.timer = ev.Timer.new(function()
          self:emit('timeout')
        end,secs,secs)
      watchers.timer:start(loop)
      if callback then
        self:once('timeout',callback)
      end
    else
      watchers.timer:stop(loop)
      if callback then
        self:removeListener('timeout',callback)
      end
    end
  end
  
  self.setKeepAlive = function(_,enable)
    if sock then
      sock:setsockopt(S.c.SO.KEEPALIVE,enable)
    else
    end
  end
  
  self.setNoDelay = function(_,enable)
    if sock then
      sock:setoption('tcp-nodelay',enable)
    end
  end
  
  self.unref = function()
    for _,watcher in pairs(self.watchers) do
      util.unref(watcher)
    end
  end
  
  self.ref = function()
    for _,watcher in pairs(self.watchers) do
      util.ref(watcher)
    end
  end
  
  return self
end

local connect = function(...)
  local args = {...}
  local port
  local host
  local connectionListener
  if type(args[1]) == 'table' then
    local options = args[1]
    assert(options.port)
    port = options.port
    host = options.host
    connectionListener = args[2]
  else
    port = args[1]
    host = type(args[2]) == 'string' and args[2]
    connectionListener = (type(args[2]) == 'function' and args[2]) or (type(args[3]) == 'function' and args[3])
  end
  local sock = new()
  if connectionListener then
    sock:once('connect',connectionListener)
  end
  sock:connect(port,host)
  return sock
end

return {
  new = new,
  Socket = new,
  connect = connect,
  createConnection = connect,
  isIP = isIP,
  isIPv4 = isIPv4,
  isIPv6 = isIPv6,
}
