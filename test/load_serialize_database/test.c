#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

#include <hs.h>

#define DB_STORE_PATH "./serialized.db"
#define TARGET_STRING "1233213313"

static int eventHandler(unsigned int id, unsigned long long from,
                        unsigned long long to, unsigned int flags, void *ctx) {
    printf("Match for id: %u\n", id);
    return HS_SCAN_TERMINATED;
}


int main(void)
{
	hs_error_t ret;
	hs_database_t* db;
    hs_scratch_t *scratch = NULL;
	char* info;
	
	int fd;
	void* db_ptr;
	struct stat sb;

	if((fd = open(DB_STORE_PATH, O_RDONLY)) < 0){
		perror("open");
		return -1;
	}
	
	if((fstat(fd, &sb)) == -1 ){
		perror("fstat");
		return -1;
	}	
	 
	db_ptr = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if(MAP_FAILED == db_ptr){
		perror("mmap");
		return -1;
	}

	ret = hs_serialized_database_info(db_ptr, sb.st_size, &info);
	if (ret != HS_SUCCESS) {
        fprintf(stderr, "ERROR: hs_serialized_database_info failed: %s\n", info);
		munmap(db_ptr, sb.st_size);
		close(fd);
		hs_free_database(db);
		return -1;
	}
	// OUTPUT:Version: 5.3.0 Features: AVX2 Mode: BLOCK
	fprintf(stdout, "SUCCESS: hs_serialized_database_info: %s\n", info);

	
	ret = hs_deserialize_database(db_ptr, sb.st_size, &db);
	if (ret != HS_SUCCESS) {
        fprintf(stderr, "ERROR: serialize database failed: %d\n", ret);
		munmap(db_ptr, sb.st_size);
		close(fd);
		hs_free_database(db);
		return -1;
	}

	munmap(db_ptr, sb.st_size);
	close(fd);

    if (hs_alloc_scratch(db, &scratch) != HS_SUCCESS) {
        fprintf(stderr, "ERROR: Unable to allocate scratch space. Exiting.\n");
        hs_free_database(db);
        return -1;
	}

	ret = hs_scan(db, TARGET_STRING, sizeof(TARGET_STRING)-1, 0, scratch, eventHandler, NULL);
	if (ret != HS_SUCCESS && ret != HS_SCAN_TERMINATED) {
        fprintf(stderr, "ERROR: hs_scan faild, %d\n", ret);
        hs_free_database(db);
	}
	
	hs_free_scratch(scratch);
	hs_free_database(db);

	return 0;
}


