#!/bin/ksh
export PS4=' + ens_trak_ave_2d.sh line $LINENO: '

set +x
##############################################################################
echo " "
echo "-----------------------------------------------------"
echo " +++ - Compute ensemble mean cyclone forecast track"
echo "-----------------------------------------------------"
echo "History: Jul 2005 - Marchok - First implementation of this new script."
echo " "
echo "                    In the event of a crash, you can contact Tim "
echo "                    Marchok at GFDL at (609) 452-6534 or "
echo "                    via email at timothy.marchok@noaa.gov"
echo " "
echo " "
echo "Current time is: `date`"
echo " "
##############################################################################
set -x

########################################
msg="has begun for ${cmodel} at ${cyc}z"
postmsg "$jlogfile" "$msg"
########################################

# This script computes ensemble mean cyclone tracks.  It dumps all
# the cyclone tracks for a given ensemble forecast into one file,
# then runs a fortran program to compute the ensemble mean, spread
# and mode.  In addition, strike probabilities are produced for
# any storms in the Atlantic, EastPac and WestPac basins. 
#
# Environmental variable inputs needed for this scripts:
#  PDY   -- The date for data being processed, in YYYYMMDD format
#  cycle -- The cycle for data being processed (t00z, t06z, t12z, t18z)
#  cmodel -- Model being processed: ens (ncep ensemble), cens (CMC ensemble),
#                                   ece (ECMWF ensemble).
#  envir -- 'prod' or 'test'
#  SENDCOM -- 'YES' or 'NO'
#
# For testing script interactively in non-production, set following vars:
#
#-------J.Peng---2010-09-27-------------------------
#export PDY=$1
#export cyc=$2
#export cmodel=$3
#export DATA=$4

export jlogfile=${DATA}/log_file_mean
export pgmout=${DATA}/pgm_out_mean

ymdh=${PDY}${cyc}

if [ ! -d $DATA ]
then
   mkdir -p $DATA
fi
cd $DATA

case ${cmodel} in

   ens) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ NCEP ensemble tracks will be averaged...."   ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="AEMN"                                          ;
        amodel="aemn"                                          ;
        achar="a"                                              ;;

   fens) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ FNMOC ensemble tracks will be averaged...."  ;
        echo " "                                               ;
        set -x                                                 ;
#        AMODEL="FEMN"                                          ;
#        amodel="femn"                                          ;
#        achar="f"                                              ;;
        AMODEL="NEMN"                                          ;
        amodel="nemn"                                          ;
        achar="n"                                              ;;

  cens) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ CMC ensemble tracks will be averaged...."    ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="CEMN"                                          ;
        amodel="cemn"                                          ;
        achar="c"                                              ;;

  ukes) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ UKMET ensemble tracks will be averaged...."  ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="UKMN"                                          ;
        amodel="ukmn"                                          ;
        achar="u"                                              ;;

   eens) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF ensemble tracks will be averaged...."  ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="EEMN"                                          ;
        amodel="eemn"                                          ;
        achar="e"                                              ;;

   g2c) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ NCEP+CMC ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="2EMN"                                          ;
        amodel="2emn"                                          ;
        achar="A"                                              ;;

   gce4) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF+NCEP+CMC+FNMOC ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="4EMN"                                          ;
        amodel="4emn"                                          ;
        achar="A"                                              ;;

   gce5) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF+NCEP+CMC+FNMOC+UK ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="5EMN"                                          ;
        amodel="5emn"                                          ;
        achar="A"                                              ;;

   neu3) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF+NCEP+UK ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="3NEU"                                          ;
        amodel="3neu"                                          ;
        achar="A"                                              ;;

   ncf3) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ NCEP+CMC+FNMOC ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="3NCF"                                          ;
        amodel="3ncf"                                          ;
        achar="A"                                              ;;

   gce3) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF+NCEP+CMC ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="3EMN"                                          ;
        amodel="3emn"                                          ;
        achar="A"                                              ;;

   nae2) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF+NCEP ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="2NAE"                                          ;
        amodel="2nae"                                          ;
        achar="A"                                              ;;

   gce3a) set +x                                               ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ eemn+2EMN ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="SEMN"                                          ;
        amodel="semn"                                          ;
        achar="A"                                              ;;

   gce3b) set +x                                               ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ eemn+cemn+aemn ensemble tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="PEMN"                                          ;
        amodel="pemn"                                          ;
        achar="A"                                              ;;

   sing) set +x                                                ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ AVNO+EMX+CMC tracks will be averaged...."    ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="3DET"                                          ;
        amodel="3det"                                          ;
        achar="A"                                              ;;

  tot6) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ AVNO+EMX+CMC+AEMN+CEMN+EEMN tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="6EMN"                                          ;
        amodel="6emn"                                          ;
        achar="A"                                              ;;

  totw) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ AVNO+EMX+CMC+AEMN+CEMN+EEMN tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="6EMW"                                          ;
        amodel="6emw"                                          ;
        achar="A"                                              ;;

  tot4) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ AVNO+EMX+CMC+3EMN tracks will be averaged....";
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="T4MN"                                          ;
        amodel="t4mn"                                          ;
        achar="A"                                              ;;

  tot2) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ 3EMN+3DET tracks will be averaged...."       ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="S6MN"                                          ;
        amodel="s6mn"                                          ;
        achar="A"                                              ;;

  sref) set +x                                                 ;
        echo " "                                               ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ SREF ensemble tracks will be averaged...."   ;
        echo " "                                               ;
        set -x                                                 ;
        AMODEL="SFMN"                                          ;
        amodel="sfmn"                                          ;
        achar="s"                                              ;;

     *) set +x                                                 ;
        echo " "                                               ;
        echo "FATAL ERROR: INPUT CMODEL PARAMETER IS NOT RECOGNIZED.";
        echo " !! Input cmodel parameter = ${cmodel}...."      ;
        echo " "                                               ;
        set -x                                                 ;
        err_exit "FAILED ${jobid} -- UNKNOWN cmodel IN TRACK-AVERAGING SCRIPT - ABNORMAL EXIT";;

esac

#---------------------------------------------------
# Run the program that calculates the ensemble mean
# track and generates the probability files....
#---------------------------------------------------

echo "TIMING: Time before any of the track-averaging stuff is `date`"

>trak.allperts.atcfunix.${amodel}.${ymdh}

# for tfile in `ls -1 ${COMOUT}/${achar}[np]*.t${cyc}z.cyclone.trackatcfunix`
#------J.Peng----2010-10-28-----------------------
#for tfile in `ls -1 ${COMOUT}/${achar}[np]*.t${cyc}z.cyclone.trackatcfunix`
#for tfile in `ls -1 ${COMOUT}/trak.${achar}P??.atcfunix.${PDY}${cyc}`

#----J.Peng-----2010-10-29----and 2010-11-02 ---------------------
if [ ${cmodel} = "g2c" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done
elif [ ${cmodel} = "gce4" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "gce5" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "neu3" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "ncf3" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "gce3a" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "gce3b" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "sing" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done
elif [ ${cmodel} = "tot6" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "totw" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "tot4" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "tot2" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "fens" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "fenb" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "ensb" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "cenb" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "eens" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done
elif [ ${cmodel} = "ens" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done
elif [ ${cmodel} = "cens" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "ukes" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.uk[012]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "sref" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[aenr]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "gce3" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.[ace][np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

elif [ ${cmodel} = "nae2" ]; then
  for tfile in `ls -1 ${COMOUT}/trak.[ae][np]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done

else
  for tfile in `ls -1 ${COMOUT}/trak.${achar}[NP]*.atcfunix.${PDY}${cyc}`
  do
    cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
  done
fi

####J.Peng 2012-02-28 filtering weak storms for TC genesis #####
#### Vmax>=19kts  SLP<=1010mb ####################################
#  ln -s -f ${DATA}/trak.allperts.atcfunix.${amodel}.${ymdh}     fort.41
#  ln -s -f ${DATA}/trak.allperts.atcfunix.${amodel}.${ymdh}.tcgen fort.42
#/ensemble/save/Jiayi.Peng/huprob/ens_trak_ave.fd/filter/filter

numrecs=` cat trak.allperts.atcfunix.${amodel}.${ymdh} | wc -l`
if [ ${numrecs} -eq 0 ]; then
  msg="No member tracks exist for ${ymdh}"
  echo "WARNING:  $msg"
  postmsg $jlogfile "$msg"
  exit 0
fi

for dt in 65
do

  set +x
  echo "TIMING: Time just before call to trakave for dt= $dt is `date`"
  set -x
  export pgm=ens_trak_ave_2d

  . prep_step

  # Input file
  export FORT11=${DATA}/trak.allperts.atcfunix.${amodel}.${ymdh}
  #ln -s -f ${DATA}/trak.allperts.atcfunix.${amodel}.${ymdh}.tcgen fort.11

  # Output files
  export FORT51=${DATA}/${amodel}.trkprob.${ymdh}.${dt}.ctlinfo.txt
  # Unit 52: Created internally, may be 1 to 15 files...
  export FORT53=${DATA}/trak.${amodel}.atcfunix.${ymdh}
  export FORT54=${DATA}/trak.${amodel}.atcf.${ymdh}
  export FORT55=${DATA}/trak.${amodel}.all.${ymdh}
  export FORT56=${DATA}/trak.${amodel}.spread.${ymdh}
  export FORT57=${DATA}/trak.${amodel}.mode.${ymdh}

#----J.Peng----2011-03-01-------------------------------------------
  #export FORT92=/hfip/noscrub/Jiayi.Peng/2010/super_new/weight/weight.dat

  namelist=${DATA}/input.${ymdh}.nlist
  echo "&datain dthresh=${dt}.0,cmodel='${cmodel}'/" >${namelist}

  ${EXECens_tracker}/ens_trak_ave_2d <${namelist} >${DATA}/ens_trak_ave_2d.${ymdh}.${dt}.fout
  ens_trak_ave_rcc=$?

  if [ ${ens_trak_ave_rcc} -ne 0 ]
  then
    set +x
    echo " "
    echo "FATAL ERROR:  An error occurred while running ens_trak_ave.x,"
    echo "!!! which is the program that computes the mean track."
    echo "!!! Return code from ens_trak_ave.x = ${ens_trak_ave_rcc}"
    echo "!!! model= ${amodel}, forecast initial time = ${PDY}${cyc}"
    echo " "
    set -x
    err_exit "FAILED ${jobid} - ERROR RUNNING ens_trak_ave_2d - ABNORMAL EXIT"
  fi

  set +x
  echo "TIMING: Time just after call to trakave for dt= $dt is `date`"
  set -x

done

set +x
echo "TIMING: Time after loop to get mean & probabilities for $ymdh is `date`"
set -x

#-----------------------------------------------------
# Parse out the atcfunix records and send them to the
# correct tpcprd directory and file.

if [ "$SENDCOM" = 'YES' ]; then

  cp ${DATA}/trak.${amodel}.* ${COMOUT}/
  ls ${DATA}/${amodel}.trkprob.* 1>/dev/null
  if [ $? -eq 0 ]; then
    cp ${DATA}/${amodel}.trkprob.* ${COMOUT}/
  fi

  #if [ "$SENDDBN" = 'YES' ]; then
  #  if [ $cmodel != 'eens' ]; then
  #    $DBNROOT/bin/dbn_alert MODEL ENS_GENESIS $job ${COMOUT}/trak.${amodel}.atcfunix.${ymdh}
  #  fi
  #fi  

fi
