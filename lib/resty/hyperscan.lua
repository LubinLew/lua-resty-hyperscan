-- Copyright (C) LubinLew

local bit = require("bit")

local ffi = require('ffi')
local ffi_new = ffi.new
local ffi_cast = ffi.cast

local nkeys = require('table.nkeys')

local string_gmatch = string.gmatch
local string_match = string.match

local _M = {
    _VERSION = '0.2.0',
    _HS_VER  = '5.4.0', -- Hyperscan v5.3.0, version number is used to indicate the libray name

    -- work mode
    HS_WORK_NORMAL       = 1, -- both Compilation and Scanning, use libhs.so
    HS_WORK_RUNTIME      = 2, --[[only Scanning, use libhs_runtime.so,
        see http://intel.github.io/hyperscan/dev-reference/serialization.html --]]

    -- scan mode flag
    HS_MODE_BLOCK        =  1,
    HS_MODE_STREAM       =  2,
    HS_MODE_VECTORED     =  4
}

local mt = { __index = _M }


ffi.cdef[[
enum {
    HS_SUCCESS             = 0,
    HS_INVALID             = (-1),
    HS_NOMEM               = (-2),
    HS_SCAN_TERMINATED     = (-3),
    HS_COMPILER_ERROR      = (-4),
    HS_DB_VERSION_ERROR    = (-5),
    HS_DB_PLATFORM_ERROR   = (-6),
    HS_DB_MODE_ERROR       = (-7),
    HS_BAD_ALIGN           = (-8),
    HS_BAD_ALLOC           = (-9),
    HS_SCRATCH_IN_USE      = (-10),
    HS_ARCH_ERROR          = (-11),
    HS_INSUFFICIENT_SPACE  = (-12),
    HS_UNKNOWN_ERROR       = (-13)
};

typedef struct hs_database {
    char* dummy;
} hs_database_t;

typedef struct hs_scratch {
    char* dummy;
} hs_scratch_t;

typedef struct hs_platform_info {
    char* dummy;
} hs_platform_info_t;

typedef struct hs_stream {
    char* dummy;
} hs_stream_t;

/* not used */
typedef struct hs_expr_ext {
    unsigned long long flags;
    unsigned long long min_offset;
    unsigned long long max_offset;
    unsigned long long min_length;
    unsigned edit_distance;
    unsigned hamming_distance;
} hs_expr_ext_t;

typedef struct hs_compile_error {
    char* message;
    int   expression;
} hs_compile_error_t;

/* CallBack function */
typedef int (*match_event_handler)(
    unsigned int id,
    unsigned long long from,
    unsigned long long to,
    unsigned int flags,
    void *context);

/* customize, store match result */
typedef struct hs_match_result {
    unsigned int id;
    unsigned long long from;
    unsigned long long to;
    unsigned int flags;
} hs_match_result_t;
/*----------------------- Common Functions  ---------------------*/
int hs_valid_platform(void);
int hs_free_database(hs_database_t *db);
int hs_free_compile_error(hs_compile_error_t *error);
int hs_database_info(const hs_database_t *database, char **info);
int hs_alloc_scratch(const hs_database_t *db, hs_scratch_t **scratch);
int hs_clone_scratch(const hs_scratch_t *src, hs_scratch_t **dest);
int hs_free_scratch(hs_scratch_t *scratch);


/*----------------------- Compile Functions  --------------------*/
/* Compile Regular Expression */
int hs_compile_ext_multi(
    const char *const *expressions,
    const unsigned int *flags,
    const unsigned int *ids,
    const hs_expr_ext_t *const *ext,
    unsigned int elements,
    unsigned int mode,
    const hs_platform_info_t *platform,
    hs_database_t **db,
    hs_compile_error_t **error);

/* Compile Pure Literals */
int hs_compile_lit_multi(
    const char * const *expressions,
    const unsigned *flags,
    const unsigned *ids,
    const size_t *lens,
    unsigned elements,
    unsigned mode,
    const hs_platform_info_t *platform,
    hs_database_t **db,
    hs_compile_error_t **error);

/*------------------------ Scan Functions  ---------------------*/
/* Block Scan */
int hs_scan(
    const hs_database_t *db,
    const char *data,
    unsigned int length,
    unsigned int flags,
    hs_scratch_t *scratch,
    match_event_handler onEvent,
    void *context);

/* Vectord Scan */
int hs_scan_vector(
    const hs_database_t *db,
    const char *const *data,
    const unsigned int *length,
    unsigned int count,
    unsigned int flags,
    hs_scratch_t *scratch,
    match_event_handler onEvent,
    void *context);

/* Stream Scan */
int hs_open_stream(const hs_database_t *db, unsigned int flags, hs_stream_t **stream);
int hs_scan_stream(hs_stream_t *id, const char *data, unsigned int length, unsigned int flags, hs_scratch_t *scratch, match_event_handler onEvent, void *ctxt);
int hs_close_stream(hs_stream_t *id, hs_scratch_t *scratch, match_event_handler onEvent, void *ctxt);
int hs_reset_stream(hs_stream_t *id, unsigned int flags, hs_scratch_t *scratch, match_event_handler onEvent, void *context);
int hs_copy_stream(hs_stream_t **to_id, const hs_stream_t *from_id);

/*--------------- Database Serialization ----------------*/
int hs_serialized_database_info(const char *bytes, size_t length, char **info);
int hs_deserialize_database(const char *bytes, const size_t length, hs_database_t **db);

]]

-----------------------------------------------------------------------------------------
----------------------------------- Core Code -------------------------------------------
-----------------------------------------------------------------------------------------
local hyperscan    = nil
local hs_work_mode = nil
local obj_store    = {}

--Compile flag
local compile_bit_flag = {
    ['i'] = 1,    --HS_FLAG_CASELESS         Set case-insensitive matching
    ['d'] = 2,    --HS_FLAG_DOTALL           Matching a `.` will not exclude newlines.
    ['m'] = 4,    --HS_FLAG_MULTILINE        Set multi-line anchoring.
    ['s'] = 8,    --HS_FLAG_SINGLEMATCH      Set single-match only mode.
    ['e'] = 16,   --HS_FLAG_ALLOWEMPTY       Allow expressions that can match against empty buffers.
    ['u'] = 32,   --HS_FLAG_UTF8             Enable UTF-8 mode for this expression.
    ['p'] = 64,   --HS_FLAG_UCP              Enable Unicode property support for this expression.
    ['f'] = 128,  --HS_FLAG_PREFILTER        Enable prefiltering mode for this expression.
    ['l'] = 256,  --HS_FLAG_SOM_LEFTMOST     Enable leftmost start of match reporting.
    ['c'] = 512,  --HS_FLAG_COMBINATION      Logical combination.
    ['q'] = 1024, --HS_FLAG_QUIET            Don't do any match reporting.
}

local function _translate_compile_flags(str)
    if type(str) ~= 'string' then
        return -1, "Invalid flags type: '" .. type(str) .. "', should be string."
    end

    local flags = 0
    local flag_bytes = {str:byte(1, #str)}
    for i = 1, #flag_bytes do
        local byte = string.char(flag_bytes[i])
        local flag = compile_bit_flag[byte]
        if not flag then
            return -1, "Invalid compile flag '" .. flag_bytes[i] .. "' !"
        else
            flags = bit.bor(flags, flag)
        end
    end

    return flags
end

--[[ get shared libray name based on platform
    - OSX       : libhs.5.3.0.dylib
    - Windows   : not sure
    -Unix Like : libhs.so.5.3.0
--]]
local function _get_so_name(base_name, version)
    if ffi.os == "OSX" then --libhs.5.3.0.dylib
        return "lib" .. base_name .. "." .. version .. ".dylib"
    end

    if ffi.os == "Windows" then -- this is just a guess
        return base_name .. "." .. version .. ".dll"
    end

    -- libhs.so.5.3.0
    return "lib" .. base_name .. ".so." .. version
end

-- find the shared library in cpath
local function _find_shared_obj(so_name)
    for k,_ in string_gmatch(package.cpath, "[^;]+") do
        local so_path = string_match(k, "(.*/)")
        if so_path then
            so_path = so_path .. so_name
            local f = io.open(so_path)
            if f ~= nil then
                io.close(f)
                return so_path
            end
        end
    end
end

-- load the serialized datebase for HS_WORK_MODE_RUNTIME
local function _load_serialize_database(self, path)
    if not path or type(path) ~= "string" then
        return false, "Please specify serialization datebase path !"
    end
    local file = io.open(path, "rb")
    if not file then
        return false, "Please specify serialization datebase path !"
    end

    -- get db content and size
    local db_data = file:read("a")
    local db_size = file:seek()
    file:close()

    -- check the db
    local info = ffi_new('char*[1]')
    local ret = hyperscan.hs_serialized_database_info(db_data, db_size, info)
    if ret ~= hyperscan.HS_SUCCESS then
        return false, "invalid serialized database !"
    end
    --[[ --TODO check the database Version and CPU Features
    --OUTPUT:Version: 5.3.0 Features: AVX2 Mode: BLOCK
    local result = ffi.string(info[0])
    ngx.log(ngx.ERR, "=== [Hyerscan serialize info] ", result)
    --]]

    -- deserialize database
    ret = hyperscan.hs_deserialize_database(db_data, db_size, self.hs_database)
    if ret ~= hyperscan.HS_SUCCESS then
        return false, "deserialize datebase failed, " .. ret
    end

    -- alloc scratch space
    ret = hyperscan.hs_alloc_scratch(self.hs_database[0], self.hs_scratch)
    if ret ~= hyperscan.HS_SUCCESS then
        hyperscan.hs_free_database(self.hs_database[0])
        return false, "alloc scratch failed, ret = " .. ret
    end

    return true
end

--[[ init
    - ffi.load the shared library
    - check CPU Instruction Set
--]]
function _M.init(mode)
    -- check hyperscan shared library
    local so_name
    if mode == _M.HS_WORK_RUNTIME then
        so_name = _get_so_name('hs_runtime', _M._HS_VER)
    else
        so_name = _get_so_name('hs', _M._HS_VER)
    end

    local so_path = _find_shared_obj(so_name)
    if so_path then
        hyperscan = ffi.load(so_path)

    else
        return false, so_name .. " shared library not found !"
    end

    hs_work_mode = mode
    ngx.log(ngx.ERR, "=== [Hyperscan load library]: ", so_path)

    -- check CPU Instruction Set
    local ret = hyperscan.hs_valid_platform()
    if ret ~= hyperscan.HS_SUCCESS then
        return false, "CPU Not Support SSSE3 Instruction !"
    end

    return true
end


local function _hs_compile_internal(self, patterns)
    local mode = self.scan_mode
    -- env Check
    if not hyperscan then
        return false, "should call init() first !"
    end
    if hs_work_mode ~= _M.HS_WORK_NORMAL then
        return false, "runtime work mode not support Compilation !"
    end

    -- Parameter Check
    if type(patterns) ~= "table" then
        return false, "#1 paramter should be a table !"
    end
    local count = nkeys(patterns)
    if count < 1 then
        return false, "No Patterns !"
    end

    local expressions = ffi_new('char*[?]', count)
    local ids         = ffi_new('unsigned int[?]', count)
    local flags       = ffi_new('unsigned int[?]', count)

    local index = 0
    for _,v in pairs(patterns) do
        ids[index]         = v.id
        flags[index]       = _translate_compile_flags(v.flag)
        expressions[index] = ffi_cast('char*', v.pattern)
        index = index + 1
    end

    local hs_err = ffi_new('hs_compile_error_t*[1]')

    local ret = hyperscan.hs_compile_ext_multi(
        ffi_cast('const char* const*', expressions),  -- const char *const *expressions,
        flags,            -- const unsigned int *flags,
        ids,              -- const unsigned int *ids,
        nil,              -- const hs_expr_ext_t *const *ext,
        count,            -- unsigned int elements,
        mode,             -- unsigned int mode,
        nil,              -- const hs_platform_info_t *platform,
        self.hs_database, --hs_database_t **db,
        hs_err            --hs_compile_error_t **error
    )

    if ret ~= hyperscan.HS_SUCCESS then
        local errlog = ffi.string(hs_err[0].message)
        hyperscan.hs_free_compile_error(hs_err[0])
        return false, errlog
    end

    local info = ffi_new('char*[1]')
    ret = hyperscan.hs_database_info(self.hs_database[0], info)
    if ret ~= hyperscan.HS_SUCCESS then
        return false, "hs_database_info failed, " .. ret
    end

    -- output the compiled database info, something like 'Version: 5.3.0 Features: AVX2 Mode: BLOCK'
    --ngx.log(ngx.ERR, "=== [Hyperscan datebase info]: ", ffi.string(info[0]))

    -- alloc scratch space
    ret = hyperscan.hs_alloc_scratch(self.hs_database[0], self.hs_scratch)
    if ret ~= hyperscan.HS_SUCCESS then
        hyperscan.hs_free_database(self.hs_database[0])
        return false, "alloc scratch failed, ret = " .. ret
    end

    return true
end


-- CallBack
-- Just Match Once
local function hs_match_event_handler(id, from, to, flags, context)
    local ctx = ffi.cast('hs_match_result_t*', context)
    ctx.id    = id
    ctx.from  = from
    ctx.to    = to
    ctx.flags = flags
    return 1 -- only match once
end


local function _hs_block_scan(self, string)
    local ret = hyperscan.hs_scan(
        self.hs_database[0],    -- const hs_database_t *,
        string,                 -- const char *data,
        string.len(string),     -- unsigned int length,
        0,                      -- unsigned int flags,
        self.hs_scratch[0],     -- hs_scratch_t *scratch,
        hs_match_event_handler, -- match_event_handler onEvent,
        self.hs_result          -- void *context
    )

    if ret == hyperscan.HS_SCAN_TERMINATED then
        return true, self.hs_result[0].id
    end

    return false
end


local function _hs_vector_scan(self, block_table)
    -- Parameter Check
    local count = nkeys(block_table)
    if count < 1 then
        return false, "No Data !"
    end

    local data   = ffi_new('char*[1]', count)
    local length = ffi_new('unsigned int[?]', count)
    local index = 0
    for _, v in pairs(block_table) do
        data[index] = v
        length[index] = string.len(v)
    end

    local ret = hyperscan.hs_scan_vector(
        self.hs_database[0],    -- const hs_database_t *,
        data,                   -- const char *const *data,
        length,                 -- const unsigned int *length,
        count,                  -- unsigned int count
        0,                      -- unsigned int flags,
        self.hs_scratch[0],     -- hs_scratch_t *scratch,
        hs_match_event_handler, -- match_event_handler onEvent,
        nil                     -- void *context
    )

    if ret == hyperscan.HS_SCAN_TERMINATED then
        return true, self.hs_result[0].id
    end

    return false
end



local function _hs_free_resources(self)
    if self.scan_mode ~= _M.HS_MODE_STREAM then
        hyperscan.hs_free_scratch(self.hs_scratch)
    end

    hyperscan.hs_free_database(self.hs_database)


end

--[[
-- return a stream id
function _M.hs_stream_scan_start()
    local hs_stream   = ffi_new('hs_stream_t*[1]')
end

function _M.hs_stream_scan_work(stream_id, data)
end

function _M.hs_stream_scan_end(stream_id)
end
--]]



function _M.new(scan_mode)
    local compile_func = nil
    if hs_work_mode == _M.HS_WORK_RUNTIME then
        compile_func = _load_serialize_database
    else
        compile_func = _hs_compile_internal
    end

    local scan_func = nil
    if scan_mode == _M.HS_MODE_BLOCK then
        scan_func = _hs_block_scan
    elseif scan_mode == _M.HS_MODE_VECTORED then
        scan_func = _hs_vector_scan
    elseif scan_mode == _M.HS_MODE_STREAM then
        scan_func = _hs_block_scan
    else
        return nil, "Error scan mode !"
    end

    return setmetatable({
            -- internal data
            scan_mode    = scan_mode,
            hs_database  = ffi_new('hs_database_t*[1]'),
            hs_scratch   = ffi_new('hs_scratch_t*[1]'),
            hs_result    = ffi_new('hs_match_result_t[1]'),
            -- public object method
            compile      = compile_func,
            scan         = scan_func,
            free         = _hs_free_resources
        }, mt)
end

-- thread safe for same database
function _M.clone(old)
    local new = old
    -- new buff to store match result
    new.hs_result = ffi_new('hs_match_result_t[1]')

    -- new scratch space
    new.hs_scratch = ffi_new('hs_scratch_t*[1]')
    local ret = hyperscan.hs_clone_scratch(old.hs_scratch[0], new.hs_scratch)
    if ret ~= hyperscan.HS_SUCCESS then -- insufficient memory or invalid parameters
        return nil
    end

    return new
end


function _M.set(name, object)
    if obj_store[name] then
        return false, name .. " already exist !"
    end

    obj_store[name] = object
    return true
end

function _M.get(name)
    return obj_store[name]
end

return _M
