local ev = require'ev'
local S = require'syscall'
local loop = ev.Loop.default

local EAGAIN = S.c.E.AGAIN

local nexttick = require'nodish.nexttick'.nexttick

local readable = function(emitter)
  local self = emitter
  assert(self.watchers)
  self.add_read_watcher = function(_,fd)
    assert(self._read)
    if self.watchers.read then
      return
    end
    local watchers = self.watchers
    watchers.read = ev.IO.new(function(loop,io)
        self:emit('readable')
        repeat
          local data,err,closed = self:_read()
          if data then
            if #data > 0 then
              if watchers.timer then
                watchers.timer:again(loop)
              end
              self:emit('data',data)
            else
              self:emit('fin')
              if closed then
                self:emit('close')
              end
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
  
  local might_have_data
  
  self.resume = function()
    if not might_have_data then
      nexttick(function()
          if sock and watchers.read and not watchers.read:is_pending() then
            watchers.read:callback()(loop,watchers.read)
          end
        end)
      might_have_data = false
    end
    self.watchers.read:start(loop)
  end
  
  self.pipe = function(_,writable,auto_fin)
    self:on('data',function(data)
        writable:write(data)
      end)
    if auto_fin == nil or auto_fin == true then
      self:on('fin',function()
          writable:fin()
        end)
    end
  end
  
end

local writable = function(emitter)
  local self = emitter
  local pending
  local ended
  
  self.add_write_watcher = function(_,fd)
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
  
  self.write = function(_,data)
    if pending then
      pending = pending..data
    elseif ended then
      error('writable.fin has been called')
    else
      pending = data
      self.watchers.write:start(loop)
    end
  end
  
  self.fin = function(_,data)
    if data then
      self:write(data)
    elseif not pending then
      nexttick(function()
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
