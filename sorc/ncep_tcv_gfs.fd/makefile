SHELL=  /bin/sh
COMP=   mpiifort
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
