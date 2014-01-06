local tinsert = table.insert
local tremove = table.remove

local EventEmitter = function()
  local self = {}
  local listeners = {}
  local maxListeners = 10
  
  self.setMaxListeners = function(_,max)
    maxListeners = max
  end
  
  self.listeners = function(_,event)
    local l = {}
    for i,listener in ipairs(listeners[event] or {}) do
      l[i] = listener
    end
    return l
  end
  
  self.addListener = function(_,event,listener)
    listeners[event] = listeners[event] or {}
    if #listeners[event] > maxListeners and maxListeners ~= 0 then
      error('maxListeners limit reached for event '..event)
    end
    tinsert(listeners[event],listener)
    self:emit('newListener',event,listener)
    return self
  end
  
  self.on = self.addListener
  
  self.removeListener = function(_,event,oldlistener)
    if listeners[event] then
      for i,listener in ipairs(listeners[event]) do
        if listener == oldlistener then
          tremove(listeners[event],i)
          self:emit('removeListener',event,listener)
          return self
        end
      end
    end
    return self
  end
  
  local removeAllListenersForEvent = function(event)
    local listenersbak = listeners[event] or {}
    listeners[event] = nil
    for _,listener in ipairs(listenersbak) do
      self:emit('removeListener',event,listener)
    end
  end
  
  self.removeAllListeners = function(_,event)
    if event then
      removeAllListenersForEvent(event)
    else
      for event in pairs(listeners) do
        removeAllListenersForEvent(event)
      end
    end
    return self
  end
  
  self.once = function(_,event,listener)
    local remove
    remove = function()
      self:removeListener(event,remove)
      self:removeListener(event,listener)
    end
    self:addListener(event,listener)
    self:addListener(event,remove)
    return self
  end
  
  local emitListeners = {}
  
  self.emit = function(_,event,...)
    local listeners = listeners[event]
    if listeners then
      for i,listener in ipairs(listeners) do
        emitListeners[i] = listener
      end
      for i=1,#listeners do
        local ok,err = pcall(emitListeners[i],...)
        if not ok then
          self:emit('error',err)
          print('error in listener',err)
        end
      end
    end
    return self
  end
  
  return self
end

return {
  EventEmitter = EventEmitter,
}
