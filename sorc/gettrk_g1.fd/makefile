SHELL=  /bin/sh
ISIZE = 4
RSIZE = 8
FCOMP=  mpiifort -nofree 
FFLAGS= -O3 -g -traceback -convert big_endian -I $(INC) -i$(ISIZE) -r$(RSIZE)

gettrk_g1:      gettrk_main_g1.f gettrk_modules.o 
	@echo " "
	@echo "  Compiling the main tracker program ....."
	$(FCOMP) $(FFLAGS) gettrk_modules.o gettrk_main_g1.f $(LIBS) -o gettrk_g1
	@echo " "

gettrk_modules.o:    gettrk_modules.f
	@echo " "
	@echo "  Compiling the tracker modules....."
	$(FCOMP) $(FFLAGS) -c gettrk_modules.f -o gettrk_modules.o
	@echo " "

CMD =   gettrk_g1

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
