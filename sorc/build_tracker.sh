#!/bin/sh
set -xeu
source ./machine-setup.sh > /dev/null 2>&1

#Supports Debug or Release modes for the build
BUILD_MODE=${BUILD_MODE:-Release}

cwd=$(pwd)

if [ "${BUILD_MODE}" = Release ]; then
  export BUILD_TYPE=RELEASE
else
  export BUILD_TYPE=DEBUG
fi

module use ../modulefiles
module load $target.lua
module list

cd ..

if [ -d "build" ]; then
   rm -rf build
fi
mkdir build
cd build

cmake .. -DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER} -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}

make -j ${BUILD_JOBS:-8} VERBOSE=2
make install

cd ..

exit
