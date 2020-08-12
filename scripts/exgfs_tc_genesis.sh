#!/bin/ksh
set -x

export cmodel=gfs
#export loopnum=1
#export ymdh=${PDY}${cyc}
#export gfsdir=${COMINgfs}/${cyc}
#export gfsdir=${COMINgfs}
export COMPONENT=${COMPONENT:-atmos}
#export gfsdir=${COMINgfs}/${cyc}/${COMPONENT}
export gfsdir=${gfsdir:-${COMINgfs}/${cyc}/${COMPONENT}}

#-----------input data checking -----------------
${USHens_tracker}/data_check_gfs.sh
# exit code 6 = missing data of opportunity
if [ $? -eq 6 ]; then exit; fi
#------------------------------------------------


#export cmodel=gfs
export loopnum=1
export ymdh=${PDY}${cyc}

#export gfsdir=${COMINgfs}/${cyc}

#---- first run to get GFS genesis vital at time=00 06 12 18Z -----------

#export trkrtype=tcgen
#export trkrebd=350.0
#export trkrwbd=105.0
#export trkrnbd=30.0
#export trkrsbd=5.0
#export mslpthresh=0.0015
#export v850thresh=1.5000
export regtype=altg

export pert=p01
export pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out

if [[ -d /gpfs/hps && -e /etc/SuSE-release ]] ; then
  # We are on NOAA Luna or Surge
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_tcv_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -L /usrx && "$( readlink /usrx 2> /dev/null )" =~ dell ]] ; then
  # We are on NOAA Mars or Venus
  machine=dell
  ${USHens_tracker}/extrkr_tcv_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /scratch2 ]] ; then
  # We are on NOAA Hera
  machine=hera
  ${USHens_tracker}/extrkr_tcv_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /work ]] ; then
  # We are on MSU Orion
  machine=orion
  ${USHens_tracker}/extrkr_tcv_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs3 ]] ; then
  # We are on NOAA Jet
  machine=jet
  ${USHens_tracker}/extrkr_tcv_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"
fi
export err=$?; err_chk

#### NCEP/GFS genesis tcvitals  ###########################
num_gen_vits=`cat ${COMINgenvit}/genesis.vitals.gfs.gfso.${JYYYY} | wc -l`
if [ ${num_gen_vits} -gt 0 ]
then
  . prep_step

  # Input file
  export FORT41=${COMINgenvit}/genesis.vitals.gfs.gfso.${JYYYY}

  # Output files
  export FORT42=gen_tc.vitals.gfs.gfso.${JYYYY}

  ${EXECens_tracker}/tcvital_ch_gfs
  export err=$?; err_chk

  cat $FORT42 >> ${COMOUTgenvit}/all.vitals.gfs.gfso.${JYYYY}
else
  touch ${COMOUTgenvit}/all.vitals.gfs.gfso.${JYYYY}
fi

#---- second run genesis ---------------------------------------
#exit
rm -rf ${DATA}/*
export pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out

if [[ -d /gpfs/hps && -e /etc/SuSE-release ]] ; then
  # We are on NOAA Luna or Surge
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_gen_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -L /usrx && "$( readlink /usrx 2> /dev/null )" =~ dell ]] ; then
  # We are on NOAA Mars or Venus
  machine=dell
  ${APRUNTRACK} ${USHens_tracker}/extrkr_gen_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /scratch2 ]] ; then
  # We are on NOAA Hera
  machine=hera
  ${USHens_tracker}/extrkr_gen_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /work ]] ; then
  # We are on MSU Orion
  machine=orion
  ${USHens_tracker}/extrkr_gen_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs3 ]] ; then
  # We are on NOAA Jet
  machine=jet
  ${USHens_tracker}/extrkr_gen_gfs.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"
fi
export err=$?; err_chk

export atcfout=gfso
export TRKDATA=${DATA}/${cmodel}/${pert}
${USHens_tracker}/sort_tracks.gen.sh  >${TRKDATA}/sort.${regtype}.${atcfout}.${ymdh}.out
export err=$?; err_chk

#cp ${pertdir}/trak.gfso.atcfunix.altg.${ymdh} ${COMOUT}/
#cp ${pertdir}/storms.gfso.atcf_gen.altg.${ymdh}  ${COMOUT}/

#### filtering weak storms for TC genesis #####
. prep_step

# Input file
export FORT41=storms.gfso.atcf_gen.altg.${ymdh}
cpreq ${COMOUT}/$FORT41 .

# Output files
export FORT42=storms.gfso.atcf_gen.${ymdh}
export FORT43=trak.gfso.atcfunix.${ymdh}

${EXECens_tracker}/filter_gen_gfs
export err=$?; err_chk

if [ "$SENDCOM" = YES ]; then
  cp $FORT42 $FORT43 ${COMOUT}/
  if [ $? -ne 0 ]; then
    echo "WARNING: Filtering did not produce any files... perhaps there were no storms to begin with."
  fi
fi
