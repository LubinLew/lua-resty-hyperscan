/* Copyright (C) LubinLew */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include "wrapper.h"


const char* pattern[] = {
    "123456",
    "hello",
    "\\d{5}"
};

const unsigned int ids[] = {
    1001, 1002, 1003
};

const char* inputdata[] = {
    "01234567",
    "hello world",
    "11111111"
};



int test_block(void)
{
    int i, ret;
    whs_hdl_t* handle;

    handle = whs_block_create("test_block", 1); //enable debug output
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
        }
        else {
            printf("NOT MATCHED\n");
        }
    }

    whs_block_free(handle);
    return 0;
}

int test_multi_block(void) {
    int i = 0, ret;
    whs_hdl_t* handle;

    handle = whs_block_create("test_block", 1); //enable debug output
    if (NULL == handle) {
        exit(EXIT_FAILURE);
    }
    unsigned int flags[3] = {
        8 | 2| 1,
        8 | 2| 1,
        8 | 2| 1,
    };

    ret = whs_block_compile(handle, pattern, flags, ids, 3);
    if (ret != 0) {
        exit(EXIT_FAILURE);
    }
    whs_match_t match[30];
    whs_multi_match_t multi_match;
    multi_match.matchs = match;
    multi_match.len = 30;
    multi_match.cur = 0;

    ret = whs_block_scan_multi_match(handle, inputdata[i], strlen(inputdata[i]), &multi_match);
    if (ret >= 0) {
        printf("Match number :%hu\n",multi_match.cur);
        for (i = 0; i < multi_match.cur ; i ++)
            printf("MATCH:%s [ID:%u][%llu-%llu]\n", inputdata[0], multi_match.matchs[i].id, multi_match.matchs[i].from, multi_match.matchs[i].to);
    }
    else {
        printf("NOT MATCHED\n");
    }

    whs_block_free(handle);
    return 0;
}

int test_vector(void)
{
    int ret;
    whs_hdl_t* handle;

    handle = whs_vector_create("test_vector", 1); //enable debug output
    if (NULL == handle) {
        exit(EXIT_FAILURE);
    }

    ret = whs_vector_compile(handle, pattern, NULL, ids, 3);
    if (ret != 0) {
        exit(EXIT_FAILURE);
    }

    const char* inputdata[] = {
        "dasff",
        "dacxf",
        "dhellodd",
        "dadsf",
        "dasfa",
    };
    unsigned int inputdatalen[] = {
        5,
        5,
        8,
        5,
        5,
        5,
    };

    unsigned int id;
    unsigned int dataindex;
    unsigned long long to;
    ret = whs_vector_scan(handle, inputdata, inputdatalen, sizeof(inputdata) / sizeof(const char*), &id, &dataindex, &to);
    if (ret == 1) {
        printf("[ID:%u][dataindex:%u][stop:%llu]\n", id, dataindex, to);
        assert(dataindex == 2);
    }
    else {
        printf("NOT MATCHED\n");
    }

    whs_vector_free(handle);
    return 0;
}


int main()
{
    whs_init();
    test_multi_block();
    test_block();
    test_vector();
    exit(EXIT_SUCCESS);
}