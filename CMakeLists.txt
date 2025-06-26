#=======================================================================
#$$$ CMAKEFILE DOCUMENTATION BLOCK
# Biju Thomas
# Email: biju.thomas@noaa.gov
#=======================================================================

cmake_minimum_required(VERSION 3.15)
project(
  HAFS_TOOLS
  LANGUAGES C Fortran)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules/")

message(CMAKE_MODULE_PATH " ${CMAKE_MODULE_PATH}")
if(NOT CMAKE_Fortran_COMPILER_ID MATCHES "^(Intel|GNU)$")
  message(WARNING "Compiler not officially supported: ${CMAKE_Fortran_COMPILER_ID}")
endif()

if(NOT CMAKE_C_COMPILER_ID MATCHES "^(Intel|GNU)$")
  message(WARNING "Compiler not officially supported: ${CMAKE_C_COMPILER_ID}")
endif()


find_package(NetCDF REQUIRED C Fortran)
#find_package(HDF5 REQUIRED)
find_package(PNG REQUIRED)
find_package(Jasper REQUIRED)
find_package(ZLIB REQUIRED)
find_package(g2 REQUIRED)
find_package(bacio REQUIRED)
set (USE_W3EMC FALSE)
if(NOT g2_VERSION VERSION_GREATER_EQUAL "3.5.0")
  message(STATUS "g2 version ${g2_VERSION} < 3.5.0, w3emc package is needed")
  set(USE_W3EMC TRUE)
endif()
# Regardless, w3emc is required by g2.
find_package(w3emc REQUIRED)

add_subdirectory(sorc/gettrk_gfs.fd)
add_subdirectory(sorc/ens_trak_ave.fd)
add_subdirectory(sorc/filter_gfs.fd)
add_subdirectory(sorc/rhum_g2.fd)
add_subdirectory(sorc/ens_trak_ave_2d.fd)
add_subdirectory(sorc/filter_ecmwf.fd)
add_subdirectory(sorc/filter_cmc.fd)
add_subdirectory(sorc/filter_ukmet.fd)
add_subdirectory(sorc/filter_navgem.fd)
add_subdirectory(sorc/ncep_tcv_ecmwf.fd)
add_subdirectory(sorc/ncep_tcv_cmc.fd)
add_subdirectory(sorc/ncep_tcv_navgem.fd)
add_subdirectory(sorc/ncep_tcv_ukmet.fd)
add_subdirectory(sorc/ncep_tcv_gfs.fd)
add_subdirectory(sorc/wsr_ecmwfens.fd)
add_subdirectory(sorc/leadtime.fd)
add_subdirectory(sorc/readprob.fd)
add_subdirectory(sorc/readtcv.fd)
add_subdirectory(sorc/readprobLL.fd)
add_subdirectory(sorc/tave_g1.fd)
add_subdirectory(sorc/tave_g2.fd)
add_subdirectory(sorc/supvit_g1.fd)
add_subdirectory(sorc/supvit_g2.fd)
add_subdirectory(sorc/gettrk_gen_g1.fd)
add_subdirectory(sorc/gettrk_gen_g2.fd)
add_subdirectory(sorc/gettrk_gen_gfs.fd)
add_subdirectory(sorc/gettrk_g1.fd)
add_subdirectory(sorc/gettrk_g2.fd)
add_subdirectory(sorc/ushear_g1.fd)
add_subdirectory(sorc/ushear_g2.fd)
add_subdirectory(sorc/vint_g1.fd)
add_subdirectory(sorc/vint_g2.fd)
add_subdirectory(sorc/ukmet.fd)
