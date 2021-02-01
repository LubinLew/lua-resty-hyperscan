Name
====

lua-resty-hyperscan - [Hyperscan](https://github.com/intel/hyperscan) for [Openresty](https://github.com/openresty/openresty)

Table of Contents
=================

- [Name](#name)
- [Table of Contents](#table-of-contents)
- [Status](#status)
- [Description](#description)
- [Synopsis](#synopsis)
- [Methods](#methods)
  - [init](#init)
  - [new](#new)
  - [instance:compile](#compile)
  - [instance:scan](#scan)
  - [instance:free](#free)
  - [clone](#clone)
  - [set](#set)
  - [get](#get)
- [Author](#author)
- [Copyright and License](#copyright-and-license)
- [See Also](#see-also)

Status
======

This library is under development so far.

Description
===========

**THIS LIBRARY ONLY SUPPORT [BLOCK SCAN](http://intel.github.io/hyperscan/dev-reference/api_files.html#c.HS_MODE_BLOCK) NOW !**

**THIS LIBRARY IS ONLY TESTED on CentOS 7 !**

# Dependency

You should build the hyperscan shared library. I got some pre-build blow:

- [CentOS 7](https://github.com/LubinLew/lua-resty-hyperscan/tree/master/hslibs/el7_x64)

- [CentOS 8](https://github.com/LubinLew/lua-resty-hyperscan/tree/master/hslibs/el8_x64)

- [MacOS](https://github.com/LubinLew/lua-resty-hyperscan/tree/master/hslibs/osx)

- [~~Windows 10~~](https://github.com/LubinLew/lua-resty-hyperscan/tree/master/hslibs/win10_x64)

Synopsis
========

## normal mode

```lua
init_by_lua_block {
    local hs = require('hyperscan')
    local ret, err = hs.init(hs.HS_WORK_NORMAL)
    if not ret then
        ngx.log(ngx.ERR, "hyperscan init failed, ", err)
    end

    local obj = hs.new(hs.HS_MODE_BLOCK)

    local patterns = {
        {id = 1001, pattern = "\\d3",       flag = "iu"},
        {id = 1002, pattern = "\\s{3,5}",   flag = "u"},
        {id = 1003, pattern = "[a-d]{2,7}", flag = ""}
    }

    -- compile patterns to a database
    ret, err = obj:compile(patterns)
    if not ret then
        ngx.log(ngx.ERR, "hyperscan block compile failed, ", err)
        return
    end

    hs.set("test1_obj", obj)
}


location = / {
    content_by_lua_block {
        local hs = require('hyperscan')
        local obj = hs.get("test1_obj")
        local ret, id = obj:scan("abcdefghisghk")
        if ret then
            return ngx.print("matchid:", id)
        else
            return ngx.print("not match")
        end
    }
}

```

## Runtime Mode

```lua
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

location = / {
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
```



[Back to TOC](#table-of-contents)

Methods
=======

way to load this library

```lua
local hs = require('hyperscan')
```

init
----

```lua
local ok, err = hs.init(mode)
```

Load Hyperscan shared library and check the CPU Instruction Set.

### Parameters

#### `mode`

- hs.`HS_WORK_NORMAL`    [Compiling Patterns](http://intel.github.io/hyperscan/dev-reference/compilation.html) and [Scanning for Patterns](http://intel.github.io/hyperscan/dev-reference/runtime.html)
- hs.`HS_WORK_RUNTIME`  [Serialization](http://intel.github.io/hyperscan/dev-reference/serialization.html) and [Scanning for Patterns](http://intel.github.io/hyperscan/dev-reference/runtime.html)

### Return Value

#### `ok`

boolean value. true for success, false for failure and check ther `err`.

#### `err`

string value to indicate error. 

[Back to TOC](#table-of-contents)

new
----------------

```lua
local instance, err = hs.new(scan_mode)
```

Create a Hyperscan Instance.

### Parameters

#### `scan_mode`

- hs.`HS_MODE_BLOCK`          Block mode: the target data is a discrete, contiguous block which can be scanned in one call and does not require state to be retained.

- hs.`HS_MODE_STREAM`        Streaming mode: the target data to be scanned is a continuous stream, not all of which is available at once; blocks of data are scanned in sequence and matches may span multiple blocks in a stream. In streaming mode, each stream requires a block of memory to store its state between scan calls.

- hs.`HS_MODE_VECTORED`    Vectored mode: the target data consists of a list of non-contiguous blocks that are available all at once. As for block mode, no retention of state is required.

> [Compiling Patterns &#8212; Hyperscan 5.3.0 documentation](http://intel.github.io/hyperscan/dev-reference/compilation.html#compilation)

### Return Value

#### `instance`

Hyperscan Instance.  nil for failure and check ther `err`.

#### `err`

string value to indicate error.

[Back to TOC](#table-of-contents)

compile
-------------

```lua
local ok, err = instance:compile(parameter)
```

make or load the pattern database.

### Parameters

#### `parameter`

| init mode            | scan mode             | parameter             |
| -------------------- | --------------------- | --------------------- |
| hs.`HS_WORK_NORMAL`  | hs.`HS_MODE_BLOCK`    | table(pattern list)   |
|                      | hs.`HS_MODE_STREAM`   | table(pattern list)   |
|                      | hs.`HS_MODE_VECTORED` | table(pattern list)   |
| hs.`HS_WORK_RUNTIME` | hs.`HS_MODE_BLOCK`    | string(database path) |
|                      | hs.`HS_MODE_STREAM`   | string(database path) |
|                      | hs.`HS_MODE_VECTORED` | string(database path) |

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

| Flag  | Hyperscan Value                                                                                              | Remark                                                  |
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

### Return Value

#### `ok`

boolean value. true for success, false for failure and check ther `err`.

#### `err`

boolean value.

[Back to TOC](#table-of-contents)



## scan

```lua
local ok, ret = instance:scan(data)
```

scan data.

### Parameters

#### `mode`

- hs.`HS_WORK_NORMAL` [Compiling Patterns](http://intel.github.io/hyperscan/dev-reference/compilation.html) and [Scanning for Patterns](http://intel.github.io/hyperscan/dev-reference/runtime.html)
- hs.`HS_WORK_RUNTIME` [Serialization](http://intel.github.io/hyperscan/dev-reference/serialization.html) and [Scanning for Patterns](http://intel.github.io/hyperscan/dev-reference/runtime.html)

### Return Value

#### `ok`

boolean value. true for match success and `ret`  is the pattern id, false for not match.

#### `ret`

pattern id.



## free

```lua
local ok, err = instance:free()
```

destroy the instance.

### Return Value

#### `ok`

boolean value. true for success, false for failure and check ther `err`.

#### `err`

string value to indicate error.



## set

```lua
local ok, err = hs.set(instance)
```

store instance.

### Return Value

#### `ok`

boolean value. true for success, false for failure and check ther `err`.

#### `err`

string value to indicate error.



## get

```lua
local instance = hs.get()
```

get instance.

### Return Value

#### `instance`

nil for failure.



## clone

```lua
local new_instance = hs.clone(old_instance)
```

clone a instance, this is for muti-threads. then 2 threads can scan the same database at  the same time.

### Return Value

#### `new_instance`

clone one



[Back to TOC](#table-of-contents)

Author
======

Lubin <lgbxyz@gmail.com>.

Copyright and License
=====================

This module is licensed under the MIT license.

See Also
========

* Hyperscan Developer’s Reference Guide: http://intel.github.io/hyperscan/dev-reference/

[Back to TOC](#table-of-contents)
