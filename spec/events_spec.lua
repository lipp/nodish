describe('The events module',function()
    local events = require'nodish.events'
    it('provides EventEmitter method',function()
        assert.is_function(events.EventEmitter)
      end)
    
    it('esock.new returns an object/table',function()
        assert.is_table(events.EventEmitter())
      end)
    
    describe('with an emitter instance',function()
        local i
        before_each(function()
            i = events.EventEmitter()
          end)
        
        local expectedMethods = {
          'addListener',
          'on',
          'once',
          'removeListener',
          'emit',
        }
        
        for _,method in ipairs(expectedMethods) do
          it('i.'..method..' is function',function()
              assert.is_function(i[method])
            end)
        end
        
        it('i.addListener and i.on are the same method',function()
            assert.is_equal(i.addListener,i.on)
          end)
        
        it('i.on callback gets called with correct arguments',function(done)
            i:on('foo',async(function(a,b)
                  assert.is_equal(a,'test')
                  assert.is_equal(b,123)
                  done()
              end))
            i:emit('foo','test',123)
          end)
        
        it('i.on callback gets called once for each emit',function(done)
            local count = 0
            i:on('foo',async(function()
                  count = count + 1
                  if count == 2 then
                    done()
                  end
              end))
            i:emit('foo')
            i:emit('foo')
          end)
        
        it('once is really called once',function(done)
            local count = 0
            i:once('bar',async(function()
                  count = count + 1
              end))
            local b = 0
            i:on('bar',async(function()
                  b = b + 1
                  if b == 2 then
                    assert.is_equal(count,1)
                    done()
                  end
              end))
            i:emit('bar',1)
            i:emit('bar',2)
          end)
        
        it('once can be canceled',function(done)
            local entered
            local onceCb = async(function()
                entered = true
              end)
            i:once('bar',onceCb)
            i:on('bar',async(function()
                  assert.is_nil(entered)
                  done()
              end))
            i:removeListener('bar',onceCb)
            i:emit('bar')
          end)
        
        it('removeAllListeners works for a specific event',function(done)
            local entered = 0
            i:on('foo',async(function()
                  entered = entered + 1
              end))
            i:on('foo',async(function()
                  entered = entered + 1
              end))
            i:on('bar',async(function()
                  assert.is_equal(entered,0)
                  done()
              end))
            i:removeAllListeners('foo')
            i:emit('foo')
            i:emit('bar')
          end)
        
        it('removeAllListeners works for all events',function(done)
            local entered = 0
            i:on('foo',async(function()
                  entered = entered + 1
              end))
            i:on('foo',async(function()
                  entered = entered + 1
              end))
            i:on('bar',async(function()
                  entered = entered + 1
                  --                  done()
              end))
            i:removeAllListeners()
            i:emit('foo')
            i:emit('bar')
            assert.is_equal(entered,0)
            done()
          end)
        
      end)
  end)
