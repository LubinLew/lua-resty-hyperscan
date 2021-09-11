## lua-resty-hyperscan

lua-resty-hyperscan - [Hyperscan](https://github.com/intel/hyperscan) for [Openresty](https://github.com/openresty/openresty)

!!! [Old Branch](https://github.com/LubinLew/lua-resty-hyperscan/tree/v0.1) got [too many callbacks](https://github.com/LubinLew/lua-resty-hyperscan/issues/1) problem, because luajit is not fully support [CALLBACK](https://luajit.org/ext_ffi_semantics.html#callback).

So we need a [C wrapper](hs_wrapper/) to handle callbacks.

## Table of Contents

<!-- TOC -->

- [lua-resty-hyperscan](#lua-resty-hyperscan)
- [Table of Contents](#table-of-contents)
- [Status](#status)
- [Synopsis](#synopsis)
- [Methods](#methods)
  - [block_new](#block_new)
  - [block_free](#block_free)
  - [handle:compile](#handlecompile)
    - [Pattern List](#pattern-list)
      - [Example](#example)
      - [Flags](#flags)
  - [handle:scan](#handlescan)
- [Copyright and License](#copyright-and-license)

<!-- /TOC -->

## Status

This library is under development so far.

**THIS LIBRARY ONLY SUPPORT [BLOCK SCAN](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_MODE_BLOCK) NOW !**

**THIS LIBRARY IS ONLY TESTED on CentOS 7 !**

----

## Synopsis

configuration example

```lua
user  nobody;
worker_processes  auto;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    init_by_lua_block {
       local whs, err = require('hyperscan')
        if not whs then
            ngx.log(ngx.ERR, "Failure:", err)
            return
        end

       -- new
       local obj = whs.block_new("a-uniq-name", true) -- true : enable debug mode

       local patterns = {
           {id = 1001, pattern = "\\d3",       flag = "iu"},
           {id = 1002, pattern = "\\s{3,5}",   flag = "u"},
           {id = 1003, pattern = "[a-d]{2,7}", flag = ""}
       }

        -- compile
        ret, err = obj:compile(patterns)
        if not ret then
           ngx.log(ngx.ERR, "hyperscan block compile failed, ", err)
           return
        end
    }

    server {
        listen       80;
        server_name  localhost;

        location / {
            content_by_lua_block {
                local whs = require('hyperscan')
                local obj = whs.block_get("a-uniq-name")
                -- scan
                local ret, id, from, to = obj:scan(ngx.var.uri)
                if ret then
                    return ngx.print("[", ngx.var.uri,"] match: ", id, " zone [", from, " - ", to, ").\n")
                else
                    return ngx.print("[", ngx.var.uri, "] not match any rule.\n")
                end
            }
        }
    }
}
```

test with uri

```bash
$ curl http://localhost
[/] not match any rule.

$ curl http://localhost/111111111
[/111111111] not match any rule.

$ curl http://localhost/aaaaaaa
[/aaaaaaa] match: 1003 zone [0 - 3).

$ curl "http://localhost/      end"
[/      end] match: 1002 zone [0 - 4).
```

[Back to TOC](#table-of-contents)

## Methods

way to load this library

```lua
local whs,err = require('hyperscan')
if not whs then
    ngx.log(ngx.ERR, "reason: ", err)
end
```

### block_new

Create a hyperscan instance for block mode

```lua
local handle, err = whs.block_new(name, debug)
if not handle then
    ngx.log(ngx.ERR, "reason: ", err)
end
```

| Field        | Name     | Lua Type | Description                   |
| ------------ | -------- | -------- | ----------------------------- |
| Parameter    | `name`   | string   | instance name, mainly for log |
|              | `debug`  | boolean  | enable/disable debug log      |
| Return Value | `handle` | cdata    | instance pointer              |
|              | `err`    | string   | reason of failure             |

[Back to TOC](#table-of-contents)

### block_free

Destroy a hyperscan instance for block mode

```lua
whs.block_free(name)
```

### handle:compile

```lua
--local handle = whs.block_new(name, debug)
local ok, err = handle:compile(patterns)
if not ok then
    ngx.log(ngx.ERR, "reason: ", err)
end
```

| Field        | Name       | Lua Type | Description       |
| ------------ | ---------- | -------- | ----------------- |
| parameter    | `patterns` | table    | pattern list)     |
| Return Value | `ok`       | boolean  | success/failure   |
|              | `err`      | string   | reason of failure |

#### Pattern List

##### Example

```lua
local patterns = {
    {id = 1001, pattern = "\\d3",       flag = "iu"   },
    {id = 1002, pattern = "\\s{3,5}",   flag = "dmsu" },
    {id = 1003, pattern = "[a-d]{2,7}", flag = ""     }
}
```

##### Flags

| Flag  | Hyperscan Value                                                                                              | Description                                             |
| ----- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------- |
| `'i'` | [HS_FLAG_CASELESS](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_CASELESS)         | Set case-insensitive matching                           |
| `'d'` | [HS_FLAG_DOTALL](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_DOTALL)             | Matching a `.` will not exclude newlines.               |
| `'m'` | [HS_FLAG_MULTILINE](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_MULTILINE)       | Set multi-line anchoring.                               |
| `'s'` | [HS_FLAG_SINGLEMATCH](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_SINGLEMATCH)   | Set single-match only mode.                             |
| `'e'` | [HS_FLAG_ALLOWEMPTY](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_ALLOWEMPTY)     | Allow expressions that can match against empty buffers. |
| `'u'` | [HS_FLAG_UTF8](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_UTF8)                 | Enable UTF-8 mode for this expression.                  |
| `'p'` | [HS_FLAG_UCP](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_UCP)                   | Enable Unicode property support for this expression.    |
| `'f'` | [HS_FLAG_PREFILTER](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_PREFILTER)       | Enable prefiltering mode for this expression.           |
| `'l'` | [HS_FLAG_SOM_LEFTMOST](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_SOM_LEFTMOST) | Enable leftmost start of match reporting.               |
| `'c'` | [HS_FLAG_COMBINATION](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_COMBINATION)   | Logical combination.                                    |
| `'q'` | [HS_FLAG_QUIET](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_FLAG_QUIET)               | Don't do any match reporting.                           |

### handle:scan

```lua
--local handle = whs.block_new(name, debug)
local ok, id, from, to = handle:scan(data)
if ok then
    ngx.log(ngx.INFO, "match success", id, from, to)
end
```

| Field        | Name   | Lua Type | Description                                  |
| ------------ | ------ | -------- | -------------------------------------------- |
| Parameter    | `data` | string   | string to be scanned                         |
| Return Value | `ok`   | boolean  | `ture` for match, `false` for not match      |
|              | `id`   | number   | match id                                     |
|              | `from` | number   | match from byte arrary index(include itself) |
|              | `to`   | number   | match end byte arrary index(exclude itself)  |

[I Back to TOC](#table-of-contents)

---

## Copyright and License

Author: Lubin <lgbxyz@gmail.com>.

This module is licensed under the MIT license.

**See Also**

* [Hyperscan Developer’s Reference Guide](http://intel.github.io/hyperscan/dev-reference/)
- [hyperscan packaging for CentOS7/8](https://github.com/OpenSecHub/hyperscan-packaging)
