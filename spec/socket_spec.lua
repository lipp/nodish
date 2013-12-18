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
os.execute('nc -k -l 12345 < infifo > outfifo  &')

local infifo = io.open('infifo','w')
local outfifo = io.open('outfifo','r')

describe('The net.socket module',function()
    
    teardown(function()
        cleanup()
      end)
    
    local socket = require'net.socket'
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
        
        after_each(function()
            i:destroy()
          end)
        
        local expected_methods = {
          'connect',
          'write',
          'fin',
          'destroy',
          'pause',
          'resume',
          'set_timeout',
          'set_nodelay',
          'set_keepalive',
          'on',
          'once',
          'add_listener',
          'remove_listener',
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
            i:connect(80,'www.google.com')
          end)
        
        it('can connect to www.google.com and address is correct',function(done)
            i:on('connect',async(function(j)
                  local addr = i:address()
                  assert.is_number(addr.port)
                  assert.is_string(addr.address)
                  assert.is_true(addr.family == 'ipv4' or addr.family == 'ipv6')
                  done()
              end))
            i:connect(80,'www.google.com')
          end)
        
        it('can write and drain event is emitted',function(done)
            i:on('drain',async(function()
                  local data = outfifo:read('*l')
                  assert.is_equal(data,'halloposl')
                  done()
              end))
            i:on('connect',async(function()
                  i:write('hallo')
                  i:fin('posl\n')
              end))
            i:connect(12345)
          end)
        
        it('can write and drain event is emitted with 500k bytes',function(done)
            settimeout(10)
            local lines = 100
            local many_bytes = string.rep('hallo',1000)
            i:on('drain',async(function()
                  for x = 1,lines do
                    local data = outfifo:read('*l')
                    assert.is_equal(data,many_bytes)
                  end
                  done()
              end))
            i:on('connect',async(function()
                  for x = 1,lines do
                    i:write(many_bytes..'\n')
                  end
                  i:fin()
              end))
            i:connect(12345)
          end)
        
        it('data event is emitted with correct argument',function(done)
            local nc_data = 'hello world'
            i:on('data',async(function(data)
                  assert.is_same(data,nc_data)
                  done()
              end))
            i:on('connect',async(function()
                  i:write('hallo')
                  i:fin('posl')
              end))
            i:connect(12345)
            infifo:write(nc_data)
            infifo:flush()
          end)
        
        
      end)
  end)
