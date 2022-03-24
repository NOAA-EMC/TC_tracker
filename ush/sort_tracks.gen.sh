#!/bin/ksh
PS4=' + sort_tracks.sh line $LINENO: '

echo " "
echo "+++ Top of sort script, TRKDATA= $TRKDATA"
echo " "
set -x

cd $TRKDATA

#J.Peng---2012-04-12-------------------------
model=${atcfout}
min_storm_length=24

#vdrcc=`${datecheck} ${YMDH} >/dev/null; echo $?`
#if [ ${vdrcc} -eq 0 ]; then
#  echo " "
#  echo "Imported date there, using ymdh= $YMDH"
#  echo " "
#else
#  tmpdate=`date '+%Y%m%d'`
#  indate=${tmpdate}00
#  echo " "
#  echo "!!! IMPORTED DATE NOT THERE; USING CURRENT DAY'S 00Z CYCLE"
#  echo " "
#fi
  
yyyy=`echo ${PDY} | cut -c1-4`
ymdh=${PDY}${cyc}

#J.Peng----2012-04-11-------------------
#outdir=/ptmpp1/Jiayi.Peng/hugen_g2/${ymdh}
  
trakfile=trak.${model}.atcf_gen.${regtype}.${ymdh}
# trakfile=mftrak.atcf_gen.${ymdh}
# trakfile=trak.jsg.atcf_gen.glob.2005082506

#---------------------------------------------------------------
# There can be up to 3 different forecast records for each time
# level (1 each for 34-, 50- and 64-knot wind radii).  For our
# plotting purposes, we just care about the track, so just pick
# out one of them (the records that have 34-kt winds).  The
# lat/lon information will be the same on all 3.  Sort these
# records by storm number.  Cat out the file and sort it by 
# storm ID.  The storm ID is the 3rd element in the atcf record.

#cat ${trakfile} | grep "34, NEQ" | grep FOF | sort +2 -n >${trakfile}.sorted
cat ${trakfile} | grep "34, NEQ" | grep FOF | sort -k 2 -n >${trakfile}.sorted

#---------------------------------------------------------------
# Now go through the sorted atcf file and create a list of the
# unique storm IDs.

>unique_storm_list.txt

prevstormid='xxx'
while read atcfrec
do

  stormid=` echo "${atcfrec}" | awk -F, '{print $3}'`
  if [ ${stormid} != ${prevstormid} ]; then
    echo "${stormid}" >>unique_storm_list.txt
    set +x
    echo "+++ Storm ${stormid} added to unique storm list"
    set -x
    prevstormid=${stormid}
  fi
      
done <${trakfile}.sorted

#---------------------------------------------------------------
# Now go through this list of unique storm IDs, and for each
# storm, grep out all of the atcf records from the sorted 
# atcf file.  Then check to see what the length of time is that
# each storm lived for.  If the storm lived for at least the 
# minimum storm length, then dump all the atcf records (i.e., 
# all lead times) into a final, sorted & filtered file.

>storms.${model}.atcf_gen.${regtype}.${ymdh}

while read stormid
do

  >indiv_storm.temp.txt
  grep "${stormid}" ${trakfile}.sorted >indiv_storm.temp.txt

  first_hour=` head -1 indiv_storm.temp.txt | awk -F, '{printf ("%d\n",$7)}'`
  last_hour=`  tail -1 indiv_storm.temp.txt | awk -F, '{printf ("%d\n",$7)}'`

  let storm_length=last_hour-first_hour

  if [ ${storm_length} -ge ${min_storm_length} ]; then
    set +x
    echo " "
    echo "+++ Storm $stormid lived for at least 24h.  Length= $storm_length"
    echo " "
    set -x
    cat indiv_storm.temp.txt >>storms.${model}.atcf_gen.${regtype}.${ymdh}
  else
    set +x
    echo " "
    echo "!!! Storm $stormid DID NOT LIVE at least 24h.  Length= $storm_length"
    echo " "
    set -x
  fi

done <unique_storm_list.txt

# Now add in the storms that are already being numbered and
# tracked by one of the operational forecasting centers.
# These storms have TC Vitals records issued for them.

grep -v FOF ${trakfile} | grep -v "ML, " | grep -v "TG," | \
         grep "34, NEQ" >>storms.${model}.atcf_gen.${regtype}.${ymdh}
#        grep "34, NEQ" | sort +0 -n >>storms.${model}.atcf_gen.${regtype}.${ymdh}

#archdir=${FIXens_tracker}/tracks_${yyyy}
#if [ ! -s ${archdir} ]; then
#  mkdir -p ${archdir}
#fi

#J.Peng----2012-04-12---------
#cp  storms.${model}.atcf_gen.${regtype}.${ymdh} ${gradsdir}/.
#cp  storms.${model}.atcf_gen.${regtype}.${ymdh} ${outdir}/.
#cat storms.${model}.atcf_gen.${regtype}.${ymdh} >>${archdir}/storms.${model}.atcf_gen.${regtype}.${yyyy}
##cp storms.${model}.atcf_gen.${regtype}.${ymdh} ${FIXens_tracker}/genesis_track_${yyyy}/.

if [ "$SENDCOM" = 'YES' ]; then
  cp storms.${model}.atcf_gen.${regtype}.${ymdh} ${COMOUT}/

  if [ "$SENDDBN" = 'YES' ]; then
    if [ "$cmodel" != 'eens' -a "$cmodel" != 'ecmwf' -a "$cmodel" != 'ukmet' ]; then
      $DBNROOT/bin/dbn_alert MODEL ENS_GENESIS $job ${COMOUT}/storms.${model}.atcf_gen.${regtype}.${ymdh}
    fi
  fi
fi

