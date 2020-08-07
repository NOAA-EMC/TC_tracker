SHELL=  /bin/sh
#COMP=   ifort
COMP= ftn
#FFLAGS= -O2 -check bounds -check format -xHost -fpe0
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
