.PYONY: all clean

TARGET := test
CC     := gcc
INCS   := -I/usr/local/include/hs      #`pkg-config --cflags libhs`
LFLAGS := -L/usr/local/lib64 -lhs      #`pkg-config --libs libhs`
CFLAGS := -g -Wall


all:
	${CC} ${CFLAGS} ${INCS} test.c -o ${TARGET} ${LFLAGS} 
	
clean:
	rm -f ${TARGET}
