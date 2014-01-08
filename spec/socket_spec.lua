setloop('ev')

local ev = require'ev'

local cleanup = function()
  os.execute('killall nc 2>/dev/null')
  os.execute('rm infifo 2>/dev/null')
  os.execute('rm outfifo 2>/dev/null')
end

cleanup()

os.execute('mkfifo infifo')
os.execute('mkfifo outfifo')
os.execute('nc -6 -k -l 12345 < infifo > outfifo  &')

local infifo = io.open('infifo','w')
local outfifo = io.open('outfifo','r')

describe('The net.socket module',function()
    
    teardown(function()
        cleanup()
      end)
    
    local socket = require'nodish.net.socket'
    it('provides new method',function()
        assert.is_function(socket.new)
      end)
    
    it('socket.new returns an object/table',function()
        assert.is_table(socket.new())
      end)
    
    it('error and close events are emitted once',function(done)
        local s = socket.new()
        local dead_port = 16237
        s:connect(dead_port)
        local nerrors = 0
        local ncloses = 0
        s:on('error',async(function()
              nerrors = nerrors + 1
              s:destroy()
          end))
        
        s:on('close',async(function()
              ncloses = ncloses + 1
          end))
        ev.Timer.new(async(function()
              assert.is_equal(nerrors,1)
              assert.is_equal(ncloses,1)
              done()
          end),0.01):start(ev.Loop.default)
      end)
    
    describe('with an net.socket instance',function()
        local i
        before_each(function()
            i = socket.new()
          end)
        
        after_each(function(done)
            i:destroy()
            -- this is required since netcat (nc)
            -- seems to return "Connection refused" if tests are
            -- executed to fast
            ev.Timer.new(async(function()
                  done()
              end),0.01):start(ev.Loop.default)
          end)
        
        local expected_methods = {
          'connect',
          'write',
          'fin',
          'destroy',
          'pause',
          'resume',
          'setTimeout',
          'setNoDelay',
          'setKeepAlive',
          'on',
          'once',
          'addListener',
          'removeListener',
        }
        
        for _,method in ipairs(expected_methods) do
          it('i.'..method..' is function',function()
              assert.is_function(i[method])
            end)
        end
        
        it('can connect to www.google.com',function(done)
            i:on('connect',async(function(j)
                  assert.is_same(i,j)
                  done()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(80,'www.google.com')
          end)
        
        it('can connect to www.google.com and address is correct',function(done)
            i:on('connect',async(function(j)
                  local addr = i:address()
                  assert.is_number(addr.port)
                  assert.is_string(addr.address)
                  assert.is_true(addr.family == 'IPv4' or addr.family == 'IPv6')
                  done()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(80,'www.google.com')
          end)
        
        it('can write and drain event is emitted',function(done)
            i:on('drain',async(function()
                  local data = outfifo:read('*l')
                  assert.is_equal(data,'halloposl')
              end))
            i:on('connect',async(function()
                  i:write('hallo')
                  i:fin('posl\n')
              end))
            i:on('finish',async(function()
                  done()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(12345)
          end)
        
        it('can write and drain event is emitted with 100k bytes',function(done)
            local lines = 20
            local many_bytes = string.rep('hallo',1000)
            i:on('drain',async(function()
                  for x = 1,lines do
                    local data = outfifo:read('*l')
                    assert.is_equal(data,many_bytes)
                  end
                  assert.is_equal(i.bytesWritten,20*(#many_bytes+1))
                  done()
              end))
            i:on('connect',async(function()
                  for x = 1,lines do
                    i:write(many_bytes..'\n')
                  end
                  i:fin()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(12345)
          end)
        
        it('address() is correct',function(done)
            i:on('connect',async(function()
                  local addr = i:address()
                  assert.is_number(addr.port)
                  assert.is_string(addr.address)
                  assert.is_true(addr.family == 'IPv4' or addr.family == 'IPv6')
                  assert.is_number(i.remotePort)
                  assert.is_string(i.remoteAddress)
                  done()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(12345)
          end)
        
        it('data event is emitted with correct argument',function(done)
            local nc_data = 'hello world'
            i:on('data',async(function(data)
                  assert.is_same(data,nc_data)
                  assert.is_equal(i.bytesRead,#nc_data)
                  done()
              end))
            i:on('connect',async(function()
                  infifo:write(nc_data)
                  infifo:flush()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(12345)
            i:setEncoding('utf8')
          end)
        
        it('support ipv6',function(done)
            i:on('connect',async(function()
                  done()
              end))
            i:on('error',async(function(err)
                  assert.is_nil(err)
              end))
            i:connect(12345,'::1')
          end)
        
      end)
  end)
