local ev = require'ev'
local S = require'syscall'
local loop = ev.Loop.default

local EAGAIN = S.c.E.AGAIN

local nextTick = require'nodish.nexttick'.nextTick

local readable = function(emitter)
  local self = emitter
  self.bytesRead = 0
  assert(self.watchers)
  self.addReadWatcher = function(_,fd)
    assert(self._read)
    if self.watchers.read then
      return
    end
    local watchers = self.watchers
    watchers.read = ev.IO.new(function(loop,io)
        self:emit('readable')
        repeat
          local data,err = self:_read()
          if data then
            if #data > 0 then
              self.bytesRead = self.bytesRead + #data
              if watchers.timer then
                watchers.timer:again(loop)
              end
              self:emit('data',data)
            else
              self:emit('fin')
              io:stop(loop)
              return
            end
          elseif err and err.errno ~= EAGAIN then
            self:emit('error',err)
            err = nil
          end
        until err
      end,fd,ev.READ)
  end
  
  self.pause = function()
    self.watchers.read:stop(loop)
  end
  
  local mightHaveData
  
  self.resume = function()
    if not mightHaveData then
      nextTick(function()
          if self.watchers.read and not self.watchers.read:is_pending() then
            self.watchers.read:callback()(loop,self.watchers.read)
          end
        end)
      mightHaveData = false
    end
    self.watchers.read:start(loop)
  end
  
  self.pipe = function(_,writable,autoFin)
    self:on('data',function(data)
        writable:write(data)
      end)
    if autoFin == nil or autoFin == true then
      self:on('fin',function()
          writable:fin()
        end)
    end
  end
  
end

local writable = function(emitter)
  local self = emitter
  self.bytesWritten = 0
  local pending
  local ended
  
  self.addWriteWatcher = function(_,fd)
    assert(self._write)
    if self.watchers.write then
      return
    end
    local pos = 1
    local left
    local watchers = self.watchers
    watchers.write = ev.IO.new(function(loop,io)
        local written,err = self:_write(pending:sub(pos))
        if written > 0 then
          self.bytesWritten = self.bytesWritten + written
          pos = pos + written
          if pos > #pending then
            pos = 1
            pending = nil
            io:stop(loop)
            self:emit('drain')
            if ended then
              self:emit('finish')
            end
          end
        elseif err and err.errno ~= EAGAIN then
          io:stop(loop)
          self:emit('error',err)
          return
        end
        if watchers.timer then
          watchers.timer:again(loop)
        end
      end,fd,ev.WRITE)
  end
  
  
  --may be overwritten by 'subclass/implementors'
  -- save for usage in fin
  local write = function(_,data)
    if pending then
      pending = pending..data
    elseif ended then
      error('writable.fin has been called')
    else
      pending = data
      self.watchers.write:start(loop)
    end
  end
  
  self.write = write
  
  self.fin = function(_,data)
    if data then
      write(self,data)
    elseif not pending then
      nextTick(function()
          self:emit('finish')
        end)
    end
    ended = true
  end
  
end

return {
  readable = readable,
  writable = writable
}
