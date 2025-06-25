help([[
loads TC_tracker modulefile and related set environment veriables on Hera
]])

prepend_path("MODULEPATH", "/contrib/sutils/modulefiles")
load("sutils")
load("hpss")

prepend_path("MODULEPATH", "/contrib/spack-stack/spack-stack-1.9.1/envs/ue-oneapi-2024.2.1/install/modulefiles/Core")

stack_oneapi_ver=os.getenv("stack_oneapi_ver") or "2024.2.1"
load(pathJoin("stack-oneapi", stack_oneapi_ver))

stack_impi_ver=os.getenv("stack_impi_ver") or "2021.13"
load(pathJoin("stack-intel-oneapi-mpi", stack_impi_ver))

python_ver=os.getenv("python_ver") or "3.11.7"
load(pathJoin("python", python_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

jasper_ver=os.getenv("jasper_ver") or "2.0.32"
load(pathJoin("jasper", jasper_ver))

zlib_ver=os.getenv("zlib_ver") or "1.2.13"
load(pathJoin("zlib", zlib_ver))

libpng_ver=os.getenv("libpng_ver") or "1.6.37"
load(pathJoin("libpng", libpng_ver))

hdf5_ver=os.getenv("hdf5_ver") or "1.14.3"
load(pathJoin("hdf5", hdf5_ver))

netcdf_c_ver=os.getenv("netcdf_c_ver") or "4.9.2"
load(pathJoin("netcdf-c", netcdf_c_ver))

netcdf_fortran_ver=os.getenv("netcdf_fortran_ver") or "4.6.1"
load(pathJoin("netcdf-fortran", netcdf_fortran_ver))

bacio_ver=os.getenv("bacio_ver") or "2.4.1"
load(pathJoin("bacio", bacio_ver))

g2_ver=os.getenv("g2_ver") or "3.5.1"
load(pathJoin("g2", g2_ver))

g2tmpl_ver=os.getenv("g2tmpl_ver") or "1.13.0"
load(pathJoin("g2tmpl", g2tmpl_ver))

sigio_ver=os.getenv("sigio_ver") or "2.3.3"
load(pathJoin("sigio", sigio_ver))

prod_util_ver=os.getenv("prod_util_ver") or "2.1.1"
load(pathJoin("prod_util", prod_util_ver))

wgrib2_ver=os.getenv("wgrib2_ver") or "3.6.0"
load(pathJoin("wgrib2", wgrib2_ver))

grib_util_ver=os.getenv("grib_util_ver") or "1.4.0"
load(pathJoin("grib-util", grib_util_ver))

setenv("CMAKE_C_COMPILER", "mpiicc")
setenv("CMAKE_CXX_COMPILER", "mpiicpc")
setenv("CMAKE_Fortran_COMPILER", "mpiifort")
setenv("CMAKE_Platform", "hera.intel")
