SHELL=  /bin/sh
#COMP=   ifort
COMP= ftn
#FFLAGS= -O2 -check bounds -check format -xHost -fpe0
FFLAGS= -O3 -g -traceback -convert big_endian 

filter_gen_gfs:      filter_gen_gfs.f
	@echo " "
	@echo "  Compiling the ensemble track filter program....."
	$(COMP) $(FFLAGS) filter_gen_gfs.f -o filter_gen_gfs
	@echo " "

CMD = filter_gen_gfs

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
