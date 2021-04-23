SHELL=  /bin/sh
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian

ens_trak_ave_2d:      ens_trak_ave_2d.f
	@echo " "
	@echo "  Compiling the ensemble track averaging program....."
	$(COMP) $(FFLAGS) ens_trak_ave_2d.f -o ens_trak_ave_2d
	@echo " "

CMD = ens_trak_ave_2d

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
