use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = qq{
   	lua_package_path "./lib/?.lua;;";
	lua_package_cpath "./hs_wrapper/?.so;;";
};

repeat_each(2);

plan tests => blocks() * repeat_each() * 2;

run_tests();

__DATA__

=== TEST 1: normal mode test
Normal Mode Test

--- http_config eval: $::HttpConfig
--- config
location = /t {
    content_by_lua_block {
         local whs, err = require('resty.hyperscan')
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
