SHELL=  /bin/sh
ISIZE = 4
RSIZE = 8
FCOMP=  mpiifort -nofree
FFLAGS= -O3 -g -traceback -convert big_endian -I $(INC) -i$(ISIZE) -r$(RSIZE)

tave_g1: tave_g1.f 
	@echo " "
	@echo "  Compiling the mean field program and subroutines....."
	$(FCOMP) $(FFLAGS) tave_g1.f $(LIBS) -o tave_g1.x
	@echo " "

CMD =   tave_g1.x

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
