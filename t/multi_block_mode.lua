local whs = require('resty.hyperscan')
describe("multi_block_mode", function()
    local hs = whs.block_new("")
    it("compile", function()
        ---@type Hyperscan.pattern[]
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

        local ok, err = hs:compile(patterns)
        assert.is_true(ok)
    end)

    it("scan", function()
        local ok, ids = hs:multi_scan(5, "01234567")
        assert.is_true(ok)
        assert.is.same(ids, { 3, 1 })
    end)


end)
