/* Copyright (C) LubinLew */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "wrapper.h"


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
    int i, ret;
    whs_hdl_t* handle;

    whs_init();

    handle = whs_block_create("test", 1); //enable debug output
    if (NULL == handle) {
        exit(EXIT_FAILURE);
    }

    ret = whs_block_compile(handle, pattern, NULL, ids, 3);
    if (ret != 0) {
        exit(EXIT_FAILURE);
    }

    for (i = 0; i < 3; i++) {
        unsigned int id;
        unsigned long long from;
        unsigned long long to;
        ret = whs_block_scan(handle, inputdata[i], strlen(inputdata[i]), &id, &from, &to);
        if (ret == 1) {
            printf("MATCH:%s [ID:%u][%llu-%llu]\n", inputdata[i], id, from, to);
        } else {
            printf("NOT MATCHED\n");
        }
    }

    whs_block_free(handle);

    exit(EXIT_SUCCESS);
}
