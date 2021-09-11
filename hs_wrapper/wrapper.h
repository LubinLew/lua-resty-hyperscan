/* Copyright (C) LubinLew */

#ifndef __HS_WRAPPER_H__
#define __HS_WRAPPER_H__


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
whs_hdl_t*
whs_block_create(const char *name, int debug);


/** Compiling Patterns for block mode
 * Return:
 *    0 : Success
 *   -1 : Error occurred
 */
int
whs_block_compile(whs_hdl_t* handle,
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
whs_block_scan(whs_hdl_t* handle,
                  const char *data, 
                  unsigned int len,
                  unsigned int *id,
                  unsigned long long *from,
                  unsigned long long *to);


/* destroy the hyperscan block scan mode instance */
void
whs_block_free(whs_hdl_t* handle);




#endif  /* __HS_WRAPPER_H__ */

