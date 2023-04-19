#!/bin/ksh 
set -x

export cmodel=gfs
export loopnum=1
export ymdh=${PDY}${cyc}

#export gfsdir=${COMINgfs}/${cyc}
#export gfsdir=${COMINgfs}

export COMPONENT=${COMPONENT:-atmos}
export gfsdir=${COMINgfs}/${cyc}/${COMPONENT}

export pert="p01"
pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#-----------input data checking -----------------
#${USHens_tracker}/data_check.sh 
${USHens_tracker}/data_check_gfs.sh
## exit code 6 = missing data of opportunity
if [ $? -eq 6 ]; then exit; fi
#------------------------------------------------

outfile=${pertdir}/trkr.${cmodel}.${pert}.${ymdh}.out

if [[ -d /scratch2 ]] ; then
  # We are on NOAA Hera
  machine=hera
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /work ]] ; then
  # We are on MSU Orion 
  machine=orion
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs4/HFIP ]] ; then
  # We are on NOAA Jet
  machine=jet
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs/h1 ]] ; then
  # We are on NOAA WCOSS2
  machine=wcoss2
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}  

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"

fi
export err=$?; err_chk

#if [ "$SENDCOM" = 'YES' ]; then
#  cat ${pertdir}/trak.gfso.atcfunix.${PDY}${cyc} | \
#      sed s:GFSO:AVNO:g \
#    > ${COMOUT}/avn.t${cyc}z.cyclone.trackatcfunix
#fi

#############################################################

