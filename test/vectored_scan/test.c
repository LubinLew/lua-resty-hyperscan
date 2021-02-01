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

typedef struct _str {
	char*  data;
	size_t len;
}str_t;

#define strelm(a) {a, sizeof(a)-1}

static str_t inputdata[] = {
	strelm("ABChelo"),
	strelm("555 world"),
	strelm("xccx333@@@"),
	strelm("666sssa123"),
	strelm("dddxxx45"),
	strelm("1345563444")
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
	unsigned int* length;
	unsigned int count;
	const char** data;
	
	ret = hs_compile_ext_multi(pattern, NULL, ids, NULL, elements, 
    					HS_MODE_VECTORED, NULL, &db, &compile_err);
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
	
	count = sizeof(inputdata)/sizeof(str_t);
	length = calloc(sizeof(unsigned int), count);
	data = calloc(sizeof(char*), count);
	for (i = 0; i < count; i++) {
		data[i] = inputdata[i].data;
		length[i] = inputdata[i].len;
	}
	ret = hs_scan_vector(db, data, length, count, 0, scratch, eventHandler, NULL);
	if (ret != HS_SUCCESS && ret != HS_SCAN_TERMINATED) {
		fprintf(stderr, "ERROR: Unable to scan input buffer. Exiting.\n");
		hs_free_scratch(scratch);
		hs_free_database(db);
		return -1;
	}
	
	hs_free_scratch(scratch);
	hs_free_database(db);

	return 0;
}


