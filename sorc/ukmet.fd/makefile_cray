SHELL=  /bin/bash
ISIZE = 4
RSIZE = 8
#COMP=   ifort
COMP= ftn
#FFLAGS= -r8 -i4 -list -traceback
#FFLAGS=-O2 -convert big_endian -traceback -mkl -free
#FFLAGS= -O3 -g -traceback -convert big_endian -free
FFLAGS= -O3 -g -traceback -convert big_endian -free -I $(INC) -i$(ISIZE) -r$(RSIZE)


ukm_hires_merge: ukmhires.f 
	@echo " "
	@echo "  Compiling program UKMET 8-piece-GRIB to NCEP GRIB1...."
	$(COMP) $(FFLAGS) ukmhires.f $(LIBS) -o ukm_hires_merge
	@echo " "

CMD =   ukm_hires_merge

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)

