SHELL=  /bin/sh
ISIZE = 4
RSIZE = 8
FCOMP=  mpiifort -nofree
FFLAGS= -O3 -g -traceback -convert big_endian -I $(INC) -i$(ISIZE) -r$(RSIZE)

rhum_g2: rhum_g2.f 
	@echo " "
	@echo "  Compiling the RH subroutines....."
	$(FCOMP) $(FFLAGS) rhum_g2.f $(LIBS) -o rhum_g2.x
	@echo " "

CMD =   rhum_g2.x

clean:
	-rm -f  *.o  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
