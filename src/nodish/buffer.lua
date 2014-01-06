local ffi = require'ffi'
local S = require'syscall'

ffi.cdef[[
void * memcpy(void *restrict dst, const void *restrict src, size_t n);
]]

local types = {
  Double = {
    ctype = 'double',
    size = 8,
  },
  Float = {
    ctype = 'float',
    size = 4
  },
  Int32 = {
    ctype = 'uint32_t',
    size = 4,
  }
}

local tmpBuf = ffi.new('uint8_t[8]')

local methods = {}

for typeName,typeInfo in pairs(types) do
  local readName = 'read'..typeName
  local ctype = typeInfo.ctype..'*'
  local size = typeInfo.size
  methods[readName] = function(self)
    local val = ffi.cast(ctype,self.pread)[0]
    self.pread = self.pread + size
    return val
  end
  local swapRead = function(self)
    local pread = self.pread
    for i=0,size-1 do
      tmpBuf[i] = pread[size-i-1]
    end
    local val = ffi.cast(ctype,tmpBuf)[0]
    self.pread = self.pread + size
    return val
  end
  
  if ffi.abi('be') then
    methods[readName..'BE'] = methods[readName]
    methods[readName..'LE'] = swapRead
  else
    methods[readName..'BE'] = swapRead
    methods[readName..'LE'] = methods[readName]
  end
end

for typeName,typeInfo in pairs(types) do
  local writeName = 'write'..typeName
  local size = typeInfo.size
  local store = ffi.new(typeInfo.ctype..'[1]')
  methods[writeName] = function(self,val)
    store[0] = val
    ffi.C.memcpy(self.pwrite,store,size)
    self.pwrite = self.pwrite + size
  end
  local swapWrite = function(self)
    store[0] = val
    for i=0,size-1 do
      tmpBuf[i] = store[size-i-1]
    end
    ffi.C.memcpy(self.pwrite,tmpBuf,size)
    self.pwrite = self.pwrite + size
    return val
  end
  
  if ffi.abi('be') then
    methods[writeName..'BE'] = methods[writeName]
    methods[writeName..'LE'] = swapWrite
  else
    methods[writeName..'BE'] = swapWrite
    methods[writeName..'LE'] = methods[writeName]
  end
end

local mt = {
  __index = function(self,key)
    if type(key) == 'number' then
      return self.buf[key]
    else
      return methods[key]
    end
  end,
  __newindex = function(self,key,value)
    self.buf[key] = value
  end
}

local Buffer = function(size)
  local buf = ffi.new('uint8_t [?]',size)
  local self = {}
  self.pwrite = buf + 0
  self.pread = buf + 0
  self.buf = buf
  self.dump = function()
    local hex = {}
    for i=0,size-1 do
      hex[i+1] = string.format('%2x',buf[i])
    end
    print(table.concat(hex,' '))
  end
  setmetatable(self,mt)
  return self
end

return {
  Buffer = Buffer
}
