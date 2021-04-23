SHELL=  /bin/sh
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian

readprobLL:      readprobLL.f
	@echo " "
	@echo "  Compiling the TC genesis probability program....."
	$(COMP) $(FFLAGS) readprobLL.f -o readprobLL
	@echo " "

CMD = readprobLL

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
