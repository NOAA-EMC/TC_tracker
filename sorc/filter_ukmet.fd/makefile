SHELL=  /bin/sh
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian 

filter_gen_ukmet:      filter_gen_ukmet.f
	@echo " "
	@echo "  Compiling the ensemble track filter program....."
	$(COMP) $(FFLAGS) filter_gen_ukmet.f -o filter_gen_ukmet
	@echo " "

CMD = filter_gen_ukmet

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
