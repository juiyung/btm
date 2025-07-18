CC = c99
CFLAGS = -Wall -pedantic -O2

all: btm-emul btm-enum

clean:
	rm -f btm-emul btm-enum *.o

btm-emul: btm-emul.o btm.o util.o
	$(CC) $(CFLAGS) -o $@ btm-emul.o btm.o util.o

btm-enum: btm-enum.o btm.o util.o
	$(CC) $(CFLAGS) -o $@ btm-enum.o btm.o util.o

btm-emul.o: btm-emul.c btm.h util.h
	$(CC) -c $(CFLAGS) -o $@ btm-emul.c

btm-enum.o: btm-enum.c btm.h util.h
	$(CC) -c $(CFLAGS) -o $@ btm-enum.c

btm.o: btm.c btm.h
	$(CC) -c $(CFLAGS) -o $@ btm.c

util.o: util.c util.h
	$(CC) -c $(CFLAGS) -o $@ util.c

.PHONY: all clean
