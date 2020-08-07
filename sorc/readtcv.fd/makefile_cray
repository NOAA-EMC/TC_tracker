SHELL=  /bin/sh
#COMP=   ifort
COMP= ftn
#FFLAGS= -O2 -check bounds -check format -xHost -fpe0
FFLAGS= -O3 -g -traceback -convert big_endian

track_convert:      track_convert.f
	@echo " "
	@echo "  Compiling the TC track atcfunix to gen_format program....."
	$(COMP) $(FFLAGS) track_convert.f -o track_convert
	@echo " "

CMD =   track_convert

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
