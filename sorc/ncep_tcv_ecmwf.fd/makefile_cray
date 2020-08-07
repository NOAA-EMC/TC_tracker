SHELL=  /bin/sh
#COMP=   ifort
COMP= ftn
#FFLAGS= -O2 -check bounds -check format -xHost -fpe0
FFLAGS= -O3 -g -traceback -convert big_endian 

tcvital_ch_ecmwf:      tcvital_ch_ecmwf.f
	@echo " "
	@echo "  Compiling the TC_vital track program....."
	$(COMP) $(FFLAGS) tcvital_ch_ecmwf.f -o tcvital_ch_ecmwf
	@echo " "

CMD = tcvital_ch_ecmwf

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
