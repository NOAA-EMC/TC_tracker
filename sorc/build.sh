#!/bin/sh

#---------------------------------------------------------
if [[ ! -d ../exec ]] ; then mkdir ../exec ; fi

# Purge current modules
module purge
# Use modules within
module use .

#---------------------------------------------------------
if [[ -d /gpfs/hps && -e /etc/SuSE-release ]] ; then
 # Load module file for Cray (NOAA Luna or Surge)
 module load Module_ens_tracker.v1.1.15_for_Cray

 machine=cray
 export INC="${G2_INCd} ${NETCDF_INCLUDE} -I${PNETCDF_INC} ${HDF5_INCLUDE}"
 export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${NETCDF_LDFLAGS_CXX} -L${PNETCDF_LIB} ${HDF5_LDFLAGS}"
 export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
 export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
  cd $dir
  make clean
  make -f makefile_cray
  make install
  cd ..
done

elif [[ -L /usrx && "$( readlink /usrx 2> /dev/null )" =~ dell ]] ; then
 # Load module file for Dell (NOAA Mars or Venus)
 module load Module_ens_tracker.v1.1.15_for_Dell

 machine=dell
# export INC="${G2_INCd} ${NETCDF_INCLUDE} ${HDF5_INCLUDE}"
# export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${NETCDF_LDFLAGS} ${HDF5_LDFLAGS}"
 export INC="${G2_INCd} ${NETCDF_INCLUDE} ${PNetCDF_INCLUDE}"
 export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${NETCDF_LDFLAGS} ${PNetCDF_LDFLAGS}"
 export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
 export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
  cd $dir
  make clean
  make -f makefile
  make install
  cd ..
done

elif [[ -d /scratch2 ]] ; then
 # Load module file for NOAA Hera
 module load Module_ens_tracker.v1.1.15_for_Hera

machine=hera
export INC="${G2_INCd} -I${NETCDF}/include -I${HDF5}/include "
#export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} -L${NETCDF}/lib -lnetcdff -lnetcdf -L${HDF5}/lib -lhdf5_hl -lhdf5hl_fortran -lhdf5 -lhdf5_fortran " 
export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} -L${NETCDF}/lib -lnetcdff -lnetcdf -L${HDF5}/lib -lhdf5_hl -lhdf5 " 
export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
#for dir in leadtime.fd; do
  cd $dir
  make clean
  make -f makefile_wcoss
  make install
  cd ..
done

elif [[ -d /work ]] ; then
 # Load module file for MSU Orion
 module load Module_ens_tracker.v1.1.15_for_Orion

machine=orion
export INC="${G2_INCd} -I${NETCDF}/include -I${HDF5_ROOT}/include "
export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} -L${NETCDF}/lib -lnetcdff -lnetcdf -L${HDF5_ROOT}/lib" 
export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
#for dir in gettrk_gfs.fd; do
  cd $dir
  make clean
  make -f makefile_orion
  make install
  cd ..
done

elif [[ -d /lfs3 ]] ; then
 # Load module file for Jet
 module load Module_ens_tracker.v1.1.15_for_Jet

machine=jet
#export INC="${G2_INCd} -I${NETCDF}/include ${PNETCDF_INCLUDE} ${HDF5_INCLUDE_OPTS} "
#export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} -L${NETCDF}/lib -lnetcdf ${PNETCDF_LD_OPTS} ${HDF5_LINK_OPTS}"
export INC="${G2_INCd} -I${NETCDF}/include -I${HDF5}/include "
export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} -L${NETCDF}/lib -lnetcdff -lnetcdf -L${HDF5}/lib -lhdf5_hl -lhdf5 "
export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
#for dir in gettrk_gfs.fd; do
  cd $dir
  make clean
  make -f makefile_jet
  make install
  cd ..
done

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
fi
