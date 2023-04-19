#!/bin/ksh
set -x

export cmodel=fens
export loopnum=1
export ymdh=${PDY}${cyc}

export fensdir=${DCOM}

export trkrtype=tcgen
export trkrebd=350.0
export trkrwbd=105.0
export trkrnbd=30.0
export trkrsbd=5.0
export mslpthresh=0.0015
export v850thresh=1.5000
export regtype=altg

mkdir ${DATA}/${cmodel}
cd ${DATA}/${cmodel}

pertstring=' c00 p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 p11 p12 p13 p14 p15 p16 p17 p18 p19 p20'
>trkr.cmdfile
for pert in ${pertstring}; do
  export pertdir=${DATA}/${cmodel}/${pert}
  mkdir -p $pertdir

  outfile=${pertdir}/trkr.${regtype}.${cmodel}.${pert}.${ymdh}.out
  echo "${USHens_tracker}/extrkr_gen_g2.sh ${loopnum} ${cmodel} ${pert} ${pertdir} &>${outfile}" >>trkr.cmdfile
done

chmod u+x trkr.cmdfile
export MP_PGMMODEL=mpmd
export MP_CMDFILE=${DATA}/${cmodel}/trkr.cmdfile

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  mpirun.lsf
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} cfp ${MP_CMDFILE}
fi

#-------------------------------------------------------
for pert in ${pertstring}; do
  export atcfout="n${pert}"
  export TRKDATA=${DATA}/${cmodel}/${pert}
  ${USHens_tracker}/sort_tracks.gen.sh  >${TRKDATA}/sort.${regtype}.${atcfout}.${ymdh}.out
  export err=$?; err_chk

#  cp ${TRKDATA}/trak.f*.atcfunix.altg.${ymdh} ${COMOUT}/
#  cp ${TRKDATA}/storms.f*.atcf_gen.altg.${ymdh} ${COMOUT}/
done

cd ${DATA}
#rm -rf ${DATA}/${cmodel}
if [ -s "missing_fens.txt" ]; then
   mail.py -s "Missing FNMOC data in $job" --html <<ENDMSG
One or more Fleet Numerical Meteorology and Oceanography Center files are missing, including
<ul>
$(sort -u missing_fens.txt | awk '$0="<li>"$0"</li>"')
</ul>

$0 could not process all expected data.
ENDMSG
fi

#---filtering weak storms -----------------------------
for pert in ${pertstring}; do
  . prep_step

  # Input file
  export FORT41=storms.n${pert}.atcf_gen.altg.${ymdh}
  cpreq ${COMOUT}/$FORT41 .

  # Output files
  export FORT42=storms.n${pert}.atcf_gen.${ymdh}
  export FORT43=trak.n${pert}.atcfunix.${ymdh}
  
  ${EXECens_tracker}/filter_gen_navgem
  export err=$?; err_chk

  if [ "$SENDCOM" = YES ]; then
    cp $FORT42 $FORT43 ${COMOUT}/
  fi
done

##### ensemble mean calculation and plot probability ##########
${USHens_tracker}/ens_trak_ave_2d.sh 
export err=$?; err_chk

#cp ${DATA}/trak.femn.* ${COMOUT}/
#cp ${DATA}/femn.trkprob.* ${COMOUT}/

hurrlist="AL90 AL91 AL92 AL93 AL94 AL95 AL96 AL97 AL98 AL99 \
          EP90 EP91 EP92 EP93 EP94 EP95 EP96 EP97 EP98 EP99 \
          WP90 WP91 WP92 WP93 WP94 WP95 WP96 WP97 WP98 WP99 \
          HC01 HC02 HC03 HC04 HC05 HC06 HC07 HC08 HC09 HC10"
namelist=input.${ymdh}.nlist
namelist1=input.${ymdh}.nlist1

for hurr in $hurrlist; do
  if [ -s ${COMOUT}/nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.ieee ]; then
    cpreq ${COMOUT}/nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.ieee .
    cpreq ${COMOUT}/trak.nemn.atcfunix.${ymdh} .
    pert_basin=`    echo "${hurr}" | cut -c1-2`
    pert_num=`    echo "${hurr}" | cut -c3-4`
    grep "${pert_basin}, ${pert_num}" trak.nemn.atcfunix.${ymdh} > trak.nemn.atcfunix.${ymdh}.${hurr}

    . prep_step
    echo "&datain0 kymdh0='nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.ieee'/" >${namelist}
    echo "&datain1 kymdh1='nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.data'/" >>${namelist}
    ${EXECens_tracker}/readprob <${namelist}
    export err=$?; err_chk

    echo "&datain0 kymdh0='nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.ieee'/" >${namelist1}
    echo "&datain1 kymdh1='nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.gene'/" >>${namelist1}
    echo "&datain2 kymdh2='trak.nemn.atcfunix.${ymdh}.${hurr}'/" >>${namelist1}
    ${EXECens_tracker}/readprobLL <${namelist1}
    export err=$?; err_chk

    if [ "$SENDCOM" = YES ]; then
      cp nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.data ${COMOUT}/
      cp nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.gene ${COMOUT}/

      if [ "$SENDDBN" = 'YES' ]; then
        # JY $DBNROOT/bin/dbn_alert MODEL ENS_GENESIS $job ${COMOUT}/nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.data
        $DBNROOT/bin/dbn_alert MODEL ENS_GENESIS $job ${COMOUT}/nemn.trkprob.${hurr}.65nm.${ymdh}.indiv.gene
      fi
    fi
    rm $namelist $namelist1
  fi
done

