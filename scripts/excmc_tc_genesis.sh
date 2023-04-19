#!/bin/ksh
set -x

export cmodel=cmc
export loopnum=1
export ymdh=${PDY}${cyc}

# export cmcdir=${DCOM}

#---- first run to get GFS genesis vital at time=00 06 12 18Z -----------

export trkrtype=tcgen
export trkrebd=350.0
export trkrwbd=105.0
export trkrnbd=30.0
export trkrsbd=5.0
export mslpthresh=0.0015
export v850thresh=1.5000
export regtype=altg

export pert=p01
export pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out
#${USHens_tracker}/extrkr_tcv_g1.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  ${USHens_tracker}/extrkr_tcv_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_tcv_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
fi
export err=$?; err_chk

####J.Peng 2012-05-03 CMC genesis tcvitals  ###########################
num_gen_vits=`cat ${COMINgenvit}/genesis.vitals.cmc.cmc.${JYYYY} | wc -l`
if [ ${num_gen_vits} -gt 0 ]
then
  . prep_step

  # Input file
  export FORT41=${COMINgenvit}/genesis.vitals.cmc.cmc.${JYYYY}

  # Output file
  export FORT42=gen_tc.vitals.cmc.cmc.${JYYYY}

  ${EXECens_tracker}/tcvital_ch_cmc
  export err=$?; err_chk

  cat gen_tc.vitals.cmc.cmc.${JYYYY} >> ${COMOUTgenvit}/all.vitals.cmc.cmc.${JYYYY}
else
  touch ${COMOUTgenvit}/all.vitals.cmc.cmc.${JYYYY}
fi

#---- second run genesis ---------------------------------------

export pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out
#${USHens_tracker}/extrkr_gen_g1.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  ${USHens_tracker}/extrkr_gen_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_gen_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
fi
export err=$?; err_chk

export atcfout=cmc
export TRKDATA=${DATA}/${cmodel}/${pert}
${USHens_tracker}/sort_tracks.gen.sh  >${TRKDATA}/sort.${regtype}.${atcfout}.${ymdh}.out
export err=$?; err_chk

#cp ${pertdir}/trak.cmc.atcfunix.altg.${ymdh} ${COMOUT}/
#cp ${pertdir}/storms.cmc.atcf_gen.altg.${ymdh}  ${COMOUT}/

####J.Peng 2012-05-24 filtering weak storms for TC genesis #####
. prep_step

# Input file
export FORT41=storms.cmc.atcf_gen.altg.${ymdh}
cpreq ${COMOUT}/$FORT41 .

# Output files
export FORT42=storms.cmc.atcf_gen.${ymdh}
export FORT43=trak.cmc.atcfunix.${ymdh}

${EXECens_tracker}/filter_gen_cmc
export err=$?; err_chk

if [ "$SENDCOM" = YES ]; then
  cp $FORT42 $FORT43 ${COMOUT}/
  if [ $? -ne 0 ]; then
    echo "WARNING: Filtering did not produce any files... perhaps there were no storms to begin with."
  fi
fi
