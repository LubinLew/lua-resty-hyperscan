# vim:set ft= ts=4 sw=4 et fdm=marker:

use Test::Nginx::Socket::Lua;

#no_shuffle();

repeat_each(2);

plan tests => blocks() * repeat_each() * 2;

run_tests();

__DATA__

=== TEST 1: normal mode test
Normal Mode Test

--- http_config
init_by_lua_block {
    local whs, err = require('hyperscan')
    if not whs then
        ngx.log(ngx.ERR, "hyperscan init failed, ", err)
    end

    local handle = whs.block_new("test", false)

    local patterns = {
        {id = 1001, pattern = "\\d3",       flag = "iu"},
        {id = 1002, pattern = "\\s{3,5}",   flag = "u"},
        {id = 1003, pattern = "[a-d]{2,7}", flag = ""}
    }

    -- compile patterns to a database
    ret, err = handle:compile(patterns)
    if not ret then
        ngx.log(ngx.ERR, "hyperscan block compile failed, ", err)
        return
    end

    hs.set("test1_obj", obj)
}

--- config
location = /t {
    content_by_lua_block {
        local whs = require('hyperscan')
        local handle = whs.block_get("test")
        local ret, id = handle:scan("abcdefghisghk")
        if ret then
            return ngx.print("matchid:", id)
        else
            return ngx.print("not match")
        end
    }
}

--- request
GET /t
--- error_code chomp
200
--- response_body chomp
matchid:1003