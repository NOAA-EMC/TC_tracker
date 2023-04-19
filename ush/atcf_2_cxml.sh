#!/bin/ksh
export PS4=' + atcf_2_cxml.sh line $LINENO: '
set -x

########  J.Peng 2013-05-13   ##############################
pmodel=$1
ymdh=$2
COMvit=$3
JPDATA=$4
if [ ! -d ${JPDATA} ]; then mkdir -p ${JPDATA}; fi

JYYYY=`echo ${ymdh} | cut -c1-4`
JMM=`echo ${ymdh} | cut -c5-6`
JDD=`echo ${ymdh} | cut -c7-8`
JCYC=`echo ${ymdh} | cut -c9-10`
 
export JPCXML=${JPDATA}/${JYYYY}${JMM}/${JYYYY}${JMM}${JDD}
if [ ! -d ${JPCXML} ]; then mkdir -p ${JPCXML}; fi

vitalsfile=vitals.upd.gfsx.${ymdh}
cp ${COMvit}/$vitalsfile ${JPDATA}/
#----------------------------------------------------------------------------------------------------
if [ ${pmodel} = 'ens' ]; then
#  export DATAin=/com/gens/prod/gefs.${JYYYY}${JMM}${JDD}/${JCYC}/track
  export DATAin=${COMOUT}
  memblist="c00 p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 \
                p11 p12 p13 p14 p15 p16 p17 p18 p19 p20"
  hurlist="01 02 03 04 05 06 07 08 09 10 \
           11 12 13 14 15 16 17 18 19 20 \
           21 22 23 24 25 26 27 28 29 30 \
	       31 32 33 34 35 36 37 38 39 40 \
           90 91 92 93 94 95 96 97 98 99"
  basinlist="AL EP WP CP SC EC AU SP SI BB AA"

  cd ${JPDATA}

  if [ -s $vitalsfile ]; then
    for memb in $memblist; do
      cp ${DATAin}/a${memb}.t${JCYC}z.cyclone.trackatcfunix trak.a${memb}.atcfunix.${ymdh}

      for basin in $basinlist; do
      for hur in $hurlist; do
        grep "${basin}, ${hur}" trak.a${memb}.atcfunix.${ymdh} | grep "XX,  34, NEQ" > a${memb}.${basin}${hur}.${ymdh}
      done
      done
      cat a${memb}.*.${ymdh} > trak.a${memb}.atcfunix.glob.${ymdh}
      rm -f a${memb}.*.${ymdh}

      . prep_step

      # Input file
      export FORT11=trak.a${memb}.atcfunix.glob.${ymdh}
      export FORT31=$vitalsfile

      # Output file
      export FORT66=trak.a${memb}.atcf_gen.glob.${ymdh}

      ${EXECens_tracker}/track_convert
      export err=$?; err_chk

      mv $FORT66 ${JPCXML}
    done
  else
    echo "WARNING: $vitalsfile not found... perhaps due to lack of storms."
  fi

  ${USHens_tracker}/atcf2xml.pl --date ${ymdh} --model GEFS --basin glob --atcf_dir ${JPDATA} --cxml_dir ${JPDATA}
  export err=$?; err_chk

  cp ${JPCXML}/kwbc_${ymdh}0000_GEFS_glob_prod_esttr_glo.xml ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]; then
     $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/kwbc_${ymdh}0000_GEFS_glob_prod_esttr_glo.xml
  fi

#  rm -rf ${JPDATA}/*

#----------------------------------------------------------------------------------------------------
elif [ ${pmodel} = 'gfs' ]; then
  export DATAin=${COMOUT}
  memblist="gfsx"
  hurlist="01 02 03 04 05 06 07 08 09 10 \
           11 12 13 14 15 16 17 18 19 20 \
           21 22 23 24 25 26 27 28 29 30 \
           31 32 33 34 35 36 37 38 39 40 \
           90 91 92 93 94 95 96 97 98 99"
  basinlist="AL EP WP CP SC EC AU SP SI BB AA"

  cd ${JPDATA}

  if [ -s $vitalsfile ]; then
    for memb in $memblist; do
      cp ${DATAin}/gfsx.t${cyc}z.cyclone.trackatcfunix trak.${memb}.atcfunix.${ymdh}

      for basin in $basinlist; do
      for hur in $hurlist; do
        grep "${basin}, ${hur}" trak.${memb}.atcfunix.${ymdh} | grep "XX,  34, NEQ" > ${memb}.${basin}${hur}.${ymdh}
      done
      done
      cat ${memb}.*.${ymdh} > trak.${memb}.atcfunix.glob.${ymdh}
      rm -f ${memb}.*.${ymdh}

      . prep_step

      # Input files
      export FORT11=trak.${memb}.atcfunix.glob.${ymdh}
      export FORT31=$vitalsfile

      # Output file
      export FORT66=trak.${memb}.atcf_gen.glob.${ymdh}

      ${EXECens_tracker}/track_convert
      export err=$?; err_chk
      mv $FORT66 ${JPCXML}
    done
  else
    echo "WARNING: $vitalsfile not found... perhaps due to lack of storms."
  fi

  ${USHens_tracker}/atcf2xml.pl --date ${ymdh} --model GFS --basin glob --atcf_dir ${JPDATA} --cxml_dir ${JPDATA}
  export err=$?; err_chk

  cp ${JPCXML}/kwbc_${ymdh}0000_GFS_glob_prod_sttr_glo.xml ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]; then
    $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/kwbc_${ymdh}0000_GFS_glob_prod_sttr_glo.xml
  fi

#  rm -rf ${JPDATA}/*

#----------------------------------------------------------------------------------------------------
elif [ ${pmodel} = 'cens' ]; then
#  export DATAin=/com/gens/prod/cmce.${JYYYY}${JMM}${JDD}/${JCYC}/track
  export DATAin=${COMOUT}
  memblist="c00 p01 p02 p03 p04 p05 p06 p07 p08 p09 p10 \
                p11 p12 p13 p14 p15 p16 p17 p18 p19 p20"
  hurlist="01 02 03 04 05 06 07 08 09 10 \
           11 12 13 14 15 16 17 18 19 20 \
           21 22 23 24 25 26 27 28 29 30 \
           31 32 33 34 35 36 37 38 39 40 \
           90 91 92 93 94 95 96 97 98 99"
  basinlist="AL EP WP CP SC EC AU SP SI BB AA"

  cd ${JPDATA}

  if [ -s $vitalsfile ]; then
    for memb in $memblist; do
      cp ${DATAin}/c${memb}.t${JCYC}z.cyclone.trackatcfunix trak.c${memb}.atcfunix.${ymdh}

      for basin in $basinlist; do
      for hur in $hurlist; do
        grep "${basin}, ${hur}" trak.c${memb}.atcfunix.${ymdh} | grep "XX,  34, NEQ" > c${memb}.${basin}${hur}.${ymdh}
      done
      done
      cat c${memb}.*.${ymdh} > trak.c${memb}.atcfunix.glob.${ymdh}
      rm -f c${memb}.*.${ymdh}

      . prep_step

      # Input files
      export FORT11=trak.c${memb}.atcfunix.glob.${ymdh}
      export FORT31=$vitalsfile

      # Output file
      export FORT66=trak.c${memb}.atcf_gen.glob.${ymdh}

      ${EXECens_tracker}/track_convert
      export err=$?; err_chk

      mv $FORT66 ${JPCXML}
    done
  else
    echo "WARNING: $vitalsfile not found... perhaps due to lack of storms."
  fi

  ${USHens_tracker}/atcf2xml.pl --date ${ymdh} --model CENS --basin glob --atcf_dir ${JPDATA} --cxml_dir ${JPDATA}
  export err=$?; err_chk

  cp ${JPCXML}/kwbc_${ymdh}0000_CENS_glob_prod_esttr_glo.xml ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]; then
    $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/kwbc_${ymdh}0000_CENS_glob_prod_esttr_glo.xml  
  fi

#  rm -rf ${JPDATA}/*

#----------------------------------------------------------------------------------------------------
elif [ ${pmodel} = 'cmc' ]; then
  export DATAin=${COMOUT}
  memblist="cmc"
  hurlist="01 02 03 04 05 06 07 08 09 10 \
           11 12 13 14 15 16 17 18 19 20 \
           21 22 23 24 25 26 27 28 29 30 \
           31 32 33 34 35 36 37 38 39 40 \
           90 91 92 93 94 95 96 97 98 99"
  basinlist="AL EP WP CP SC EC AU SP SI BB AA"

  cd ${JPDATA}

  if [ -s $vitalsfile ]; then
    for memb in $memblist; do
      cp ${DATAin}/${memb}.t${JCYC}z.cyclone.trackatcfunix trak.${memb}.atcfunix.${ymdh}

      for basin in $basinlist; do
      for hur in $hurlist; do
        grep "${basin}, ${hur}" trak.${memb}.atcfunix.${ymdh} | grep "XX,  34, NEQ" > ${memb}.${basin}${hur}.${ymdh}
      done
      done
      cat ${memb}.*.${ymdh} > trak.${memb}.atcfunix.glob.${ymdh}
      rm -f ${memb}.*.${ymdh}

      . prep_step

      # Input files
      export FORT11=trak.${memb}.atcfunix.glob.${ymdh}
      export FORT31=$vitalsfile

      # Output file
      export FORT66=trak.${memb}.atcf_gen.glob.${ymdh}

      ${EXECens_tracker}/track_convert
      export err=$?; err_chk

      mv $FORT66 ${JPCXML}
    done
  else
    echo "WARNING: $vitalsfile not found... perhaps due to lack of storms."
  fi
 

  ${USHens_tracker}/atcf2xml.pl --date ${ymdh} --model CMC --basin glob --atcf_dir ${JPDATA} --cxml_dir ${JPDATA}
  export err=$?; err_chk

  cp ${JPCXML}/kwbc_${ymdh}0000_CMC_glob_prod_sttr_glo.xml ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]; then
    $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/kwbc_${ymdh}0000_CMC_glob_prod_sttr_glo.xml
  fi

#  rm -rf ${JPDATA}/*

fi
