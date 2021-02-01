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
    local hs = require('hyperscan')
    local ret, err = hs.init(hs.HS_WORK_RUNTIME)
    if not ret then
        ngx.log(ngx.ERR, "hyperscan init failed, ", err)
    end

    local obj = hs.new(hs.HS_MODE_BLOCK)


    -- load database
    ret, err = obj:compile("test/make_serialize_database/serialized.db")
    if not ret then
        ngx.log(ngx.ERR, "hyperscan load database failed, ", err)
        return
    end

    hs.set("test2_obj", obj)
}

--- config
location = /t {
    content_by_lua_block {
        local hs = require('hyperscan')
        local obj = hs.get("test2_obj")
        local ret, id = obj:scan("abcdefg11111111hisghk")
        if ret then
            return ngx.print("matchid:", id)
        else
            ngx.print("not match")
        end
    }
}

--- request
GET /t
--- error_code chomp
200
--- response_body chomp
matchid:1003