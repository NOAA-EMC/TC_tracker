SHELL=  /bin/sh
#COMP=   ifort
COMP= ftn
#FFLAGS= -O2 -check bounds -check format -xHost -fpe0
FFLAGS= -O3 -g -traceback -convert big_endian 

tcvital_ch_gfs:      tcvital_ch_gfs.f
	@echo " "
	@echo "  Compiling the TC_vital track program....."
	$(COMP) $(FFLAGS) tcvital_ch_gfs.f -o tcvital_ch_gfs
	@echo " "

CMD = tcvital_ch_gfs

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
