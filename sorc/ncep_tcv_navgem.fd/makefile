SHELL=  /bin/sh
COMP=   mpiifort
FFLAGS= -O3 -g -traceback -convert big_endian 

tcvital_ch_navgem:      tcvital_ch_navgem.f
	@echo " "
	@echo "  Compiling the TC_vital track program....."
	$(COMP) $(FFLAGS) tcvital_ch_navgem.f -o tcvital_ch_navgem
	@echo " "

CMD = tcvital_ch_navgem

clean:
	-rm -f  *.mod

install:
	mv $(CMD) ../../exec/$(CMD)
