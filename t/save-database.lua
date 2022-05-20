local whs = require('resty.hyperscan')
describe('save-database', function()
    local handle = whs.block_new("test", false)
    assert(handle)
    local scan = function()
        local ret, id = handle:scan("01234567")
        assert.is_true(ret)
        assert.not_nil(id)
        assert.is.same(id, 3)
    end
    describe('compile', function()
        local patterns = {
            {
                id = 1,
                flag = 'ids',
                pattern = "123456",
            },
            {
                id = 2,
                flag = 'ids',
                pattern = "hello",
            },
            {
                id = 3,
                flag = 'ids',
                pattern = "\\d{5}",
            }
        }
        local ret, err = handle:compile(patterns)
        assert.is_true(ret)

        it('scan', scan)
    end)
    local data
    it('serialize', function()
        data = whs.serialize_database(handle)
        assert.not_nil(data)
    end)

    describe('deserialize', function()
        handle = whs.deserialize_database('ww', 'block', data)
        assert.not_nil(handle)
        it('scan', scan)
    end)
end)
