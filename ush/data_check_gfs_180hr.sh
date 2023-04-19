#!/bin/ksh
export PS4=' + data_check_gfs.sh line $LINENO: '
set -x

####################################
# Specify Timeout Behavior for TC Track calculations
# SLEEP_TIME - Amount of time to wait for a input-data file before exiting
# SLEEP_INT  - Amount of time to wait between checking for input-data file
####################################
export SLEEP_TIME=3600
export SLEEP_INT=60
SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`

if [ ${cmodel} = "gfs" ]; then
#  datdir=${gfsdir}/gfs.${PDY}/${cyc}
  export COMPONENT=${COMPONENT:-atmos}
  datdir=${gfsdir}/gfs.${PDY}/${cyc}/${COMPONENT}
  vit_incr=${FHOUT_CYCLONE:-6}                        
  fcstlen=${FHMAX_CYCLONE:-180}                       
  fcsthrs=$(seq -f%03g -s' ' 0 $vit_incr $fcstlen)    
fi

ic=0
while [ $ic -lt $SLEEP_LOOP_MAX ]; do
  echo "Check for the existence of the files in ${datdir}"

  ic1=0
  for fhour in ${fcsthrs}; do
    datfile=gfs.t${cyc}z.pgrb2.0p25.f${fhour}
    if [ ! -s ${datdir}/${datfile} ]; then
      set +x
      echo " "
      echo "GFS file missing: ${datdir}/${datfile}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo " "
      set -x
      ic1=`expr $ic1 + 1`
    fi
  done

  if [ $ic1 -eq 0 ]; then
    echo " !!!  $ic1 files missing in ${datdir} after waiting $ic minutes"
    break
  else
    sleep $SLEEP_INT
  fi
  ic=`expr $ic + 1`
###############################
# After we wait for 60 minutes, no data is available, Job will be quit. 
###############################
  if [ $ic -eq $SLEEP_LOOP_MAX ]; then
    msg="FATAL ERROR: $ic1 files missing in ${datdir}"
    echo "$msg"; postmsg "$jlogfile" "$msg"
    exit 6
  fi
done
