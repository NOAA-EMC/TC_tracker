#!/bin/sh
set -x -e

mac=`echo ${SITE}`
#---------------------------------------------------------
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
                                                 # --------
machine=wcoss
export INC="${G2_INCd} ${NETCDF_INCLUDE} -I${PNETCDF}/include ${HDF5_INCLUDE}"
export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${SP_LIBd} ${IP_LIBd} ${NETCDF_LDFLAGS} -L${PNETCDF}/lib -lpnetcdf ${HDF5_LDFLAGS}"
export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
  cd $dir
  make clean
  make -f makefile_wcoss
  make install
  cd ..
done
#---------------------------------------------------------

elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
                                                 # --------
 machine=cray
 export INC="${G2_INCd} ${NETCDF_INCLUDE} -I${PNETCDF_INC} ${HDF5_INCLUDE}"
 export LIBS="${W3EMC_LIBd} ${W3NCO_LIBd} ${BACIO_LIB4} ${G2_LIBd} ${PNG_LIB} ${JASPER_LIB} ${Z_LIB} ${NETCDF_LDFLAGS_CXX} -L${PNETCDF_LIB} ${HDF5_LDFLAGS}"
 export LIBS_SUP="${W3EMC_LIBd} ${W3NCO_LIBd}"
 export LIBS_UK="${W3NCO_LIB4} ${BACIO_LIB4}"

for dir in *.fd; do
  cd $dir
  make clean
  make -f makefile
  make install
  cd ..
done

fi
