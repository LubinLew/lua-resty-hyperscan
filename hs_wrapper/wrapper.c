/* Copyright (C) LubinLew */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <errno.h>

#include <hs.h>
#include "wrapper.h"

#ifndef __NO_SYSLOG
#include <syslog.h>
#endif /* __NO_SYSLOG */
/* ------------------------------------------------------------------------------------------ */

#ifdef __GNUC__
#define likely(x)   __builtin_expect(!!(x), 1)
#else  /* __GNUC__ */
#define likely(x)   (x)
#endif /* __GNUC__ */

#ifndef __NO_SYSLOG
#define Error(fmt, ...) syslog(LOG_INFO, "[%s][%s:%d]"fmt, handle->name, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define Debug(fmt, ...) if (handle->debug) syslog(LOG_INFO, "[%s][%s:%d]"fmt, handle->name, __FUNCTION__, __LINE__,##__VA_ARGS__)
#else  /* __NO_SYSLOG */
#define Error(fmt, ...) printf("[%s][%s:%d]"fmt"\n", handle->name, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#define Debug(fmt, ...) if (handle->debug) printf("[%s][%s:%d]"fmt"\n", handle->name, __FUNCTION__, __LINE__,##__VA_ARGS__)
#endif /* __NO_SYSLOG */

#define MAX_NAME_LEN (128)
/* ------------------------------------------------------------------------------------------ */

/* handler */
struct _whs_hdl {
    hs_database_t *db;
    hs_scratch_t  *scratch;
    int            debug;
    char           name[MAX_NAME_LEN + 1];
};

typedef struct _whs_match {
    unsigned int id;
    unsigned long long from;
    unsigned long long to;
    unsigned int flags;
} whs_match_t;

/* ------------------------------------------------------------------------------------------ */

/** the match event callback function 
 * Return: 
 *    Non-zero: the matching should cease
      zero   : the matching should go on
*/
static int
eventHandler(unsigned int id,
                 unsigned long long from,
                 unsigned long long to,
                 unsigned int flags,
                 void *ctx) 
{
    whs_match_t *match = (whs_match_t *)ctx;
    if (likely(ctx)) {
        match->id    = id;
        match->from  = from;
        match->to    = to;
        match->flags = flags;
    }

    return HS_SCAN_TERMINATED;
}


int
whs_init(void)
{
    hs_error_t ret;

#ifndef __NO_SYSLOG
        openlog("[libwhs]", LOG_CONS|LOG_PID, LOG_USER);
#endif /* __NO_SYSLOG */

    /* veritfy arch */
    ret = hs_valid_platform();
    if (ret != HS_SUCCESS) {
#ifndef __NO_SYSLOG
        syslog(LOG_INFO, "This system does not support Hyperscan");
        closelog();
#endif /* __NO_SYSLOG */
        return -1;
    }
    
#ifndef __NO_SYSLOG
     syslog(LOG_INFO, "whs_init() success");
#endif /* __NO_SYSLOG */

    return 0;
}


int
whs_compile(whs_hdl_t* handle,
                        const char *const *expressions,
                        const unsigned int *flags,
                        const unsigned int *ids,
                        unsigned int count,
                        unsigned int mode)
{
    int loop;
    hs_error_t ret;
    hs_compile_error_t* compile_err;

    if (!expressions || !ids) {
        Error("Invalid Paramters");
        return -1;
    }

    Debug("expressions count is %u", count);
    for (loop = 0; loop < count; loop++) {
        unsigned int flag = flags?flags[loop]:0;
        Debug("[%u][%u]-[%s]", ids[loop], flag, expressions[loop]);
    }

    ret = hs_compile_ext_multi(expressions, flags, ids, NULL, count,
                        mode, NULL, &handle->db, &compile_err);
    if (ret) {
        Error("hs_compile_ext_multi() failed: %s", compile_err->message);
        hs_free_compile_error(compile_err);
        return -1;
    }

    ret = hs_alloc_scratch(handle->db, &handle->scratch);
    if (ret != HS_SUCCESS) {
        Error("hs_alloc_scratch: %d", ret);
        hs_free_database(handle->db);
        handle->db = NULL;
        return -1;
    }

    return 0;
}


whs_hdl_t*
whs_block_create(const char *name, int debug)
{
    whs_hdl_t *handle = NULL;

    handle = (whs_hdl_t*)calloc(sizeof(whs_hdl_t), 1);
    if (NULL == handle) {
        Error("Insufficient Memory");
        return NULL;
    }

    handle->debug = debug;
    strncpy(handle->name, name, MAX_NAME_LEN);
    Debug("create handle %p", handle);
    return handle;
}

int
whs_block_compile(whs_hdl_t* handle,
                        const char *const *expressions,
                        const unsigned int *flags,
                        const unsigned int *ids,
                        unsigned int count)
{
    return whs_compile(handle, expressions, flags, ids, count, HS_MODE_BLOCK);
}

int
whs_block_scan(whs_hdl_t* handle,
                       const char *data, 
                       unsigned int len,
                       unsigned int *id,
                       unsigned long long *from,
                       unsigned long long *to)
{
    hs_error_t  ret;
    whs_match_t match;

    if (!len) {
        len = strlen(data);
    }

    ret = hs_scan(handle->db, data, len, 0, handle->scratch, eventHandler, &match);
    if (likely(HS_SUCCESS == ret)) {
        return 0;
    }
 
    if (likely(HS_SCAN_TERMINATED == ret)) {
        if (likely(id)) {
            *id = match.id;
        }
        if (likely(from)) {
            *from = match.from;
        }
        if (likely(to)) {
            *to = match.to;
        }

        Debug("MATCH id:%u, from:%llu, to:%llu, flags:%u", match.id, match.from, match.to, match.flags);
        return 1;
    }

    
    Error("hs_scan() return %d", ret);
    return -1;
}


void
whs_block_free(whs_hdl_t* handle)
{
    hs_error_t  ret;

    if (NULL == handle) {
        Error("handle is null");
        return;
    }

    if (handle->scratch) {
        ret = hs_free_scratch(handle->scratch);
        if (ret != HS_SUCCESS) {
            Error("hs_free_scratch() return %d", ret);
        }
    }


    if (handle->db) {
        ret = hs_free_database(handle->db);
        if (ret != HS_SUCCESS) {
            Error("hs_free_database() return %d", ret);
        }
    }

    Debug("free handle %p", handle);
    free(handle);
}

whs_hdl_t*
whs_vector_create(const char* name,
                    int debug) {
  return whs_block_create(name, debug);
}

int
whs_vector_compile(whs_hdl_t* handle,
                    const char* const* expressions,
                    const unsigned int* flags,
                    const unsigned int* ids,
                    unsigned int count) {
  return whs_compile(handle, expressions, flags, ids, count, HS_MODE_VECTORED);
}

int
whs_vector_scan(whs_hdl_t* handle,
                    const char** datas,
                    unsigned int* lens,
                    unsigned int count,
                    unsigned int* id,
                    unsigned int* dataIndex,
                    unsigned long long* to) {
  hs_error_t ret;
  whs_match_t match;

  if (!datas) {
    return -1;
  }

  if (!lens) {
    return -1;
  }

  ret = hs_scan_vector(handle->db, datas, lens, count, 0, handle->scratch,
                       eventHandler, &match);
  if (likely(HS_SUCCESS == ret)) {
    return 0;
  }

  if (likely(HS_SCAN_TERMINATED == ret)) {
    if (likely(id)) {
      *id = match.id;
    }
    if (likely(to)) {
      *to = match.to;
    }
    if (likely(dataIndex)) {
        long long offset = (long long)match.to;
        size_t i;
        for (i = 0; i < count; i++)
        {
            offset -= lens[i];
            if (offset <= 0){
                *dataIndex = i;
                break;
            }
        }
    }

    Debug("MATCH id:%u, from:%llu, to:%llu, flags:%u", match.id, match.from,
          match.to, match.flags);
    return 1;
  }

  Error("hs_scan() return %d", ret);
  return -1;
}

void
whs_vector_free(whs_hdl_t* handle) { 
    return whs_block_free(handle); 
}
