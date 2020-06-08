#!/bin/ksh
export PS4=' + extrkr_g1.sh line $LINENO: '

set +x
echo "TIMING: Time at beginning of extrkr.sh for pert= $pert is `date`"
set -x
export cmodel=$2
export pert=$3
export DATA=$4

set +x
##############################################################################
echo " "
echo "------------------------------------------------"
echo "xxxx - Track vortices in model GRIB-1 output"
echo "------------------------------------------------"
echo "History: Mar 1998 - Marchok - First implementation of this new script."
echo "         Apr 1999 - Marchok - Modified to allow radii output file and"
echo "                              to allow reading of 4-digit years from"
echo "                              TC vitals file."
echo "         Oct 2000 - Marchok - Fixed bugs: (1) copygb target grid scanning mode"
echo "                              flag had an incorrect value of 64 (this prevented"
echo "                              NAM, NGM and ECMWF from being processed correctly);" 
echo "                              Set it to 0.  (2) ECMWF option was using the "
echo "                              incorrect input date (today's date instead of "
echo "                              yesterday's)."
echo "         Jan 2001 - Marchok - Hours now listed in script for each model and "
echo "                              passed into program.  Script included to process"
echo "                              GFDL & Ensemble data.  Call to DBN included to "
echo "                              pass data to OSO and the Navy.  Forecast length"
echo "                              extended to 5 days for GFS & MRF."
echo " "
echo "                    In the event of a crash, you can contact Tim "
echo "                    Marchok at GFDL at (609) 452-6534 or timothy.marchok@noaa.gov"
echo " "
echo "Current time is: `date`"
echo " "
##############################################################################
set -x

##############################################################################
#
#    FLOW OF CONTROL
#
# 1. Define data directories and file names for the input model 
# 2. Process input starting date/cycle information
# 3. Update TC Vitals file and select storms to be processed
# 4. Cut apart input GRIB files to select only the needed parms and hours
# 5. Execute the tracker
# 6. Copy the output track files to various locations
#
##############################################################################
msg="has begun for ${cmodel} ${pert} at ${cyc}z"
postmsg "$jlogfile" "$msg"

# This script runs the hurricane tracker using operational GRIB model output.  
# This script makes sure that the data files exist, it then pulls all of the 
# needed data records out of the various GRIB forecast files and puts them 
# into one, consolidated GRIB file, and then runs a program that reads the TC 
# Vitals records for the input day and updates the TC Vitals (if necessary).
# It then runs gettrk, which actually does the tracking.
# 
# Environmental variable inputs needed for this scripts:
#  PDY   -- The date for data being processed, in YYYYMMDD format
#  cyc   -- The numbers for the cycle for data being processed (00, 06, 12, 18)
#  cmodel -- Model being processed (gfs, mrf, ukmet, ecmwf, nam, ngm, ngps,
#                                   gdas, gfdl, ens (ncep ensemble), ensm (ncep
#                                   ensemble run off of the mean fields)
#  envir -- 'prod' or 'test'
#  SENDCOM -- 'YES' or 'NO'
#  stormenv -- This is only needed by the tracker run for the GFDL model.
#              'stormenv' contains the name/id that is used in the input
#              grib file names.
#  pert  -- This is only needed by the tracker run for the NCEP ensemble.
#           'pert' contains the ensemble member id (e.g., n2, p4, etc.)
#           which is used as part of the grib file names.
#
# For testing script interactively in non-production set following vars:
#     gltrkdir   - Directory for output tracks
#     archsyndir - Directory with syndir scripts/exec/fix 
#

qid=$$
#----------------------------------------------#
#   Get input date information                 #
#----------------------------------------------#


###############################################
export jobid=${jobid:-testjob}
export SENDCOM=${SENDCOM:-NO}

if [ ! -d $DATA ]
then
   mkdir -p $DATA
fi
cd $DATA

if [ ${#PDY} -eq 0 -o ${#cyc} -eq 0 -o ${#cmodel} -eq 0 ]
then
  set +x
  echo " "
  echo "FATAL ERROR:  Something wrong with input parameters."
  echo "PDY= ${PDY}, cyc= ${cyc}, cmodel= ${cmodel}"
  set -x
  err_exit "FAILED ${jobid} -- BAD INPUTS AT LINE $LINENO IN TRACKER SCRIPT - ABNORMAL EXIT"
else
  set +x
  echo " "
  echo " #-----------------------------------------------------------------#"
  echo " At beginning of tracker script, the following imported variables "
  echo " are defined: "
  echo "   PDY ................................... $PDY"
  echo "   cyc ................................... $cyc"
  echo "   cmodel ................................ $cmodel"
  echo "   jobid ................................. $jobid"
  echo "   envir ................................. $envir"
  echo "   SENDCOM ............................... $SENDCOM"
  echo " "
  set -x
fi

syy=`echo ${PDY} | cut -c3-4`
smm=`echo ${PDY} | cut -c5-6`
sdd=`echo ${PDY} | cut -c7-8`
shh=${cyc}
symd=`echo ${PDY} | cut -c3-8`
syyyy=`echo ${PDY} | cut -c1-4`
CENT=`echo ${PDY} | cut -c1-2`

#------J.Peng----01-21-2015---------
#export COMOUTatcf=${COMOUTatcf:-${COMROOT}/nhc/${envir}/atcf}
#export archsyndir=${archsyndir:-${COMROOT}/arch/prod/syndat}
archsyndir=${archsyndir:-${COMINsyn:?}}
#export gltrkdir=${gltrkdir:-${COMROOT}/hur/${envir}/global}
gltrkdir=${gltrkdir:-${COMOUThur:?}}

wgrib_parmlist=" HGT:850 HGT:700 UGRD:850 UGRD:700 UGRD:500 VGRD:850 VGRD:700 VGRD:500 SurfaceU SurfaceV ABSV:850 ABSV:700 PRMSL:MSL "
wgrib_egrep_parmlist="HGT:850|HGT:700|UGRD:850|UGRD:700|UGRD:500|VGRD:850|VGRD:700|VGRD:500|UGRD:10 m |VGRD:10 m |ABSV:850|ABSV:700|PRMSL:MSL"
wgrib_ec_hires_parmlist=" GH:850 GH:700 U:850 U:700 U:500 V:850 V:700 V:500 10U:sfc 10V:sfc MSL:sfc "
wgrib_uk_hires_parmlist=' HGT:850 HGT:700 UGRD:850 UGRD:700 UGRD:500 VGRD:850 VGRD:700 VGRD:500 UGRD:sfc VGRD:sfc ABSV:850 ABSV:700 PRMSL:MSL '

#----------------------------------------------------------------#
#
#    --- Define data directories and data file names ---
#               
# Convert the input model to lowercase letters and check to see 
# if it's a valid model, and assign a model ID number to it.  
# This model ID number is passed into the Fortran program to 
# let the program know what set of forecast hours to use in the 
# ifhours array.  Also, set the directories for the operational 
# input GRIB data files and create templates for the file names.
#
# NOTE: Do NOT try to standardize this script by changing all of 
# these various data directories' variable names to be all the 
# same, such as "datadir".  As you'll see in the data cutting 
# part of this script below, different methods are used to cut 
# apart different models, thus it is important to know the 
# difference between them....
#----------------------------------------------------------------#

cmodel=`echo ${cmodel} | tr "[A-Z]" "[a-z]"`

case ${cmodel} in 

  ukmet) set +x; echo " "                                  ;
       echo " ++ operational high-res UKMET chosen"        ;
       echo " "; set -x                                    ;
       ukmetdir=${ukmetdir:-${COMINukmet:?}}                     ;
       ukmetgfile=pgbf                                     ;
       ukmetgfileb=.ukm.${PDY}${cyc}                       ;

       fcstlen=120                                         ;
#       fcsthrs=$(seq -f%02g -s' ' 0 6 $fcstlen)            ;
       fcsthrs=' 00 12 24 36 48 60 72 84 96 108 120'       ;
       atcfnum=17                                          ;
       atcfname="ukx "                                     ;
       atcfout="ukx"                                       ;
       modtyp='global'                                     ;
       model=3                                             ;;

  ecmwf) set +x; echo " "                                  ;
       echo " ++ operational high-res ECMWF chosen"        ;
       echo " "; set -x                                    ;
#       ecmwfdir=${ecmwfdir:-${DCOMROOT}/us007003/${PDY}/wgrbbul/ecmwf};
       ecmwfdir=${ecmwfdir:-${DCOM:?}}                     ;
       fcstlen=240                                         ;
       fcsthrs=$(seq -f%02g -s' ' 0 6 $fcstlen)            ;
       atcfnum=19                                          ;
       atcfname="emx "                                     ;
       atcfout="emx"                                       ;
       modtyp='global'                                     ;
       model=4                                             ;;

  eens) set +x; echo " "                                   ;
       echo " ++ ECMWF ensemble member ${pert} chosen"     ;
       echo " "; set -x                                    ;
       pert=` echo ${pert} | tr '[A-Z]' '[a-z]'`           ;
       PERT=` echo ${pert} | tr '[a-z]' '[A-Z]'`           ;
       syy=`echo ${PDY} | cut -c3-4`                       ;
       smm=`echo ${PDY} | cut -c5-6`                       ;
       sdd=`echo ${PDY} | cut -c7-8`                       ;
       shh=${cyc}                                          ;
       symd=`echo ${PDY} | cut -c3-8`                      ;
#       ecedir=${ecedir:-${COMROOT}/gens/${envir}/ecme.${PDY}/${cyc}};
       ecedir=${ecedir:-${COMIN:?}}                        ;
       fcstlen=240                                         ;
       fcsthrs=$(seq -f%02g -s' ' 0 6 $fcstlen)            ;
       atcfnum=91                                          ;
       pert_posneg=` echo "${pert}" | cut -c1-1`           ;
       pert_num=`    echo "${pert}" | cut -c2-3`           ;
       atcfname="e${pert_posneg}${pert_num}"               ;
       atcfout="e${pert_posneg}${pert_num}"                ;
       modtyp='global'                                     ;
       model=11                                            ;;

  sref) set +x; echo " "                                   ;
       echo " ++ operational SREF ensemble member ${pert} chosen";
       echo " "; set -x                                    ;
       pert=` echo ${pert} | tr '[A-Z]' '[a-z]'`           ;
       PERT=` echo ${pert} | tr '[a-z]' '[A-Z]'`           ;
       srtype=` echo ${pert} | cut -c1-2`                  ;
       srpertnum=` echo ${pert} | cut -c3-4`               ;

#       if [ ${srtype} = 'se' ]; then
#         # Eta members
#         if [ ${srpertnum} = 'c1' ]; then
#           srefgfile=sref_eta.t${cyc}z.pgrb221.ctl1.f
#         elif [ ${srpertnum} = 'c2' ]; then
#           srefgfile=sref_eta.t${cyc}z.pgrb221.ctl2.f
#         else
#           srefgfile=sref_eta.t${cyc}z.pgrb221.${srpertnum}.f
#         fi
       if [ ${srtype} = 'em' ]; then
         # ARW members
         if [ ${srpertnum} = 'c1' ]; then
           srefgfile=sref_em.t${cyc}z.pgrb221.ctl.f
         else
           srefgfile=sref_em.t${cyc}z.pgrb221.${srpertnum}.f
         fi
       elif [ ${srtype} = 'nb' ]; then
         # RSM members
         if [ ${srpertnum} = 'c1' ]; then
           srefgfile=sref_nmb.t${cyc}z.pgrb221.ctl.f
         else
           srefgfile=sref_nmb.t${cyc}z.pgrb221.${srpertnum}.f
         fi
       elif [ ${srtype} = 'nm' ]; then
         # NMM members
         if [ ${srpertnum} = 'c1' ]; then
           srefgfile=sref_nmm.t${cyc}z.pgrb221.ctl.f
         else
           srefgfile=sref_nmm.t${cyc}z.pgrb221.${srpertnum}.f
         fi
       else
         set +x
         echo " "
         echo "FATAL ERROR:  SREF MEMBER NOT RECOGNIZED."
         echo "!!!        USER INPUT SREF MEMBER = --->${pert}<---"
         echo " "
         set -x
         err_exit "SREF MEMBER ${pert} NOT RECOGNIZED"
       fi

#       srefdir=${srefdir:-${COMROOT}/sref/prod/sref.${PDY}/${cyc}/pgrb};
       srefdir=${srefdir:-${COMINsref:?}}                  ;
       fcstlen=87                                          ;
       fcsthrs=$(seq -w -s' ' 0 3 $fcstlen)                ;
       atcfnum=92                                          ;
       atcfname="${pert}"                                  ;
       atcfout="${pert}"                                   ;
       modtyp='regional'                                   ;
       model=13                                            ;;

  *) msg="FATAL ERROR:  Model $cmodel is not recognized."  ;
     echo "$msg"; postmsg $jlogfile "$msg"                 ;
     err_exit "FAILED ${jobid} -- UNKNOWN cmodel IN TRACKER SCRIPT - ABNORMAL EXIT";;

esac

#---------------------------------------------------------------#
#
#      --------  TC Vitals processing   --------
#
# Check Steve Lord's operational tcvitals file to see if any 
# vitals records were processed for this time by his system.  
# If there were, then you'll find a file in /com/gfs/prod/gfs.yymmdd 
# with the vitals in it.  Also check the raw TC Vitals file in
# /com/arch/prod/syndat , since this may contain storms that Steve's 
# system ignored (Steve's system will ignore all storms that are 
# either over land or very close to land);  We still want to track 
# these inland storms, AS LONG AS THEY ARE NHC STORMS (don't 
# bother trying to track inland storms that are outside of NHC's 
# domain of responsibility -- we don't need that info).
# UPDATE 5/12/98 MARCHOK: The script is updated so that for the
#   global models, the gfs directory is checked for the error-
#   checked vitals file, while for the regional models, the 
#   nam directory is checked for that file.
#--------------------------------------------------------------#

d6ago_ymdh=` ${NDATE:?} -6 ${PDY}${cyc}`
d6ago_4ymd=` echo ${d6ago_ymdh} | cut -c1-8`
d6ago_ymd=` echo ${d6ago_ymdh} | cut -c3-8`
d6ago_hh=`  echo ${d6ago_ymdh} | cut -c9-10`
d6ago_str="${d6ago_ymd} ${d6ago_hh}00"

d6ahead_ymdh=` ${NDATE:?} 6 ${PDY}${cyc}`
d6ahead_4ymd=` echo ${d6ahead_ymdh} | cut -c1-8`
d6ahead_ymd=` echo ${d6ahead_ymdh} | cut -c3-8`
d6ahead_hh=`  echo ${d6ahead_ymdh} | cut -c9-10`
d6ahead_str="${d6ahead_ymd} ${d6ahead_hh}00"

if [ ${modtyp} = 'global' ]
then
#  synvitdir=${COMROOT}/gfs/prod/gfs.${PDY}
  synvitdir=${COMINgfs:?}/${cyc}
  synvitfile=gfs.t${cyc}z.syndata.tcvitals.tm00
#  synvit6ago_dir=${COMROOT}/gfs/prod/gfs.${d6ago_4ymd}
  synvit6ago_dir=${synvitdir%.*}.${d6ago_4ymd}/${d6ago_hh}
  synvit6ago_file=gfs.t${d6ago_hh}z.syndata.tcvitals.tm00
#  synvit6ahead_dir=${COMROOT}/gfs/prod/gfs.${d6ahead_4ymd}
  synvit6ahead_dir=${synvitdir%.*}.${d6ahead_4ymd}/${d6ahead_hh}
  synvit6ahead_file=gfs.t${d6ahead_hh}z.syndata.tcvitals.tm00
else
  synvitdir=${COMINnam:?}
  synvitfile=nam.t${cyc}z.syndata.tcvitals.tm00
  synvit6ago_dir=${synvitdir%.*}.${d6ago_4ymd}
  synvit6ago_file=nam.t${d6ago_hh}z.syndata.tcvitals.tm00
  synvit6ahead_dir=${synvitdir%.*}.${d6ahead_4ymd}
  synvit6ahead_file=nam.t${d6ahead_hh}z.syndata.tcvitals.tm00

#  synvitdir=/ensemble/save/Jiayi.Peng/sref_tcvital/sref.${PDY}
#  synvitfile=sref.t${cyc}z.syndata.tcvitals.tm00
#  synvit6ago_dir=/ensemble/save/Jiayi.Peng/sref_tcvital/sref.${d6ago_4ymd}
#  synvit6ago_file=sref.t${d6ago_hh}z.syndata.tcvitals.tm00
#  synvit6ahead_dir=/ensemble/save/Jiayi.Peng/sref_tcvital/sref.${d6ahead_4ymd}
#  synvit6ahead_file=sref.t${d6ahead_hh}z.syndata.tcvitals.tm00
fi

set +x
echo " "
echo "              -----------------------------"
echo " "
echo " Now sorting and updating the TC Vitals file.  Please wait...."
echo " "
set -x

dnow_str="${symd} ${cyc}00"

if [ -s ${synvitdir}/${synvitfile} -o\
     -s ${synvit6ago_dir}/${synvit6ago_file} -o\
     -s ${synvit6ahead_dir}/${synvit6ahead_file} ]
then
  grep "${d6ago_str}" ${synvit6ago_dir}/${synvit6ago_file}        \
                  >${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
  grep "${dnow_str}"  ${synvitdir}/${synvitfile}                  \
                 >>${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
  grep "${d6ahead_str}" ${synvit6ahead_dir}/${synvit6ahead_file}  \
                 >>${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
else
  set +x
  echo " "
  echo " There is no (synthetic) TC vitals file for ${cyc}z in ${synvitdir},"
  echo " nor is there a TC vitals file for ${d6ago_hh}z in ${synvit6ago_dir}."
  echo " nor is there a TC vitals file for ${d6ahead_hh}z in ${synvit6ahead_dir},"
  echo " Checking the raw TC Vitals file ....."
  echo " "
  set -x
fi

# Take the vitals from Steve Lord's /com/gfs/prod tcvitals file,
# and cat them with the NHC-only vitals from the raw, original
# /com/arch/prod/synda_tcvitals file.  Do this because the nwprod
# tcvitals file is the original tcvitals file, and Steve runs a
# program that ignores the vitals for a storm that's over land or
# even just too close to land, and for tracking purposes for the
# US regional models, we need these locations.  Only include these
# "inland" storm vitals for NHC (we're not going to track inland 
# storms that are outside of NHC's domain of responsibility -- we 
# don't need that info).  
# UPDATE 5/12/98 MARCHOK: nawk logic is added to screen NHC 
#   vitals such as "91L NAMELESS" or "89E NAMELESS", since TPC 
#   does not want tracks for such storms.

grep "${d6ago_str}" ${archsyndir}/syndat_tcvitals.${CENT}${syy}   | \
      grep -v TEST | awk 'substr($0,6,1) !~ /[8]/ {print $0}' \
      >${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}
grep "${dnow_str}"  ${archsyndir}/syndat_tcvitals.${CENT}${syy}   | \
      grep -v TEST | awk 'substr($0,6,1) !~ /[8]/ {print $0}' \
      >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}
grep "${d6ahead_str}" ${archsyndir}/syndat_tcvitals.${CENT}${syy} | \
      grep -v TEST | awk 'substr($0,6,1) !~ /[8]/ {print $0}' \
      >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}

#PRODTEST# Use the next couple lines to test the tracker on the SP.
#PRODTEST# These next couple lines use data from a test TC Vitals file that 
#PRODTEST# I generate.  When you are ready to test this system, call me and
#PRODTEST# I'll create one for the current day, and then uncomment the next
#PRODTEST# couple lines in order to access the test vitals file.
#
#ttrkdir=/nfsuser/g01/wx20tm/trak/prod/data
#ttrkdir=/nfsuser/g01/wx20tm/trak/para/scripts
#grep "${dnow_str}" ${ttrkdir}/tcvit.01l >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}


# IMPORTANT:  When "cat-ing" these files, make sure that the vitals
# files from the "raw" TC vitals files are first in order and Steve's
# TC vitals files second.  This is because Steve's vitals file has
# been error-checked, so if we have a duplicate tc vitals record in
# these 2 files (very likely), program supvit.x below will
# only take the last vitals record listed for a particular storm in
# the vitals file (all previous duplicates are ignored, and Steve's
# error-checked vitals records are kept).

cat ${DATA}/tmprawvit.${atcfout}.${PDY}${cyc} ${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc} \
        >${DATA}/vitals.${atcfout}.${PDY}${cyc}

# If we are doing the processing for the GFDL model, then we want
# to further cut down on which vitals we allow into this run of the
# tracker.  The reason is that this program will be called from 
# each individual run for a storm, so the grib files will be 
# specific to each storm.  So if 4 storms are being run at a 
# particular cycle, then this script is run 4 separate times from
# within the GFDL_POST job.

if [ ${cmodel} = 'gfdl' ]; then
  grep -i ${stormid} ${COMIN}/${ATCFNAME}.vitals.${syy}${smm}${sdd}${shh} >${DATA}/tmpvit
  mv ${DATA}/tmpvit ${DATA}/vitals.${atcfout}.${PDY}${cyc}
fi

#--------------------------------------------------------------#
# Now run a fortran program that will read all the TC vitals
# records for the current dtg and the dtg from 6h ago, and
# sort out any duplicates.  If the program finds a storm that
# was included in the vitals file 6h ago but not for the current
# dtg, this program updates the 6h-old first guess position
# and puts these updated records as well as the records from
# the current dtg into a temporary vitals file.  It is this
# temporary vitals file that is then used as the input for the
# tracking program.
#--------------------------------------------------------------#

ymdh6ago=` ${NDATE:?} -6 ${PDY}${cyc}`
syy6=`echo ${ymdh6ago} | cut -c3-4`
smm6=`echo ${ymdh6ago} | cut -c5-6`
sdd6=`echo ${ymdh6ago} | cut -c7-8`
shh6=`echo ${ymdh6ago} | cut -c9-10`
symd6=${syy6}${smm6}${sdd6}

ymdh6ahead=` ${NDATE:?} 6 ${PDY}${cyc}`
syyp6=`echo ${ymdh6ahead} | cut -c3-4`
smmp6=`echo ${ymdh6ahead} | cut -c5-6`
sddp6=`echo ${ymdh6ahead} | cut -c7-8`
shhp6=`echo ${ymdh6ahead} | cut -c9-10`
symdp6=${syyp6}${smmp6}${sddp6}

echo "&datenowin   dnow%yy=${syy}, dnow%mm=${smm},"       >${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "             dnow%dd=${sdd}, dnow%hh=${cyc}/"      >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "&date6agoin  d6ago%yy=${syy6}, d6ago%mm=${smm6},"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "             d6ago%dd=${sdd6}, d6ago%hh=${shh6}/"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "&date6aheadin  d6ahead%yy=${syyp6}, d6ahead%mm=${smmp6},"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "               d6ahead%dd=${sddp6}, d6ahead%hh=${shhp6}/"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}

numvitrecs=`cat ${DATA}/vitals.${atcfout}.${PDY}${cyc} | wc -l`
if [ ${numvitrecs} -eq 0 ]
then
  set +x
  echo " "
  echo "!!! WARNING -- There are no vitals records for this time period."
  echo "!!! File ${DATA}/vitals.${atcfout}.${PDY}${cyc} is empty."
  echo "!!! It could just be that there are no storms for the current"
  echo "!!! time.  You may wish to check the date and submit this job again..."
  echo " "
  set -x
  exit 0
fi

# - - - - - - - - - - - - -
# Before running the program to read, sort and update the vitals,
# first run the vitals through some awk logic, the purpose of 
# which is to convert all the 2-digit years into 4-digit years.
# Beginning 4/21/99, NHC and JTWC will begin sending the vitals
# with 4-digit years, however it is unknown when other global
# forecasting centers will begin using 4-digit years, thus we
# need the following logic to ensure that all the vitals going
# into supvit.f have uniform, 4-digit years in their records.
#
# 1/8/2000: sed code added by Tim Marchok due to the fact that 
#       some of the vitals were getting past the syndata/qctropcy
#       error-checking with a colon in them; the colon appeared
#       in the character immediately to the left of the date, which
#       was messing up the "(length($4) == 8)" statement logic.
# - - - - - - - - - - - - -

sed -e "s/\:/ /g"  ${DATA}/vitals.${atcfout}.${PDY}${cyc} > ${DATA}/tempvit
mv ${DATA}/tempvit ${DATA}/vitals.${atcfout}.${PDY}${cyc}

awk '
{
  yycheck = substr($0,20,2)
  if ((yycheck == 20 || yycheck == 19) && (length($4) == 8)) {
    printf ("%s\n",$0)
  }
  else {
    if (yycheck >= 0 && yycheck <= 50) {
      printf ("%s20%s\n",substr($0,1,19),substr($0,20))
    }
    else {
      printf ("%s19%s\n",substr($0,1,19),substr($0,20))
    }
  }
} ' ${DATA}/vitals.${atcfout}.${PDY}${cyc} >${DATA}/vitals.${atcfout}.${PDY}${cyc}.y4

mv ${DATA}/vitals.${atcfout}.${PDY}${cyc}.y4 ${DATA}/vitals.${atcfout}.${PDY}${cyc}

export pgm=supvit_g1
. prep_step

# Input file
export FORT31=${DATA}/vitals.${atcfout}.${PDY}${cyc}

# Output file
export FORT51=${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}

msg="$pgm start for $atcfout at ${cyc}z"
postmsg "$jlogfile" "$msg"

${EXECens_tracker}/supvit_g1 <${DATA}/suv_input.${atcfout}.${PDY}${cyc}
suvrcc=$?

if [ ${suvrcc} -eq 0 ]
then
  msg="$pgm end for $atcfout at ${cyc}z completed normally"
  postmsg "$jlogfile" "$msg"
else
  set +x
  echo " "
  echo "FATAL ERROR:  An error occurred while running supvit.x, "
  echo "!!! which is the program that updates the TC Vitals file."
  echo "!!! Return code from supvit.x = ${suvrcc}"
  echo "!!! model= ${atcfout}, forecast initial time = ${PDY}${cyc}"
  echo " "
  set -x
  err_exit "FAILED ${jobid} - ERROR RUNNING supvit_g1 IN TRACKER SCRIPT- ABNORMAL EXIT"
fi

#------------------------------------------------------------------#
# Now select all storms to be processed, that is, process every
# storm that's listed in the updated vitals file for the current
# forecast hour.  If there are no storms for the current time,
# then exit.
#------------------------------------------------------------------#

numvitrecs=`cat ${DATA}/vitals.upd.${atcfout}.${PDY}${cyc} | wc -l`
if [ ${numvitrecs} -eq 0 ]
then
  set +x
  echo " "
  echo "!!! WARNING -- There are no vitals records for this time period "
  echo "!!! in the UPDATED vitals file."
  echo "!!! It could just be that there are no storms for the current"
  echo "!!! time.  You may wish to check the date and submit this job again..."
  echo " "
  set -x
  exit 0
fi

set +x
echo " "
echo " *--------------------------------*"
echo " |        STORM SELECTION         |"
echo " *--------------------------------*"
echo " "
set -x

ict=1
while [ $ict -le 15 ]
do
  stormflag[${ict}]=3
  let ict=ict+1
done

dtg_current="${symd} ${cyc}00"
stormmax=` grep "${dtg_current}" ${DATA}/vitals.upd.${atcfout}.${PDY}${cyc} | wc -l`

if [ ${stormmax} -gt 15 ]
then
  stormmax=15
fi

sct=1
while [ ${sct} -le ${stormmax} ]
do
  stormflag[${sct}]=1
  let sct=sct+1
done


#-----------------------------------------------------------------#
#
#         ------  CUT APART INPUT GRIB FILES  -------
#
# For the selected model, cut apart the GRIB input files in order
# to pull out only the variables that we need for the tracker.  
# Put these selected variables from all forecast hours into 1 big 
# GRIB file that we'll use as input for the tracker.
# 
# The wgrib utility (/nwprod/util/exec/wgrib) is used to cut out 
# the needed parms for the GFS, MRF, GDAS, UKMET and NOGAPS files.
# The utility /nwprod/util/exec/copygb is used to interpolate the 
# NGM (polar stereographic) and NAM (Lambert Conformal) data from 
# their grids onto lat/lon grids.  Note that while the lat/lon 
# grid that I specify overlaps into areas that don't have any data 
# on the original grid, Mark Iredell wrote the copygb software so 
# that it will mask such "no-data" points with a bitmap (just be 
# sure to check the lbms in your fortran program after getgb).
#-----------------------------------------------------------------#

set +x
echo " "
echo " -----------------------------------------"
echo "   NOW CUTTING APART INPUT GRIB FILES TO "
echo "   CREATE 1 BIG GRIB INPUT FILE "
echo " -----------------------------------------"
echo " "
set -x

regflag=`grep NHC ${DATA}/vitals.upd.${atcfout}.${PDY}${cyc} | wc -l`

# ------------------------------
#   Process ECMWF, if selected
# ------------------------------

# As of Summer, 2005, ECMWF is now sending us high res (1-degree) data on
# a global grid with 12-hourly resolution out to 240h.  Previously, we 
# only got their data on a low res (2.5-degree) grid, from 35N-35S, with
# 24-hourly resolution out to only 168h.

if [ ${model} -eq 4 ]
then

  if [ -s ${DATA}/ecgribfile.${PDY}${cyc} ]
  then
    rm ${DATA}/ecgribfile.${PDY}${cyc}
  fi

  immddhh=`echo ${PDY}${cyc}| cut -c5-`
  ict=0

  for fhour in ${fcsthrs}
  do
    
    let fhr=ict*6

    echo "fhr= $fhr"
    fmmddhh=` ${NDATE:?} ${fhr} ${PDY}${cyc} | cut -c5- `
    #ec_hires_orig=ecens_DCD${immddhh}00${fmmddhh}001 # Original
    if [ ${fmmddhh} -eq ${immddhh} ]; then
      ec_hires_orig=U1D${immddhh}00${fmmddhh}011
    else
      ec_hires_orig=U1D${immddhh}00${fmmddhh}001
    fi

    ecfile=${ecmwfdir}/${ec_hires_orig}

    let attempts=1
    while [ $attempts -le 30 ]; do
       if [ -s $ecfile ]; then
          break
       else
          sleep 60
          let attempts=attempts+1
       fi
    done
    if [ $attempts -gt 30 ] && [ ! -s $ecfile ]; then
       err_exit "$ecfile still not available after waiting 30 minutes... exiting"
    fi
      
    ${WGRIB:?} -s $ecfile >ec.ix
    export err=$?; err_chk

    for parm in ${wgrib_ec_hires_parmlist}
    do
      grep "${parm}" ec.ix | ${WGRIB:?} -s $ecfile -i -grib -append \
                              -o ${DATA}/ecgribfile.${PDY}${cyc}
    done

    let ict=ict+1

  done

  ${GRBINDEX:?} ${DATA}/ecgribfile.${PDY}${cyc} ${DATA}/ecixfile.${PDY}${cyc}
  export err=$?; err_chk
  gribfile=${DATA}/ecgribfile.${PDY}${cyc}
  ixfile=${DATA}/ecixfile.${PDY}${cyc}

fi

# --------------------------------------------------
#   Process ECMWF Ensemble perturbation, if selected
# --------------------------------------------------

if [ ${model} -eq 11 ]
then
    
  if [ -s ${DATA}/ece${pert}gribfile.${PDY}${cyc} ]
  then
    rm ${DATA}/ece${pert}gribfile.${PDY}${cyc}
  fi
    
  if [ ${pert_posneg} = 'n' ]; then
    posneg=2
  elif [ ${pert_posneg} = 'p' ]; then
    posneg=3
  elif [ ${pert_posneg} = 'c' ]; then
    # low-res control
    posneg=1
  else
    set +x
    echo " "
    echo "FATAL ERROR:  ECMWF PERT ID NOT RECOGNIZED"
    echo "!!! pert_posneg=${pert_posneg}"
    echo " "
    set -x
    err_exit "ECMWF PERT ID ${pert_posneg} NOT RECOGNIZED"
  fi
    
  pnum=${pert_num}
  if [ ${pnum} -lt 10 ]; then
    pnum=` echo $pnum | cut -c2-2`
  fi

  if [ ${pnum} -eq 0 ]; then
    # low-res control
    pnum=2
  fi
    
  pert_grep_str=" 0 0 0 1 ${posneg} ${pnum} 1 "

  glo=${DATA}/ece.lores.cut.${PDY}${cyc}
  xlo=${DATA}/ece.lores.cut.${PDY}${cyc}.i

  if [ -s ${glo} ]; then rm ${glo}; fi
  if [ -s ${xlo} ]; then rm ${xlo}; fi

  grid="255 0 360 181 90000 0000 128 -90000 -1000 1000 1000 0"

  # This next part simply uses wgrib to parse out
  # the member records for each variable from each
  # respective enspost file.

  for var in u850 v850 u700 v700 z850 z700 mslp u500 v500 u10m v10m
  do
#    ecegfile=enspost.t${cyc}z.${var}
    ecegfile=ensposte.t${cyc}z.${var}hr

    if [ ! -s ${ecedir:?}/${ecegfile} ]
    then
      set +x
      echo " "
      echo "FATAL ERROR:  ECMWF ENSEMBLE POST File missing: ${ecedir}/${ecegfile}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo " "
      set -x
      err_exit "FAILED ${jobid} - MISSING ECMWF ENSEMBLE FILE IN TRACKER SCRIPT - ABNORMAL EXIT"
    fi
      
    ece_orig=${ecedir}/${ecegfile}
      
    ${WGRIB:?} -PDS10 ${ece_orig} | grep "${pert_grep_str}" | \
          awk -F:TR= '{print $1}'                       | \
          ${WGRIB:?} -i ${ece_orig} -grib -append -o ${glo}
    export err=$?; err_chk
      
  done
     
  # ECMWF data are 2.5-degree data, so for consistency
  # with the NCEP ensemble data, we now use copygb to
  # interpolate down to 1-degree.  The -g3 in the copygb
  # statement is for grid 3, a 1x1 global grid (AVN).
      
  ${GRBINDEX:?} ${glo} ${xlo}
  export err=$?; err_chk
  gfile=${DATA}/ece${pert}gribfile.${PDY}${cyc}

#  ${COPYGB:?} -g"${grid}" -a ${glo} ${xlo} ${gfile}
#  ${GRBINDEX:?} ${DATA}/ece${pert}gribfile.${PDY}${cyc} ${DATA}/ece${pert}ixfile.${PDY}${cyc}
#  export err=$?; err_chk
   mv ${glo} ${gfile}  
   mv ${xlo} ${DATA}/ece${pert}ixfile.${PDY}${cyc}

  gribfile=${DATA}/ece${pert}gribfile.${PDY}${cyc}
  ixfile=${DATA}/ece${pert}ixfile.${PDY}${cyc}
      
fi    

# --------------------------------------------------
#   Process SREF Ensemble perturbation, if selected
# --------------------------------------------------

if [ ${model} -eq 13 ]
then

      grid='255 0 381 161 80000 160000 128 0000 350000  500  500 0'
#    grid='255 0 301 141 70000 190000 128 0000 340000  500  500 0'
    if [ ${regflag} -eq 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR:  SREF ensemble has been selected, but there are no storms in the"
        echo "!!! TC Vitals file that can be processed.  That is, there are no"
        echo "!!! Vitals records from NHC.  The vitals records that are in the"
        echo "!!! updated vitals file must be from another cyclone forecast "
        echo "!!! center, and the SREF domain does not extend to any "
        echo "!!! region other than that covered by NHC.  Exiting....."
        set -x
        err_exit "SREF ensemble has been selected but there are no storms in the TC Vitals file."
    fi

    if [ -s ${DATA}/sref${pert}gribfile.${PDY}${cyc} ]; then
      rm ${DATA}/sref${pert}gribfile.${PDY}${cyc}
    fi

    for fhour in ${fcsthrs}
    do

      if [ ! -s ${srefdir}/${srefgfile}${fhour} ]
      then
        set +x
        echo " "
	    echo " FATAL ERROR:  SREF ENSEMBLE ${PERT} File missing ${srefdir}/${srefgfile}${fhour}"
	    echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo " "
        set -x
	    err_exit "SREF ENSEMBLE ${PERT} File missing ${srefdir}/${srefgfile}${fhour}"
      fi

      if [ -s ${DATA}/tmpsrefixfile ]; then rm ${DATA}/tmpsrefixfile; fi
      ${GRBINDEX:?} ${srefdir}/${srefgfile}${fhour} ${DATA}/tmpsrefixfile
      export err=$?; err_chk
      x1=${DATA}/tmpsrefixfile
		   
#      set +x
#      echo " "
#      echo " Extracting SREF GRIB data for pert ${pert} for forecast hour = $fhour"
#      echo " "
#      set -x
						  
      g1=${srefdir}/${srefgfile}${fhour}
							 
      ${COPYGB:?} -g"$grid" -k'4*-1 33 100 850' $g1 $x1 ${DATA}/srefllu850.${pert}.grb.f${fhour};   rcc1=$?
      ${COPYGB:?} -g"$grid" -k'4*-1 33 100 700' $g1 $x1 ${DATA}/srefllu700.${pert}.grb.f${fhour};   rcc2=$?
      ${COPYGB:?} -g"$grid" -k'4*-1 33 100 500' $g1 $x1 ${DATA}/srefllu500.${pert}.grb.f${fhour};   rcc3=$?
      ${COPYGB:?} -g"$grid" -k'4*-1 33 105 10'  $g1 $x1 ${DATA}/srefllu10m.${pert}.grb.f${fhour};   rcc4=$?
      ${COPYGB:?} -g"$grid" -k'4*-1 41 100 850' $g1 $x1 ${DATA}/srefllav850.${pert}.grb.f${fhour};  rcc5=$?
      ${COPYGB:?} -g"$grid" -k'4*-1 41 100 700' $g1 $x1 ${DATA}/srefllav700.${pert}.grb.f${fhour};  rcc6=$?
      ${COPYGB:?} -g"$grid" -k'4*-1  7 100 850' $g1 $x1 ${DATA}/srefllz850.${pert}.grb.f${fhour};   rcc7=$?
      ${COPYGB:?} -g"$grid" -k'4*-1  7 100 700' $g1 $x1 ${DATA}/srefllz700.${pert}.grb.f${fhour};   rcc8=$?
      ${COPYGB:?} -g"$grid" -k'4*-1  2 102   0' $g1 $x1 ${DATA}/srefllmslp.${pert}.grb.f${fhour};   rcc9=$?

      if [ $rcc1 -eq 134 -o $rcc2 -eq 134 -o $rcc3 -eq 134 -o $rcc4 -eq 134 -o $rcc5 -eq 134 -o \
           $rcc6 -eq 134 -o $rcc7 -eq 134 -o $rcc8 -eq 134 -o $rcc9 -eq 134 ]
      then
        set +x
        echo " "
        echo "FATAL ERROR:  $COPYGB interpolation of sref data.  We will stop execution because"
        echo "!!! some variables may have been copied okay, while some obviously have not, "
        echo "!!! and that could lead to unreliable results from the tracker.  Check to make"
        echo "!!! sure you've allocated enough memory for this job.  Exiting...."
        echo " "
        set -x
        err_exit "FAILED ${jobid} - ERROR INTERPOLATING SREF DATA IN TRACKER SCRIPT - ABNORMAL EXIT"
      fi

      cat ${DATA}/srefllu850.${pert}.grb.f${fhour}   ${DATA}/srefllu700.${pert}.grb.f${fhour} \
          ${DATA}/srefllu500.${pert}.grb.f${fhour}   ${DATA}/srefllz850.${pert}.grb.f${fhour} \
          ${DATA}/srefllz700.${pert}.grb.f${fhour}   ${DATA}/srefllmslp.${pert}.grb.f${fhour} \
          ${DATA}/srefllav850.${pert}.grb.f${fhour}  ${DATA}/srefllav700.${pert}.grb.f${fhour} \
          ${DATA}/srefllu10m.${pert}.grb.f${fhour} \
          >>${DATA}/sref${pert}gribfile.${PDY}${cyc}

    done

    ${GRBINDEX:?} ${DATA}/sref${pert}gribfile.${PDY}${cyc} ${DATA}/sref${pert}ixfile.${PDY}${cyc}
    export err=$?; err_chk
    gribfile=${DATA}/sref${pert}gribfile.${PDY}${cyc}
    ixfile=${DATA}/sref${pert}ixfile.${PDY}${cyc}
       
fi

# ------------------------------
#   Process UKMET, if selected
# ------------------------------
if [ ${model} -eq 3 ]
then
 
  if [ -s ${DATA}/ukmetgribfile.${PDY}${cyc} ]
  then
    rm ${DATA}/ukmetgribfile.${PDY}${cyc}
  fi

  for fhour in ${fcsthrs}
  do
    ukfile=${ukmetdir}/${ukmetgfile}${fhour}${ukmetgfileb}
    
    let attempts=1
    while [ $attempts -le 30 ]; do
      if [ -s $ukfile ]; then
        break
      else
        sleep 60
        let attempts=attempts+1
      fi
    done
    if [ $attempts -gt 30 ] && [ ! -s $ukfile ]; then
      err_exit "$ukfile still not available after waiting 30 minutes... exiting"
    fi

    ${WGRIB:?} -s $ukfile >ukmet.ix
    export err=$?; err_chk

    for parm in ${wgrib_uk_hires_parmlist}
    do
      grep "${parm}" ukmet.ix | ${WGRIB:?} -s $ukfile -i -grib -append \
                              -o ${DATA}/ukmetgribfile.${PDY}${cyc}
    done

  done

  ${GRBINDEX:?} ${DATA}/ukmetgribfile.${PDY}${cyc} ${DATA}/ukmetixfile.${PDY}${cyc}
  export err=$?; err_chk
  gribfile=${DATA}/ukmetgribfile.${PDY}${cyc}
  ixfile=${DATA}/ukmetixfile.${PDY}${cyc}

fi  

set +x
echo "TIMING: Time in extrkr.sh after gribcut for pert= $pert is `date`"
set -x

#------------------------------------------------------------------------#
#                         Now run the tracker                            #
#------------------------------------------------------------------------#
set +x
echo " "
echo " -----------------------------------------------"
echo "           NOW EXECUTING TRACKER......"
echo " -----------------------------------------------"
echo " "
set -x

ist=1
while [ $ist -le 15 ]
do
  if [ ${stormflag[${ist}]} -ne 1 ]
  then
    set +x; echo "Storm number $ist NOT selected for processing"; set -x
  else
    set +x; echo "Storm number $ist IS selected for processing...."; set -x
  fi
  let ist=ist+1
done

# Load the forecast hours for this particular model into an array 
# that will be passed into the executable via a namelist....

set -A fh $fcsthrs

namelist=${DATA}/input.${atcfout}.${PDY}${cyc}
ATCFNAME=` echo "${atcfname}" | tr '[a-z]' '[A-Z]'`
  
echo -n "&datein inp%byy=${syy},inp%bmm=${smm},inp%bdd=${sdd},"    >${namelist}
echo    "        inp%bhh=${shh},inp%model=${model}/"              >>${namelist}
echo -n "&stormlist stswitch = ${stormflag[1]},${stormflag[2]},"  >>${namelist}
echo -n " ${stormflag[3]},${stormflag[4]},${stormflag[5]},"       >>${namelist}
echo -n " ${stormflag[6]},${stormflag[7]},${stormflag[8]},"       >>${namelist}
echo -n " ${stormflag[9]},${stormflag[10]},${stormflag[11]},"     >>${namelist}
echo -n " ${stormflag[12]},${stormflag[13]},${stormflag[14]},"    >>${namelist}
echo    " ${stormflag[15]}/"                                      >>${namelist}
echo -n "&fhlist itmphrs = "                                      >>${namelist}
for ifh in {0..63}; do
  echo -n "${fh[$ifh]:-99},"                                      >>${namelist}
done
echo    "${fh[64]:-99}/"                                          >>${namelist}
echo    "&atcfinfo atcfnum=${atcfnum},atcfname='${ATCFNAME}'/"    >>${namelist}

export pgm=gettrk_g1
. prep_step

# Input files
export FORT11=${gribfile}
export FORT12=${DATA}/vitals.upd.${atcfout}.${PDY}${shh}
export FORT31=${ixfile}

# Output files
export FORT61=${DATA}/trak.${atcfout}.all.${PDY}${cyc}
export FORT62=${DATA}/trak.${atcfout}.atcf.${PDY}${cyc}
export FORT63=${DATA}/trak.${atcfout}.radii.${PDY}${cyc}
export FORT64=${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc}


msg="$pgm start for $atcfout at ${cyc}z"
postmsg "$jlogfile" "$msg"

${EXECens_tracker}/gettrk_g1 <${namelist}
gettrk_rcc=$?

if [ ${gettrk_rcc} -ne 0 ]; then
  set +x
  echo " "
  echo "FATAL ERROR:  An error occurred while running gettrk.x, "
  echo "!!! which is the program that actually gets the track."
  echo "!!! Return code from gettrk.x = ${gettrk_rcc}"
  echo "!!! model= ${atcfout}, forecast initial time = ${PDY}${cyc}"
  echo " "
  set -x
  err_exit "FAILED ${jobid} - ERROR RUNNING gettrk_g1 IN TRACKER SCRIPT- ABNORMAL EXIT"
fi

set +x
echo "TIMING: Time in extrkr.sh after gettrk for pert= $pert is `date`"
set -x

#--------------------------------------------------------------#
# Now copy the output track files to different directories
#--------------------------------------------------------------#

set +x
echo " "
echo " -----------------------------------------------"
echo "    NOW COPYING OUTPUT TRACK FILES TO COM"
echo " -----------------------------------------------"
echo " "
set -x

# Copy atcf files to NHC archives. We'll use Steve Lord's original script,
# distatcf.sh, to do this, and that script requires the input atcf file to
# have the name "attk126", so first copy the file to that name, then call
# the distatcf.sh script.  After that's done, then copy the full 0-72h
# track into the /com/hur/prod/global track archive file.

if [ "$SENDCOM" = 'YES' ]
then

  glatuxarch=${glatuxarch:-${gltrkdir}/tracks.atcfunix.${syy}}
  cat ${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc}  >>${glatuxarch}

  if [ ${cmodel} = 'gfdl' ]
  then
    cp ${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc} ${COMOUT}/${stormenv}.${PDY}${cyc}.trackeratcfunix
  else
    cp ${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc} ${COMOUT}/${atcfout}.t${cyc}z.cyclone.trackatcfunix
  fi

  # ukmet only has 12 hours interval, not alert - 02/02/2018
  #if [ "$SENDDBN" = 'YES' ]
  #then
  #  if [ ${cmodel} = 'ukmet' ]
  #  then
  #    $DBNROOT/bin/dbn_alert MODEL ENS_TRACKER $job ${COMOUT}/${atcfout}.t${cyc}z.cyclone.trackatcfunix
  #  fi
  #fi

# ------------------------------------------
# Cat atcfunix files to storm trackers files
# ------------------------------------------
#
# We need to parse apart the atcfunix file and distribute the forecasts to
# the necessary directories.  To do this, first sort the atcfunix records
# by forecast hour (k6), then sort again by ocean basin (k1), storm number (k2)
# and then quadrant radii wind threshold (k12).  Once you've got that organized
# file, break the file up by putting all the forecast records for each storm
# into a separate file.  Then, for each file, find the corresponding atcfunix
# file in the storm trackers directory and dump the atcfunix records for that storm
# in there.  NOTE: Only do this if the model run is NOT for the CMC or
# ECMWF ensemble.  The reason is that we do NOT want to write out the individual
# member tracks to the atcfunix file.  We only want to write out the ensemble
# mean track to the atcfunix file, and the mean track is calculated and written
# out in a separate script.

#  if [ $cmodel != 'ece' -a $cmodel != 'cens' -a $cmodel != gfs_enr ]; then
  if [ ${cmodel} = 'gfdl' ]
  then
    auxfile=${COMOUT}/${stormenv}.${PDY}${cyc}.trackeratcfunix
  else
    auxfile=${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc}
  fi

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

  if [ $ict -gt 0 ]
  then
    mct=0
    while [ $mct -lt $ict ]
    do
      let mct=mct+1
      at=` head -1 atcfunix_file.$mct | cut -c1-2 | tr '[A-Z]' '[a-z]'`
      NO=` head -1 atcfunix_file.$mct | cut -c5-6`

      if [ ! -d ${COMOUTatcf:?}/${at}${NO}${syyyy} ]
      then
        mkdir -p $COMOUTatcf/${at}${NO}${syyyy}
      fi
      cat atcfunix_file.$mct >>$COMOUTatcf/${at}${NO}${syyyy}/ncep_a${at}${NO}${syyyy}.dat
      set +x
      echo " "
      echo "+++ Adding records to  TPC ATCFUNIX directory: $COMOUTatcf/${at}${NO}${syyyy}/ncep_${at}${NO}${syyyy}"
      echo " "
      set -x
    done
  fi
fi
