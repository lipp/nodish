setloop('ev')

describe('The net.socket module',function()
    local socket = require'net.socket'
    it('provides new method',function()
        assert.is_function(socket.new)
      end)
    
    it('socket.new returns an object/table',function()
        assert.is_table(socket.new())
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
        
        it('can write and drain event is emitted',function(done)
            i:on('drain',async(function()
                  done()
              end))
            i:on('connect',async(function()
                  i:write('hallo')
                  i:fin('posl')
              end))
            i:connect(12345)
            
          end)
      end)
  end)
