SHELL=  /bin/sh
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian

readprob:      readprob.f
	@echo " "
	@echo "  Compiling the TC genesis probability program....."
	$(COMP) $(FFLAGS) readprob.f -o readprob
	@echo " "

CMD = readprob

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
