#!/bin/ksh
export PS4=' + exwsr_ecmwfens.sh line $LINENO: '

####################################################################
set +xa
echo "------------------------------------------------"
echo "JECMFENSH - ECMWF HR ensemble postprocessing"
echo "------------------------------------------------"
echo "History: JAN 2001 - ECMWF ensemble conversion job based on "
echo "                    Tim Marchok's Cray job by Richard Wobus "
echo "         FEB 2001 - correct headers on statistics, add rh700"
echo "         SEP 2004 - high resolution version"
echo "         May 2011 - modified by J.Peng based on ECMWF data input"
set -xa
#####################################################################

###########################################################
# Processing/Flow of script
# 1) Copy this job's input files to the working directory
# 2) Extract variables to be processed from input files
# 3) Convert ensemble header extensions and make statistics
# 4) Append results to output files
# 5) Save output files to $COMOUT
# 6) Remove files located in this job's working directory
###########################################################
export DATA=$1
export hourinc=$2

cd $DATA

msg="HAS BEGUN on `hostname`"
postmsg "$jlogfile" "$msg"

#####################################################################
# Set names of executable utilities
#####################################################################

wgribx="${WGRIB:?} -ncep_opn"

#########################################################
# !!! DEFINE MAXIMUM NUMBER OF PERTURBATION RECORDS
# (This number does NOT include the LRC or HRC)
#########################################################

maxmem=50

#####################################################################
# Set date variables to process yesterday's data
#####################################################################
cent=`echo $PDY | cut -c1-2 `
yy=`  echo $PDY | cut -c3-4 `
mm=`  echo $PDY | cut -c5-6 `
dd=`  echo $PDY | cut -c7-8 `

ymdh=${PDY}${cyc}
imdh=${mm}${dd}${cyc}
echo " Date to copy is $PDY"

prev_cycle=t${cyc}z

#export INDATA=/dcom/us007003/${PDY}/wgrbbul/ecmwf
export INDATA=${eensdcom}
#####################################################################
#
#   Now process all the records into the forecast output files.
#
#####################################################################

echo " "
echo "*----------------------------------------------------------*"
echo "        NOW COPYING RECORDS TO FORECAST FILES...."
echo "*----------------------------------------------------------*"
echo "The time just before copying begins is: `date`"

#hourix=0

#---J.Peng----2010-12-13--------------------------------------
#while [ ${hourix} -lt 21 ];
#while [ ${hourix} -lt 41 ];
#do

#  let hourinc=hourix*12
#  let hourinc=hourix*6
  vymdh=` ${NDATE:?} ${hourinc} ${ymdh}`
  vmdh=`  echo ${vymdh} | cut -c5-10`
  vhour=` ${NHOUR:?} ${vymdh} ${ymdh}`

  echo `date` begin "vmdh = $vmdh"

  # Construct the ECMWF file name.
  # Each file name contains the initial time and
  # the time at which the forecast is valid.

  #ifil=ecens_DCE${imdh}00${vmdh}001
  ifil=DCE${imdh}00${vmdh}001

#---J.Peng----2010-12-13--------------------------------------
#  ifile=${dcom}/$PDY/wgrbbul/$ifil
  ifile=${INDATA}/$ifil
  echo "ifile = $ifile"

  let attempts=1
  while [ $attempts -le 30 ]; do
     if [ -s $ifile ]; then
        break
     else
        sleep 60
        let attempts=attempts+1
     fi
  done
  if [ $attempts -gt 30 ] && [ ! -s $ifile ]; then
     set +x; echo " "
     echo "FATAL ERROR:  $ifile still not available after waiting 30 minutes... exiting"
     echo " "; set -x
     err_exit
  fi

  # Copy the file from dcom
  cpreq $ifile $ifil

  # The reason we need to use that Fortran program is we need to change
  # the GRIB file from ECMWF GRIB format to NCEP GRIB format.
  $wgribx -s $ifil -d all -grib -o eccut.${ymdh}.f${vhour}

  echo " "
  echo "*---------------------------------------------------*"
  echo "  Now in forecast part for ftime= ${hourinc}"
  echo "*---------------------------------------------------*"
  echo " "

  resflag=2

  echo "FORECAST: ftype= DCE, ftime= $hourinc"
#------J.Peng----2010-12-13-----------------------------------
  export pgm=wsr_ecmwfensh
  . prep_step

  export XLFUNIT_11="eccut.${ymdh}.f${vhour}"
  ${GRBINDEX:?} $XLFUNIT_11 eccut.${ymdh}.f${vhour}.i
  export XLFUNIT_21="eccut.${ymdh}.f${vhour}.i"

  export XLFUNIT_51="tmpt200"
  export XLFUNIT_151="tmpt200stat"
  export XLFUNIT_52="tmpt500"
  export XLFUNIT_152="tmpt500stat"
  export XLFUNIT_53="tmpt700"
  export XLFUNIT_153="tmpt700stat"
  export XLFUNIT_54="tmpt850"
  export XLFUNIT_154="tmpt850stat"
  export XLFUNIT_55="tmpt2m"
  export XLFUNIT_155="tmpt2mstat"
  export XLFUNIT_56="tmpt2max"
  export XLFUNIT_156="tmpt2maxstat"
  export XLFUNIT_57="tmpt2min"
  export XLFUNIT_157="tmpt2minstat"
  export XLFUNIT_58="tmptd2m"
  export XLFUNIT_158="tmptd2mstat"

  export XLFUNIT_61="tmpz200"
  export XLFUNIT_161="tmpz200stat"
  export XLFUNIT_62="tmpz500"
  export XLFUNIT_162="tmpz500stat"
  export XLFUNIT_63="tmpz700"
  export XLFUNIT_163="tmpz700stat"
  export XLFUNIT_64="tmpz850"
  export XLFUNIT_164="tmpz850stat"
  export XLFUNIT_65="tmpz1000"
  export XLFUNIT_165="tmpz1000stat"

  export XLFUNIT_71="tmprh500"
  export XLFUNIT_171="tmprh500stat"
  export XLFUNIT_72="tmprh700"
  export XLFUNIT_172="tmprh700stat"
  export XLFUNIT_73="tmprh850"
  export XLFUNIT_173="tmprh850stat"

  export XLFUNIT_81="tmpmslp"
  export XLFUNIT_181="tmpmslpstat"
  export XLFUNIT_82="tmppsfc"
  export XLFUNIT_182="tmppsfcstat"
  export XLFUNIT_83="tmpprcp"
  export XLFUNIT_183="tmpprcpstat"
  export XLFUNIT_84="tmptcdc"
  export XLFUNIT_184="tmptcdcstat"

  export XLFUNIT_101="tmpu200"
  export XLFUNIT_102="tmpv200"
  export XLFUNIT_103="tmpu500"
  export XLFUNIT_104="tmpv500"
  export XLFUNIT_105="tmpu700"
  export XLFUNIT_106="tmpv700"
  export XLFUNIT_107="tmpu850"
  export XLFUNIT_108="tmpv850"
  export XLFUNIT_109="tmpu10m"
  export XLFUNIT_110="tmpv10m"

  echo " &namin"                                      >input1
  echo "    kres=${resflag},kmaxmem=${maxmem}"       >>input1
  echo " /"                                          >>input1

  if [ -s eccut.${ymdh}.f${vhour} ]
  then
    set +x
    echo "File ${ifil} is copied/wgribbed as eccut.${ymdh}.f${vhour}"
    echo "Now converting format..."
    set -x

    export pgm=wsr_ecmwfensh
    msg="$pgm start for eens_grib1 at ${ymdh}_${vhour}"
    postmsg "$jlogfile" "$msg"
    . prep_step
    startmsg
    ${EXECecme}/wsr_ecmwfensh <input1 >ec.DCE.f${vhour} >> $pgmout 2> errfile
    ecmwfrcc=$?

    if [ ${ecmwfrcc} -eq 0 ]; then
      msg="$pgm end for eens_grib1 at ${ymdh}_${vhour} completed normally"
      postmsg "$jlogfile" "$msg"
    else
      set +x
      echo " "
      echo "FATAL ERROR:  An error occurred while running wsr_ecmwfensh "
      echo "!!! which is the program for ECgrib1-NCEPgrib1             "
      echo "!!! Return code from wsr_ecmwfensh = ${ecmwfrcc} "
      echo "!!! Exiting...at ${ymdh}_${vhour}"
      echo " "
      set -x
      err_exit "FAILED ${jobid} - ERROR RUNNING wsr_ecmwfensh - ABNORMAL EXIT"
    fi

#    if [[ -s tmpt200 ]]; then
#      cat tmpt200      >>ensposte.$prev_cycle.t200hr
#      cat tmpt200stat  >>ensstate.$prev_cycle.t200hr
#    fi
#    if [[ -s tmpt500 ]]; then
#      cat tmpt500      >>ensposte.$prev_cycle.t500hr
#      cat tmpt500stat  >>ensstate.$prev_cycle.t500hr
#    fi
#    if [[ -s tmpt700 ]]; then
#      cat tmpt700      >>ensposte.$prev_cycle.t700hr
#      cat tmpt700stat  >>ensstate.$prev_cycle.t700hr
#    fi
#    if [[ -s tmpt850 ]]; then
#      cat tmpt850      >>ensposte.$prev_cycle.t850hr
#      cat tmpt850stat  >>ensstate.$prev_cycle.t850hr
#    fi
#    if [[ -s tmpt2m ]]; then
#      cat tmpt2m       >>ensposte.$prev_cycle.t2mhr
#      cat tmpt2mstat   >>ensstate.$prev_cycle.t2mhr
#    fi
#    if [[ -s tmpt2max ]]; then
#      cat tmpt2max       >>ensposte.$prev_cycle.t2maxhr
#      cat tmpt2maxstat   >>ensstate.$prev_cycle.t2maxhr
#    fi
#    if [[ -s tmpt2min ]]; then
#      cat tmpt2min       >>ensposte.$prev_cycle.t2minhr
#      cat tmpt2minstat   >>ensstate.$prev_cycle.t2minhr
#    fi
#    if [[ -s tmptd2m ]]; then
#      cat tmptd2m       >>ensposte.$prev_cycle.td2mhr
#      cat tmptd2mstat   >>ensstate.$prev_cycle.td2mhr
#    fi

#    if [[ -s tmpz200 ]]; then
#      cat tmpz200      >>ensposte.$prev_cycle.z200hr
#      cat tmpz200stat  >>ensstate.$prev_cycle.z200hr
#    fi
#    if [[ -s tmpz500 ]]; then
#      cat tmpz500      >>ensposte.$prev_cycle.z500hr
#      cat tmpz500stat  >>ensstate.$prev_cycle.z500hr
#    fi
#    if [[ -s tmpz700 ]]; then
#      cat tmpz700      >>ensposte.$prev_cycle.z700hr
#      cat tmpz700stat  >>ensstate.$prev_cycle.z700hr
#    fi
#    if [[ -s tmpz850 ]]; then
#      cat tmpz850      >>ensposte.$prev_cycle.z850hr
#      cat tmpz850stat  >>ensstate.$prev_cycle.z850hr
#    fi
#    if [[ -s tmpz1000 ]]; then
#      cat tmpz1000     >>ensposte.$prev_cycle.z1000hr
#      cat tmpz1000stat >>ensstate.$prev_cycle.z1000hr
#    fi

#    if [[ -s tmprh500 ]]; then
#      cat tmprh500     >>ensposte.$prev_cycle.rh500hr
#      cat tmprh500stat >>ensstate.$prev_cycle.rh500hr
#    fi
#    if [[ -s tmprh700 ]]; then
#      cat tmprh700     >>ensposte.$prev_cycle.rh700hr
#      cat tmprh700stat >>ensstate.$prev_cycle.rh700hr
#    fi
#    if [[ -s tmprh850 ]]; then
#      cat tmprh850     >>ensposte.$prev_cycle.rh850hr
#      cat tmprh850stat >>ensstate.$prev_cycle.rh850hr
#    fi

#    if [[ -s tmpmslp ]]; then
#      cat tmpmslp      >>ensposte.$prev_cycle.mslphr
#      cat tmpmslpstat  >>ensstate.$prev_cycle.mslphr
#    fi
#    if [[ -s tmppsfc ]]; then
#      cat tmppsfc      >>ensposte.$prev_cycle.psfchr
#      cat tmppsfcstat  >>ensstate.$prev_cycle.psfchr
#    fi
#    if [[ -s tmpprcp ]]; then
#      cat tmpprcp      >>ensposte.$prev_cycle.prcphr
#      cat tmpprcpstat  >>ensstate.$prev_cycle.prcphr
#    fi
#    if [[ -s tmptcdc ]]; then
#      cat tmptcdc      >>ensposte.$prev_cycle.tcdchr
#      cat tmptcdcstat  >>ensstate.$prev_cycle.tcdchr
#    fi

#    if [[ -s tmpu200 ]]; then
#      cat tmpu200      >>ensposte.$prev_cycle.u200hr
#      cat tmpv200      >>ensposte.$prev_cycle.v200hr
#    fi
#    if [[ -s tmpu500 ]]; then
#      cat tmpu500      >>ensposte.$prev_cycle.u500hr
#      cat tmpv500      >>ensposte.$prev_cycle.v500hr
#    fi
#    if [[ -s tmpu700 ]]; then
#      cat tmpu700      >>ensposte.$prev_cycle.u700hr
#      cat tmpv700      >>ensposte.$prev_cycle.v700hr
#    fi
#    if [[ -s tmpu850 ]]; then
#      cat tmpu850      >>ensposte.$prev_cycle.u850hr
#      cat tmpv850      >>ensposte.$prev_cycle.v850hr
#    fi
#    if [[ -s tmpu10m ]]; then
#      cat tmpu10m      >>ensposte.$prev_cycle.u10mhr
#      cat tmpv10m      >>ensposte.$prev_cycle.v10mhr
#    fi

#    rm tmp*
  else
    echo "!!! file ${ifile} is not copied !!!"
    echo "   "
  fi

#--------J.Peng---2010-12-13----------------------------------------------
## test output copy may be removed
#    if (( hourix == 2 )) ; then
#      echo
#      echo "##################################" ec.DCE.f${vhour} begin
#      echo
#      cat ec.DCE.f${vhour}
#      echo
#      echo "##################################" ec.DCE.f${vhour} end
#      echo
#    fi
####e

  echo `date` end "vmdh = $vmdh"

#  let hourix=hourix+1
#done

#for file in ensposte.* ensstate.*
#do
#  ${GRBINDEX:?} ${file} ${file}.i
#done

###################################
# Copy output (ECMWF ensemble GRIB1) data to $COMOUT
###################################
#if [ "$SENDCOM" = 'YES' ]; then
#  cp ensposte.* $COMOUT
#  cp ensstate.* $COMOUT
  #if [ "$SENDDBN" = 'YES' ]; then
  #  $DBNROOT/bin/dbn_alert EENS GRIB1-Change $job 
  #fi 
#fi
