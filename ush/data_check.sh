#!/bin/ksh
export PS4=' + data_check.sh line $LINENO: '
set -x

####################################
# Specify Timeout Behavior for TC Track calculations
# SLEEP_TIME - Amount of time to wait for a input-data file before exiting
# SLEEP_INT  - Amount of time to wait between checking for input-data file
####################################
export SLEEP_TIME=3600
export SLEEP_INT=60
SLEEP_LOOP_MAX=`expr $SLEEP_TIME / $SLEEP_INT`

if [ ${cmodel} = 'gfs' ]; then
  #datdir=${gfsdir:-${COMROOT}/gfs/prod/gfs.${PDY}}
  datdir=${gfsdir}
  leadhour=240
  datfile=gfs.t${cyc}z.pgrb2.0p25.f${leadhour}       

elif [ ${cmodel} = "ens" ]; then
  #datdir=${ensdir:-${COMROOT}/gens/prod/gefs.${PDY}/$cyc/pgrb2ap5}
  datdir=$ensdira
  leadhour=240
  datfile=gep20.t${cyc}z.pgrb2a.0p50.f${leadhour} 

elif [ ${cmodel} = "cmc" ]; then
  #datdir=${cmcdir:-${DCOMROOT}/us007003/${PDY}/wgrbbul/cmc}
  datdir=$DCOM
  leadhour=240
#  datfile=glb_${cyc}_${leadhour}
  datfile=CMC_glb_latlon.24x.24_${PDY}${cyc}_P${leadhour}_NCEP.grib2

elif [ ${cmodel} = "cens" ]; then
  #datdir=${ccedir:-${COMROOT}/gens/prod/cmce.${PDY}/${cyc}/pgrb2a}
  datdir=$ccedir
  leadhour=240
#  datfile=cmc_gep20.t${cyc}z.pgrb2af${leadhour}
  datfile=${PDY}${cyc}_CMC_naefs_hr_latlon0p5x0p5_P${leadhour}_020.grib2

elif [ ${cmodel} = "ngps" ]; then
  #datdir=${ngpsdir:-${COMROOT}/fnmoc/prod/navgem.${PDY}}
  datdir=$DCOM
  leadhour=180
#  datfile=navgem_${PDY}${cyc}f${leadhour}.grib2
  datfile=US058GMET-OPSbd2.NAVGEM${leadhour}-${PDY}${cyc}-NOAA-halfdeg.gr2

elif [ ${cmodel} = "fens" ]; then
  #datdir=${fensdir:-${DCOMROOT}/us007003/${PDY}/wgrbbul/fnmocens_gb2}
  datdir=$DCOM
  leadhour=240
  datfile=ENSEMBLE.MET.fcst_et020.${leadhour}.${PDY}${cyc}

elif [ ${cmodel} = "ecmwf" ]; then
  #datdir=${ecmwfdir:-${DCOMROOT}/us007003/${PDY}/wgrbbul/ecmwf}
  datdir=$DCOM
  leadhour=240
  immddhh=`echo ${PDY}${cyc}| cut -c5-`
  fmmddhh=` ${NDATE:?} ${leadhour} ${PDY}${cyc} | cut -c5- `
  #datfile=ecens_DCD${immddhh}00${fmmddhh}001 # Original
  if [ ${fmmddhh} -eq ${immddhh} ]; then
    datfile=U1D${immddhh}00${fmmddhh}011
  else
    datfile=U1D${immddhh}00${fmmddhh}001
  fi

elif [ ${cmodel} = "eens" ]; then
  #datdir=${eensdcom:-${DCOMROOT}/us007003/${PDY}/wgrbbul/ecmwf}
  datdir=$DCOM
  mm=` echo ${PDY} | cut -c5-6 `
  dd=` echo ${PDY} | cut -c7-8 `
  imdh=${mm}${dd}${cyc}
  ymdh=${PDY}${cyc}
  leadhour=240
  vymdh=` ${NDATE:?} ${leadhour} ${ymdh}`
  vmdh=`  echo ${vymdh} | cut -c5-10`
  #datfile=ecens_DCE${imdh}00${vmdh}001
  datfile=DCE${imdh}00${vmdh}001

elif [ ${cmodel} = "ukmet" ]; then
  datdir=${ukmetdcom}
  leadhour=144
  datfile=GAB${cyc}PPA.GRB

fi

ic=0
while [ $ic -lt $SLEEP_LOOP_MAX ]; do
  echo "Check for the existence of ${datdir}/${datfile}"
  if [ -s ${datdir}/${datfile} ]; then
    echo " !!! ${datdir}/${datfile} found after waiting $ic minutes"
    break
  else
    sleep $SLEEP_INT
  fi
  ic=`expr $ic + 1`
###############################
# After we wait for 30 minutes, no data is available, Job will be quit. 
###############################
  if [ $ic -eq $SLEEP_LOOP_MAX ]; then
    msg="FATAL ERROR: missing data ${datdir}/${datfile}"
    >&2 echo "$msg"; postmsg "$jlogfile" "$msg"
    if [ "$DCOM_STATUS" = "data of opportunity" ]; then
      mail.py <<ENDMSG
One or more input data files are missing, including
${datdir}/${datfile}

Exiting $0...
ENDMSG
      exit 6
    else
      err_exit "data_check.sh: ${datdir}/${datfile} is missing"
    fi
  fi
done
