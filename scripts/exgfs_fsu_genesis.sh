#!/bin/ksh 
set -x

export cmodel=gfs
export ymdh=${PDY}${cyc}
#export gfsdir=/gpfs/dell1/nco/ops/com/gfs/prod
export gfsdir=${gfsdir:-/gpfs/dell1/nco/ops/com/gfs/prod}

export pert="p01"
pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#-----------input data checking -----------------
#${USHens_tracker}/data_check.sh 
#${USHens_tracker}/data_check_gfs.sh
${USHens_tracker}/data_check_gfs_180hr.sh
## exit code 6 = missing data of opportunity
if [ $? -eq 6 ]; then exit; fi
#------------------------------------------------

outfile=${pertdir}/fsugenesis.${cmodel}.${pert}.${ymdh}.out

if [[ -d /gpfs/hps && -e /etc/SuSE-release ]] ; then
  # We are on NOAA Luna or Surge
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_fsu.sh ${cmodel} ${ymdh} ${pertdir} ${gfsdir} #2>&1 >${outfile}

elif [[ -L /usrx && "$( readlink /usrx 2> /dev/null )" =~ dell ]] ; then
  # We are on NOAA Mars or Venus
  machine=dell
  ${USHens_tracker}/extrkr_fsu.sh ${cmodel} ${ymdh} ${pertdir} ${gfsdir}  #2>&1 >${outfile}

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"

fi
export err=$?; err_chk

if [ "$SENDCOM" = 'YES' ]; then
  cp -r ${pertdir}/tracker/${cmodel}/* ${COMOUT}
fi
