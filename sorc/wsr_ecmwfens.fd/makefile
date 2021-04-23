SHELL=  /bin/bash
ISIZE = 4
RSIZE = 8
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian -I $(INC) -i$(ISIZE) -r$(RSIZE)

wsr_ecmwfensh: ecmwfensh.f 
	@echo " "
	@echo "  Compiling program ECMWF GRIB1 to NCEP GRIB1...."
	$(COMP) $(FFLAGS) ecmwfensh.f $(LIBS) -o wsr_ecmwfensh
	@echo " "

CMD =   wsr_ecmwfensh

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)

