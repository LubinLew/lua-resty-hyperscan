#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <hs.h>

const char * pattern[] = {
	"123456",
	"hello",
	"\\d{5}"
};

const unsigned int ids[] = {
	1001, 1002, 1003
};

const char * inputdata[] = {
	"01234567",
	"hello world",
	"11111111"
};


static int eventHandler(unsigned int id, unsigned long long from,
                        unsigned long long to, unsigned int flags, void *ctx) {
    printf("Match for id: %u\n", id);
    return HS_SCAN_TERMINATED;
}


int main(void)
{
	int i = 0;
	hs_database_t* db;
	hs_compile_error_t* compile_err;
	unsigned int elements = sizeof(pattern)/sizeof(pattern[0]); 
	hs_error_t ret;
    hs_scratch_t *scratch = NULL;
	
	ret = hs_compile_ext_multi(pattern, NULL, ids, NULL, elements, 
    					HS_MODE_BLOCK, NULL, &db, &compile_err);
	if (ret) {
        fprintf(stderr, "ERROR: Unable to compile pattern: %s\n", compile_err->message);
        hs_free_compile_error(compile_err);
        return -1;
	}

    if (hs_alloc_scratch(db, &scratch) != HS_SUCCESS) {
        fprintf(stderr, "ERROR: Unable to allocate scratch space. Exiting.\n");
        hs_free_database(db);
        return -1;
	}

	for (i = 0; i < 3; ++i) {
		fprintf(stdout, "inputdata %s\n", inputdata[i]);
		ret = hs_scan(db, inputdata[i], strlen(inputdata[i]), 0, scratch, eventHandler, NULL);
		if (ret != HS_SUCCESS && ret != HS_SCAN_TERMINATED) {
	        fprintf(stderr, "ERROR: Unable to scan input buffer. Exiting.\n");
	        hs_free_scratch(scratch);
	        hs_free_database(db);
	        return -1;
	    }
	}
	
	hs_free_scratch(scratch);
	hs_free_database(db);

	return 0;
}


