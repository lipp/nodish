local S = require'syscall'
local emitter = require'nodish.emitter'
local stream = require'nodish.stream'
local nextTick = require'nodish.nexttick'.nextTick
local ev = require'ev'

local loop = ev.Loop.default

-- TODO: employ ljsyscall
local isip = function(ip)
  local addrinfo,err = socket.dns.getaddrinfo(ip)
  if err then
    return false
  end
  return true
end

-- TODO: employ ljsyscall
local isipv6 = function(ip)
  local addrinfo,err = socket.dns.getaddrinfo(ip)
  if addrinfo then
    assert(#addrinfo > 0)
    if addrinfo[1].family == 'inet6' then
      return true
    end
  end
  return false
end

-- TODO: employ ljsyscall
local isipv4 = function(ip)
  return isip(ip) and not isipv6(ip)
end

local new = function()
  local self = emitter.new()
  local watchers = {}
  self.watchers = watchers
  stream.readable(self)
  stream.writable(self)
  local sock = S.socket('inet','stream')
  local connecting = false
  local connected = false
  local closing = false
  
  self:once('error',function()
      self:destroy()
      self:emit('close')
    end)
  
  local onConnect = function()
    connecting = false
    connected = true
    -- provide read mehod for stream
    self._read = function()
      if not sock then
        return '',nil,true
      end
      local data,err = sock:read()
      local closed
      if data and #data == 0 then
        closed = true
      end
      return data,err,closed
    end
    self:addReadWatcher(sock:getfd())
    -- provide write method for stream
    self._write = function(_,data)
      return sock:write(data)
    end
    self:addWriteWatcher(sock:getfd())
    self:resume()
    self:emit('connect',self)
  end
  
  self.connect = function(_,port,ip)
    ip = ip or '127.0.0.1'
    --    if not isip(ip) then
    --      onError(err)
    --    end
    if sock and closing then
      self:once('close',function(self)
          self:_connect(port,ip)
        end)
    elseif not connecting then
      self:_connect(port,ip)
    end
  end
  
  self._connect = function(_,port,ip)
    --    if isipv6(ip) then
    --      sock = S.socket.tcp6()
    --    else
    --      sock = socket.tcp()
    --    end
    local addr = S.types.t.sockaddr_in(port,ip)
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
  
  self._transfer = function(_,s)
    sock = s
    sock:nonblock(true)
    onConnect()
  end
  
  local writableWrite = self.write
  
  self.write = function(_,data)
    if connecting then
      self:once('connect',function()
          writableWrite(_,data)
        end)
    elseif connected then
      writableWrite(_,data)
    else
      self:emit('error','wrong state')
    end
    return self
  end
  
  local writableFin = self.fin
  
  self.fin = function(_,data)
    self:once('finish',function()
        if sock then
          sock:shutdown(S.c.SHUT.RD)
        end
      end)
    writableFin(_,data)
    return self
  end
  
  self.destroy = function()
    for _,watcher in pairs(watchers) do
      watcher:stop(loop)
    end
    if sock then
      sock:close()
      sock = nil
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
        address = tostring(addr.sin_addr),
        port = addr.sin_port,
        family = family[addr.sin_family],
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
  
  local daemonizeWatchers = function(daemonize)
    for _,watcher in pairs(self.watchers) do
      -- keep pending info, since watcher:stop also
      -- would call watcher:clear_pending internally
      -- with no chance of recovery
      local revents = watcher:clear_pending()
      watcher:stop(loop)
      watcher:start(loop,daemonize)
      if revents ~= 0 then
        watcher:callback()(loop,watcher,revents)
      end
    end
  end
  
  self.unref = function()
    daemonizeWatchers(true)
  end
  
  self.ref = function()
    daemonizeWatchers(false)
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
  connect = connect,
  createConnection = connect,
}
