local ffi = require'ffi'
local S = require'syscall'


local types = {
  Double = {
    ctype = 'double',
    size = 8,
  },
  Float = {
    ctype = 'float',
    size = 4
  },
  UInt8 = {
    ctype = 'uint8_t',
    size = 1,
  },
  UInt16 = {
    ctype = 'uint16_t',
    size = 2,
  },
  UInt32 = {
    ctype = 'uint32_t',
    size = 4,
  },
  Int8 = {
    ctype = 'int8_t',
    size = 1,
  },
  Int16 = {
    ctype = 'int16_t',
    size = 2,
  },
  Int32 = {
    ctype = 'int32_t',
    size = 4,
  },
}

local tmpBuf = ffi.new('uint8_t[8]')

local methods = {}

for typeName,typeInfo in pairs(types) do
  local readName = 'read'..typeName
  local ctype = typeInfo.ctype..'*'
  local size = typeInfo.size
  methods[readName] = function(self,offset,noAssert)
    if not noAssert then
      if offset + size >= self.length then
        error('out of bounds')
      end
    end
    return ffi.cast(ctype,self.buf + offset)[0]
  end
  local swapRead = function(self,offset,noAssert)
    if not noAssert then
      if offset + size >= self.length then
        error('out of bounds')
      end
    end
    for i=0,size-1 do
      tmpBuf[i] = self.buf[size-i-1+offset]
    end
    return ffi.cast(ctype,tmpBuf)[0]
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
  methods[writeName] = function(self,val,offset,noAssert)
    if not noAssert then
      if offset + size >= self.length then
        error('out of bounds')
      end
    end
    store[0] = val
    ffi.copy(self.buf + offset,store,size)
  end
  local swapWrite = function(self,val,offset,noAssert)
    if not noAssert then
      if offset + size >= self.length then
        error('out of bounds')
      end
    end
    store[0] = val
    for i=0,size-1 do
      tmpBuf[i] = store[size-i-1]
    end
    ffi.copy(self.buf + offset,tmpBuf,size)
  end
  
  if ffi.abi('be') then
    methods[writeName..'BE'] = methods[writeName]
    methods[writeName..'LE'] = swapWrite
  else
    methods[writeName..'BE'] = swapWrite
    methods[writeName..'LE'] = methods[writeName]
  end
end

methods.write = function(self,string,offset,length,encoding)
  offset = offset or 0
  length = length or (self.length - offset)
  ffi.copy(self.buf + offset,string,math.min(length,#string))
end

methods.toString = function(self,encoding,offset,stop)
  offset = offset or 0
  stop = stop or self.length
  local len = stop - offset
  return ffi.string(self.buf + offset,len)
end

methods.fill = function(self,value,offset,stop)
  print(self.length)
  offset = offset or 0
  stop = stop or self.length
  local len = stop - offset
  ffi.fill(self.buf+offset,len,string.byte(value))
end

methods.release = function(self,release)
  self.released = release ~= nil and release or true
end

methods.isReleased = function(self)
  return self.released
end

methods._setLength = function(self,length)
  assert(length <= self.length)
  self.length = length
end

local mt = {
  __index = function(self,key)
    if rawget(self,'released') then
      error('buffer is released and cannot be accesed',2)
    end
    if type(key) == 'number' then
      return self.buf[key]
    else
      return methods[key]
    end
  end,
  __tostring = function(self)
    local hex = {}
    hex[1] = '<Buffer'
    for i=0,math.min(self.length-1,50) do
      hex[i+2] = string.format('%2x',self.buf[i])
    end
    hex[#hex+1] = '>'
    return table.concat(hex,' ')
  end,
  __newindex = function(self,key,value)
    if self.released then
      error('buffer is released and cannot be accesed',2)
    end
    self.buf[key] = value
  end
}

local Buffer = function(arg)
  local buf
  local size
  if type(arg) == 'number' then
    size = arg
    buf = ffi.new('uint8_t [?]',size)
  elseif type(arg) == 'string' then
    size = #arg
    buf = ffi.new('uint8_t [?]',#arg, arg)
  end
  local self = {}
  self.released = false
  self.buf = buf
  self.length = size
  self.dump = function(self)
    print(self)
  end
  setmetatable(self,mt)
  return self
end

local isBuffer = function(x)
  return getmetatable(x) == mt
end

return {
  Buffer = Buffer,
  isBuffer = isBuffer
}
