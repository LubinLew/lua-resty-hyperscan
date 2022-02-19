# Copyright (C) LubinLew

INCS=`pkg-config --cflags libhs`
LIBS=`pkg-config --libs   libhs`

all:libwhs.so

libwhs.so:wrapper.o
	gcc -shared -o $@ $^ -lm -lstdc++ -lhs

wrapper.o:wrapper.c wrapper.h
	gcc -c -g -Wall -Werror -fPIC -O2 ${INCS} $< -o $@

clean:
	@rm -f *.o *.so test






############################  TEST  ##################################
test:test.c libwhs.so
	gcc -g -Wall -Werror -I. -o $@ $< -L. -lwhs

runtest:test
	LD_LIBRARY_PATH=. ./test

memtest:test
	LD_LIBRARY_PATH=. valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all --error-limit=no ./test

gdbtest:test
	LD_LIBRARY_PATH=.  gdb ./test
