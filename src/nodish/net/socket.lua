local S = require'syscall'
local emitter = require'nodish.emitter'
local ev = require'ev'

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
  local sock
  local loop = ev.Loop.default
  local connecting = false
  local connected = false
  local closing = false
  local watchers = {}
  
  local on_error = function(err)
    if err ~= 'closed' then
      self:emit('error',err)
    end
    self:emit('close')
    self:destroy()
  end
  
  local EAGAIN = S.c.E.AGAIN
  
  local read_io = function()
    assert(sock)
    return ev.IO.new(function()
        repeat
          local data,err = sock:read()
          if data then
            if #data > 0 then
              if watchers.timer then
                watchers.timer:again(loop)
              end
              self:emit('data',data)
            else
              on_error('closed')
            end
          elseif err and err.errno ~= EAGAIN then
            on_error(tostring(err))
          end
        until not sock
      end,sock:getfd(),ev.READ)
  end
  
  local pending
  local pos
  
  local write_io = function()
    assert(sock)
    local pos = 1
    local left
    return ev.IO.new(function(loop,io)
        local sent,err = sock:write(pending:sub(pos))
        if err and err.errno ~= EAGAIN then
          io:stop(loop)
          on_error(tostring(err))
          return
        elseif sent == 0 then
          io:stop(loop)
          on_error('closed')
          return
        else
          pos = pos + sent
          if pos > #pending then
            pos = 1
            pending = nil
            io:stop(loop)
            self:emit('_drain')
            self:emit('drain')
          end
        end
        if watchers.timer then
          watchers.timer:again(loop)
        end
      end,sock:getfd(),ev.WRITE)
  end
  
  local on_connect = function()
    connecting = false
    connected = true
    watchers.read = read_io()
    watchers.write = write_io()
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
    assert(not sock)
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
    local ok,err = sock:connect(addr)
    if ok or err.errno == S.c.E.ALREADY then
      on_connect()
    elseif err.errno == S.c.E.INPROGRESS then
      watchers.connect = ev.IO.new(function(loop,io)
          local ok,err = sock:connect(addr)
          if ok or err.errno == S.c.E.ISCONN then
            io:stop(loop)
            watchers.connect = nil
            on_connect()
          else
            on_error(tostring(err))
          end
        end,sock:getfd(),ev.WRITE)
      watchers.connect:start(loop)
    else
      on_error(tostring(err))
    end
  end
  
  self._transfer = function(_,s)
    sock = s
    sock:nonblock(true)
    on_connect()
  end
  
  self.write = function(_,data)
    if pending then
      pending = pending..data
    else
      pending = data
      if connecting then
        self:once('connect',function()
            watchers.write:start(loop)
          end)
      elseif connected then
        watchers.write:start(loop)
      else
        self:emit('error','wrong state')
        self:emit('close')
        self:destroy()
      end
    end
    return self
  end
  
  self.fin = function(_,data)
    if pending or data then
      if data then
        self:write(data)
      end
      self:once('_drain',function()
          sock:shutdown(S.c.SHUT.RD)
        end)
    else
      sock:shutdown(S.c.SHUT.RD)
    end
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
  
  self.pause = function()
    watchers.read:stop(loop)
  end
  
  self.resume = function()
    watchers.read:start(loop)
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
