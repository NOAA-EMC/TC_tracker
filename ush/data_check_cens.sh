#!/bin/ksh
export PS4=' + data_check_cens.sh line $LINENO: '
set -x

#export DCOMROOT=/dcom
#export PDY=20180601
#export cyc=00
#export cmodel=cens

####################################
# Specify Timeout Behavior for TC Track calculations
# SLEEP_TIME - Amount of time to wait for a input-data file before exiting
# SLEEP_INT  - Amount of time to wait between checking for input-data file
####################################
export SLEEP_TIME=3600
export SLEEP_INT=60
SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`

if [ ${cmodel} = "cens" ]; then
#  datdir=${ccedir:-${DCOMROOT:?}/us007003/${PDY}/wgrbbul/cmcens_gb2}
#  leadhour=${FHMAX_CYCLONE:-240}
#  datfile=${PDY}${cyc}_CMC_naefs_hr_latlon0p5x0p5_P${leadhour}_020.grib2
#  datdir=/gpfs/dell2/ptmp/Jiayi.Peng/cens_data
  datdir=${ccedir:-${DCOMROOT:?}/us007003/${PDY}/wgrbbul/cmcens_gb2}

  vit_incr=${FHOUT_CYCLONE:-6}                        
  fcstlen=${FHMAX_CYCLONE:-240}                       
  fcsthrs=$(seq -f%03g -s' ' 0 $vit_incr $fcstlen)    

  mem_incr=1
  memlen=20
  member=$(seq -f%02g -s' ' 0 $mem_incr $memlen)
fi

ic=0
while [ $ic -lt $SLEEP_LOOP_MAX ]; do
  echo "Check for the existence of the files in ${datdir}"

  ic1=0
  for fhour in ${fcsthrs}; do
  for pert_num in ${member}; do

    datfile=${PDY}${cyc}_CMC_naefs_hr_latlon0p5x0p5_P${fhour}_0${pert_num}.grib2
    if [ ! -s ${datdir}/${datfile} ]; then
      set +x
      echo " "
      echo "CANADIAN ENSEMBLE file missing: ${datdir}/${datfile}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo " "
      set -x
      ic1=`expr $ic1 + 1`
    fi

  done
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
    >&2 echo "$msg"; postmsg "$jlogfile" "$msg"
    if [ "$DCOM_STATUS" = "data of opportunity" ]; then
      mail.py <<ENDMSG
      $ic1 input data files are missing, including in ${datdir}
Exiting $0...
ENDMSG
      exit 6
    else
      err_exit "data_check_cens.sh: the files in ${datdir} are missing"
    fi
  fi
done
