local S = require'syscall'
local ffi = require'ffi'

if ffi.os == 'OSX' then
  ffi.cdef[[
  struct addrinfo {
    int             ai_flags;
    int             ai_family;
    int             ai_socktype;
    int             ai_protocol;
    socklen_t          ai_addrlen;
    char            *ai_canonname;
    struct sockaddr  *ai_addr;
    struct addrinfo  *ai_next;
  };
  ]]
else
  ffi.cdef[[
  struct addrinfo {
    int             ai_flags;
    int             ai_family;
    int             ai_socktype;
    int             ai_protocol;
    socklen_t          ai_addrlen;
    struct sockaddr  *ai_addr;
    char            *ai_canonname;
    struct addrinfo  *ai_next;
  };
  ]]
end
ffi.cdef[[
int getaddrinfo(const char *hostname, const char *servname, const struct addrinfo *hints, struct addrinfo **res);
void
freeaddrinfo(struct addrinfo *ai);
]]

local getaddrinfo = function(host)
  local paddrinfo = ffi.new('struct addrinfo *[1]')
  local ret = ffi.C.getaddrinfo(host,service,nil,paddrinfo)
  if ret ~= 0 then
    return
  end
  ffi.gc(paddrinfo[0],ffi.C.freeaddrinfo)
  local info = paddrinfo[0]
  local addrinfos = {}
  while info ~= nil do
    local addr = {}
    local addr_in = nil
    if info.ai_family == S.c.AF.INET then
      addr_in = S.types.pt.sockaddr_in(info.ai_addr)
      addr.family = 'IPv4'
    else
      assert(info.ai_family == S.c.AF.INET6)
      addr.family = 'IPv6'
      addr_in = S.types.pt.sockaddr_in6(info.ai_addr)
    end
    addr.addr = tostring(addr_in.addr);
    table.insert(addrinfos,addr)
    info = info.ai_next
  end
  return addrinfos
end

return {
  getaddrinfo = getaddrinfo
}
