SHELL=  /bin/sh
ISIZE = 4
RSIZE = 8
FCOMP=  mpiifort -nofree
CCOMP=  mpiicc
FFLAGS= -O3 -g -traceback -convert big_endian -I $(INC) -i$(ISIZE) -r$(RSIZE)
CFLAGS= -O3

gettrk_g2:      gettrk_main_g2.f gettrk_modules.o module_waitfor.o cwaitfor.o
	@echo " "
	@echo "  Compiling the main tracking program and subroutines....."
	$(FCOMP) $(FFLAGS) gettrk_modules.o module_waitfor.o cwaitfor.o gettrk_main_g2.f $(LIBS) -o gettrk_g2
	@echo " "

cwaitfor.o: cwaitfor.c
	@echo " "
	@echo "  Compiling the waitfor C routine...."
	$(CCOMP) $(CFLAGS) -c cwaitfor.c -o cwaitfor.o

module_waitfor.o: module_waitfor.f
	@echo " "
	@echo "  Compiling the waitfor fortran module...."
	$(FCOMP) $(FFLAGS) -c module_waitfor.f -o module_waitfor.o

gettrk_modules.o:    gettrk_modules.f
	@echo " "
	@echo "  Compiling the regular tracker fortran modules....."
	$(FCOMP) $(FFLAGS) -c gettrk_modules.f -o gettrk_modules.o
	@echo " "

CMD =   gettrk_g2

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
