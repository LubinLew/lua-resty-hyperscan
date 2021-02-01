#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <hs.h>

#define DB_STORE_PATH "./serialized.db"

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



int main(void)
{
	hs_database_t* db;
	hs_compile_error_t* compile_err;
	unsigned int elements = sizeof(pattern)/sizeof(pattern[0]); 
	hs_error_t ret;
	char* db_ptr;
	size_t db_size;
	FILE* fp;
	size_t ret_size;
	
	ret = hs_compile_ext_multi(pattern, NULL, ids, NULL, elements, 
    					HS_MODE_BLOCK, NULL, &db, &compile_err);
	if (ret) {
        fprintf(stderr, "ERROR: Unable to compile pattern: %s\n", compile_err->message);
        hs_free_compile_error(compile_err);
        return -1;
	}

	ret = hs_serialize_database(db, &db_ptr, &db_size);
	if (ret != HS_SUCCESS) {
        fprintf(stderr, "ERROR: serialize database failed: %d\n", ret);
		hs_free_database(db);
		return -1;
	}

	hs_free_database(db);

	fp = fopen(DB_STORE_PATH, "wb");
	if (NULL == fp) {
		free(db_ptr);
        fprintf(stderr, "ERROR: fopen failed: %s\n", strerror(errno));
		return -1;
	}

	ret_size = fwrite(db_ptr, 1, db_size, fp);
	if (ret_size != db_size) {
        fprintf(stderr, "ERROR: fwrite failed: %zu/%zu\n", ret_size, db_size);
	}

	free(db_ptr);
	fclose(fp);

	return 0;
}


