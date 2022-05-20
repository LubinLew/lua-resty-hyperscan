/* Copyright (C) LubinLew */

#ifndef __HS_WRAPPER_H__
#define __HS_WRAPPER_H__

typedef struct _whs_match {
    unsigned int id;
    unsigned long long from;
    unsigned long long to;
    unsigned int flags;
} whs_match_t;

typedef struct _whs_multi_match {
    whs_match_t* matchs;
    uint16_t len;
    uint16_t cur;
} whs_multi_match_t;

typedef struct _whs_hdl whs_hdl_t;

/* test the current system architecture 
 * Return:
 *     -1: This system does not support Hyperscan
 *      0: success
 */
int
whs_init(void);


/** create a new hyperscan block scan mode instance
 * Parameter:
 *    debug : 0(disable debug), other(enable debug)
 * Return:
 *   NULL  : Fail(Out of memory)
 *  Non-null : Success(return a handle)
 */
whs_hdl_t *
whs_block_create(const char *name, int debug);


/** Compiling Patterns for block mode
 * Return:
 *    0 : Success
 *   -1 : Error occurred
 */
int
whs_block_compile(whs_hdl_t *handle,
                  const char *const *expressions,
                  const unsigned int *flags,
                  const unsigned int *ids,
                  unsigned int count);


/** Scanning for Patterns for block mode
 * Return:
 *    0 : Success(not matched)
 *    1 : Matched
 *   -1 : Error occurred
 */
int
whs_block_scan(whs_hdl_t *handle,
               const char *data,
               unsigned int len,
               unsigned int *id,
               unsigned long long *from,
               unsigned long long *to);

int
whs_block_scan_multi_match(whs_hdl_t* handle,
    const char* data,
    unsigned int len,
    whs_multi_match_t* ctx);


/* destroy the hyperscan block scan mode instance */
void
whs_block_free(whs_hdl_t *handle);


/** create a new hyperscan vector scan mode instance
 * Parameter:
 *    debug : 0(disable debug), other(enable debug)
 * Return:
 *   NULL  : Fail(Out of memory)
 *  Non-null : Success(return a handle)
 */
whs_hdl_t *
whs_vector_create(const char *name, int debug);


/** Compiling Patterns for vector mode
 * Return:
 *    0 : Success
 *   -1 : Error occurred
 */
int
whs_vector_compile(whs_hdl_t *handle,
                   const char *const *expressions,
                   const unsigned int *flags,
                   const unsigned int *ids,
                   unsigned int count);


/** Scanning for Patterns for vector mode
 * Return:
 *    0 : Success(not matched)
 *    1 : Matched
 *   -1 : Error occurred
 */
int
whs_vector_scan(whs_hdl_t *handle,
                const char **datas,
                unsigned int *lens,
                unsigned int count,
                unsigned int *id,
                unsigned int *dataIndex,
                unsigned long long *to);

int
whs_vector_scan_multi_match(whs_hdl_t* handle,
    const char** datas,
    unsigned int* lens,
    unsigned int count,
    whs_multi_match_t* ctx);

/* destroy the hyperscan vector scan mode instance */
void
whs_vector_free(whs_hdl_t *handle);

int whs_serialize_database(whs_hdl_t *handle, char** bytes, size_t* len);

whs_hdl_t* whs_deserialize_database(const char* name, const char *bytes, size_t len);


#endif  /* __HS_WRAPPER_H__ */

