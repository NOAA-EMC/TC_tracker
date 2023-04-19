#!/bin/ksh
export PS4=' + ens_trak_ave.sh line $LINENO: '

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
#     gltrkdir   - Directory for output tracks
#

yy=`echo ${PDY} | cut -c3-4`
syyyy=`echo ${PDY} | cut -c1-4`
ymdh=${PDY}${cyc}

#export COMOUTatcf=${COMOUTatcf:-${COMROOT}/nhc/${envir}/atcf}
#export gltrkdir=${gltrkdir:-${COMROOT}/hur/${envir}/global}
gltrkdir=${gltrkdir:-${COMOUThur:?}}

cd $DATA

case ${cmodel} in

   ens) set +x; echo " "                                       ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ NCEP ensemble tracks will be averaged...."   ;
        echo " "; set -x                                       ;
        AMODEL="AEMN"                                          ;
        amodel="aemn"                                          ;
        achar="a"                                              ;;
        #COMOUT=${COM:-${COMROOT}/gens/${envir}/gefs.${PDY}/${cyc}/track}
 
   eens) set +x; echo " "                                      ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ ECMWF ensemble tracks will be averaged...."  ;
        echo " "; set -x                                       ;
        AMODEL="EEMN"                                          ;
        amodel="eemn"                                          ;
        achar="e"                                              ;;
        #COMOUT=${COM:-${COMROOT}/gens/${envir}/ecme.${PDY}/${cyc}/track}
 
  cens) set +x; echo " "                                       ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ CMC ensemble tracks will be averaged...."    ;
        echo " "; set -x                                       ;
        AMODEL="CEMN"                                          ;
        amodel="cemn"                                          ;
        achar="c"                                              ;;
        #COMOUT=${COM:-${COMROOT}/gens/prod/cmce.${PDY}/${cyc}/track}

  fens) set +x; echo " "                                       ;
	    echo " ++ Input cmodel parameter = ${cmodel}...."      ;
	    echo " ++ FNMOC ensemble tracks will be averaged...."  ;
        echo " "; set -x                                       ;
#           AMODEL="FEMN"                                          ;
#	    amodel="femn"                                          ;
#           achar="f"                                              ;;
            AMODEL="NEMN"                                          ;
            amodel="nemn"                                          ;
            achar="n"                                              ;;
	    #COMOUT=${COM:-${COMROOT}/gens/prod/fens.${PDY}/${cyc}/track}

  sref) set +x; echo " "                                       ;
        echo " ++ Input cmodel parameter = ${cmodel}...."      ;
        echo " ++ SREF ensemble tracks will be averaged...."   ;
        echo " "; set -x                                       ;
        AMODEL="SRMN"                                          ;
        amodel="srmn"                                          ;
        achar="s"                                              ;;
        #COMOUT=${COM:-${COMROOT}/sref/${envir}/sref.${PDY}/${cyc}/track}

     *) set +x; echo " "                                       ;
        echo "FATAL ERROR:  INPUT CMODEL PARAMETER IS NOT RECOGNIZED.";
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

for tfile in `ls -1 ${COMOUT}/${achar}[np]*.t${cyc}z.cyclone.trackatcfunix`
do
  cat $tfile >>trak.allperts.atcfunix.${amodel}.${ymdh}
done

numrecs=` cat trak.allperts.atcfunix.${amodel}.${ymdh} | wc -l`
if [ ${numrecs} -eq 0 ]; then
  msg="No member tracks exist for ${ymdh}"
  echo "WARNING:  $msg"
  postmsg $jlogfile "$msg"
  exit 0
fi

for dt in 65
do

  echo "TIMING: Time just before call to trakave for dt= $dt is `date`"
  export pgm=ens_trak_ave
  . prep_step

  # Input file
  export FORT11=${DATA}/trak.allperts.atcfunix.${amodel}.${ymdh}

  # Output files
  export FORT51=${DATA}/${amodel}.trkprob.${ymdh}.${dt}.ctlinfo.txt
  # Unit 52: Created internally, may be 1 to 15 files...
  export FORT53=${DATA}/trak.${amodel}.atcfunix.${ymdh}
  export FORT54=${DATA}/trak.${amodel}.atcf.${ymdh}
  export FORT55=${DATA}/trak.${amodel}.all.${ymdh}
  export FORT56=${DATA}/trak.${amodel}.spread.${ymdh}
  export FORT57=${DATA}/trak.${amodel}.mode.${ymdh}

  namelist=${DATA}/input.${ymdh}.nlist
  echo "&datain dthresh=${dt}.0,cmodel='${cmodel}'/" >${namelist}

  ${EXECens_tracker}/ens_trak_ave <${namelist} >${DATA}/ens_trak_ave.${ymdh}.${dt}.fout
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
    err_exit "FAILED ${jobid} - ERROR RUNNING ens_trak_ave - ABNORMAL EXIT"
  fi

  set +x
  echo "TIMING: Time just after call to trakave for dt= $dt is  `date`"
  set -x

done

set +x
echo "TIMING: Time after loop to get mean & probabilities for $ymdh is `date`"
set -x


#-----------------------------------------------------
# Parse out the atcfunix records and send them to the
# correct storm trackers directory and file.

if [ "$SENDCOM" = 'YES' ]
then

  glatuxarch=${glatuxarch:-${gltrkdir}/tracks.atcfunix.${yy}}
  cat ${DATA}/trak.${amodel}.atcfunix.${ymdh}           >>${glatuxarch}

  glmodearch=${glmodearch:-${gltrkdir}/tracks.ens_mode.atcfunix.${yy}}
  cat ${DATA}/trak.${amodel}.mode.${ymdh}               >>${glmodearch}

# 03/03/2017  to remove STD from track file, requested by NHC ---------
  if [ -s ${DATA}/trak.${amodel}.atcfunix.${ymdh} ]; then
    cat ${DATA}/trak.${amodel}.atcfunix.${ymdh}|cut -c1-95 > ${DATA}/short.${amodel}.atcfunix.${ymdh}
    cp ${DATA}/trak.${amodel}.atcfunix.${ymdh} ${DATA}/long.${amodel}.atcfunix.${ymdh}
    cp ${DATA}/short.${amodel}.atcfunix.${ymdh} ${DATA}/trak.${amodel}.atcfunix.${ymdh}
  fi
  cp ${DATA}/long.${amodel}.atcfunix.${ymdh} ${COMOUT}/${amodel}.t${cyc}z.cyclone.trackstd

  cp ${DATA}/trak.${amodel}.atcfunix.${ymdh} ${COMOUT}/${amodel}.t${cyc}z.cyclone.trackatcfunix
  cp ${DATA}/trak.${amodel}.spread.${ymdh}   ${COMOUT}/${amodel}.t${cyc}z.cyclone.trackspread
  cp ${DATA}/trak.${amodel}.mode.${ymdh}     ${COMOUT}/${amodel}.t${cyc}z.cyclone.trackmode
  cp ${DATA}/${amodel}.trkprob.*${ymdh}*.ieee             ${COMOUT}/
  cp ${DATA}/${amodel}.trkprob.${ymdh}.${dt}.ctlinfo.txt  ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]
  then
    if [ $cmodel != 'eens' ]
    then
      $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/${amodel}.t${cyc}z.cyclone.trackatcfunix
    fi
  fi

  # We need to parse apart the atcfunix file and distribute the forecasts to
  # the necessary directories.  To do this, first sort the atcfunix records
  # by forecast hour (k6), then sort again by ocean basin (k1), storm number (k2)
  # and then quadrant radii wind threshold (k12).  Once you've got that organized
  # file, break the file up by putting all the forecast records for each storm
  # into a separate file.  Then, for each file, find the corresponding atcfunix
  # file in the storm trackers directory and dump the atcfunix records for that storm
  # in there.

  auxfile=${DATA}/trak.${amodel}.atcfunix.${PDY}${cyc}
  sort -k6 ${auxfile} | sort -k1 -k2 -k12  >atcfunix.sorted

  old_string="XX, XX"

  ict=0
  while read unixrec
  do
    storm_string=` echo "${unixrec}" | cut -c1-6`
    if [ "${storm_string}" = "${old_string}" ]
    then
      echo "${unixrec}" >>atcfunix_file.${ict}
    else
      let ict=ict+1
      echo "${unixrec}"  >atcfunix_file.${ict}
      old_string="${storm_string}"
    fi
  done <atcfunix.sorted

  nhcct=0
  if [ $ict -gt 0 ]
  then
    mct=0
    while [ $mct -lt $ict ]
    do
      let mct=mct+1
      at=` head -1 atcfunix_file.$mct | cut -c1-2 | tr '[A-Z]' '[a-z]'`
      NO=` head -1 atcfunix_file.$mct | cut -c5-6`
      if [ ! -d ${COMOUTatcf}/${at}${NO}${syyyy} ]
      then
          mkdir -p ${COMOUTatcf}/${at}${NO}${syyyy}
      fi
      cat atcfunix_file.$mct >>${COMOUTatcf}/${at}${NO}${syyyy}/ncep_a${at}${NO}${syyyy}.dat
      set +x
      echo " "
      echo "+++ Adding records to  TPC ATCFUNIX directory: ${COMOUTatcf}/${at}${NO}${syyyy}"
      echo " "
      set -x

      if [ $at = 'al' -o $at = 'ep' ]; then
        let nhcct=nhcct+1
      fi
    done
  fi

#  cat ${DATA}/ens_trak_ave.${ymdh}.${dt}.fout

fi
