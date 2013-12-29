local S = require'syscall'
local emitter = require'nodish.emitter'
local stream = require'nodish.stream'
local nexttick = require'nodish.nexttick'.nexttick
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
  local sock
  local connecting = false
  local connected = false
  local closing = false
  
  self:once('error',function()
      self:destroy()
      self:emit('close')
    end)
  
  local on_connect = function()
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
    self:add_read_watcher(sock:getfd())
    -- provide write method for stream
    self._write = function(_,data)
      return sock:write(data)
    end
    self:add_write_watcher(sock:getfd())
    self:resume()
    self:emit('connect',self)
  end
  
  self.connect = function(_,port,ip)
    ip = ip or '127.0.0.1'
    --    if not isip(ip) then
    --      on_error(err)
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
    sock = S.socket('inet','stream')
    sock:nonblock(true)
    connecting = true
    closing = false
    local _,err = sock:connect(addr)
    if not err or err.errno == S.c.E.ISCONN then
      on_connect()
    elseif err.errno == S.c.E.INPROGRESS then
      watchers.connect = ev.IO.new(function(loop,io)
          io:stop(loop)
          local _,err = sock:connect(addr)
          if not err or err.errno == S.c.E.ISCONN then
            watchers.connect = nil
            on_connect()
          else
            self:emit('error',tostring(err))
          end
        end,sock:getfd(),ev.WRITE)
      watchers.connect:start(loop)
    else
      nexttick(function()
          self:emit('error',tostring(err))
        end)
    end
  end
  
  self._transfer = function(_,s)
    sock = s
    sock:nonblock(true)
    on_connect()
  end
  
  local writable_write = self.write
  
  self.write = function(_,data)
    if connecting then
      self:once('connect',function()
          writable_write(_,data)
        end)
    elseif connected then
      writable_write(_,data)
    else
      self:emit('error','wrong state')
    end
    return self
  end
  
  local writable_fin = self.fin
  
  self.fin = function(_,data)
    self:once('finish',function()
        if sock then
          sock:shutdown(S.c.SHUT.RD)
        end
      end)
    writable_fin(_,data)
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
  
  
  self.address = function()
    if sock then
      local res = {sock:getsockname()}
      if #res == 3 then
        local res_obj = {
          address = res[1],
          port = tonumber(res[2]),
          family = res[3] == 'inet' and 'ipv4' or 'ipv6',
        }
        return res_obj
      end
      return
    end
  end
  
  self.set_timeout = function(_,msecs,callback)
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
        self:remove_listener('timeout',callback)
      end
    end
  end
  
  self.set_keepalive = function(_,enable)
    if sock then
      sock:setsockopt(S.c.SO.KEEPALIVE,enable)
    end
  end
  
  self.set_nodelay = function(_,enable)
    if sock then
      -- TODO: employ ljsiscall
      -- sock:setoption('tcp-nodelay',enable)
    end
  end
  
  return self
end

local connect = function(port,ip,cb)
  local sock = new()
  if type(ip) == 'function' then
    cb = ip
  end
  sock:once('connect',cb)
  sock:connect(port,ip)
  return sock
end

return {
  new = new,
  connect = connect,
  create_connection = connect,
}
