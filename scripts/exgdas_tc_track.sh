#!/bin/bash 
set -x

export cmodel=gdas
export loopnum=1
export ymdh=${PDY}${cyc}

#export gdasdir=${COMINgdas}/${cyc}
#export gdasdir=${COMINgdas}
export COMPONENT=${COMPONENT:-atmos}
export gdasdir=${COMINgdas}/${cyc}/${COMPONENT}

export pert="p01"
pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#-----------input data checking -----------------
${USHens_tracker}/data_check_gdas.sh 
# exit code 6 = missing data of opportunity
if [ $? -eq 6 ]; then exit; fi
#------------------------------------------------

#outfile=${pertdir}/trkr.${cmodel}.${pert}.${ymdh}.out

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
  # We are on NOAA wcoss2
  machine=wcoss2
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}  

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"

fi
export err=$?; err_chk
