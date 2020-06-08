#!/bin/ksh
set -x

export cmodel=ngps
export loopnum=1
export ymdh=${PDY}${cyc}

#export ngpsdir=${DCOM}

#---- first run to get NAVGEM genesis vital at time=00 06 12 18Z -----------

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

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  ${USHens_tracker}/extrkr_tcv_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_tcv_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
fi
export err=$?; err_chk

#### NAVGEM genesis tcvitals  ###########################
num_gen_vits=`cat ${COMINgenvit}/genesis.vitals.ngps.ngx.${JYYYY} | wc -l`
if [ ${num_gen_vits} -gt 0 ]
then
  . prep_step

  # Input file
  export FORT41=${COMINgenvit}/genesis.vitals.ngps.ngx.${JYYYY}

  # Output file
  export FORT42=gen_tc.vitals.ngps.ngx.${JYYYY}

  ${EXECens_tracker}/tcvital_ch_navgem
  export err=$?; err_chk

  cat $FORT42 >> ${COMOUTgenvit}/all.vitals.ngps.ngx.${JYYYY}
else
  touch ${COMOUTgenvit}/all.vitals.ngps.ngx.${JYYYY}
fi

#---- second run genesis ---------------------------------------

export pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  ${USHens_tracker}/extrkr_gen_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} ${USHens_tracker}/extrkr_gen_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} #2>&1 >${outfile}
fi
export err=$?; err_chk

export atcfout=ngx
export TRKDATA=${DATA}/${cmodel}/${pert}
${USHens_tracker}/sort_tracks.gen.sh  >${TRKDATA}/sort.${regtype}.${atcfout}.${ymdh}.out
export err=$?; err_chk

if [ -s "missing_ngps.txt" ]; then
   mail.py -s "Missing NAVGEM data in $job" --html <<ENDMSG
One or more Navy Global Environmental Model files are missing, including
<ul>
$(sort -u missing_ngps.txt | awk '$0="<li>"$0"</li>"')
</ul>

$0 could not process all expected data.
ENDMSG
fi

#cp ${pertdir}/trak.ngx.atcfunix.altg.${ymdh} ${COMOUT}/
#cp ${pertdir}/storms.ngx.atcf_gen.altg.${ymdh}  ${COMOUT}/

####filtering weak storms for TC genesis #####

. prep_step

# Input file
export FORT41=storms.ngx.atcf_gen.altg.${ymdh}
cpreq ${COMOUT}/$FORT41 .

# Output files
export FORT42=storms.ngx.atcf_gen.${ymdh}
export FORT43=trak.ngx.atcfunix.${ymdh}

${EXECens_tracker}/filter_gen_navgem
export err=$?; err_chk

if [ "$SENDCOM" = YES ]; then
  cp $FORT42 $FORT43 ${COMOUT}/
  if [ $? -ne 0 ]; then
    echo "WARNING: Filtering did not produce any files... perhaps there were no storms to begin with."
  fi
fi
