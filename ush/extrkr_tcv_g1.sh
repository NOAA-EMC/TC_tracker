#!/bin/ksh
export PS4=' + extrkr_tcv_g1.sh line $LINENO: '
set +x
##############################################################################
echo " "
echo "------------------------------------------------"
echo "xxxx - Track vortices in model GRIB output"
echo "------------------------------------------------"
#echo "History: Mar 1998 - Marchok - First implementation of this new script."
#echo "         Apr 1999 - Marchok - Modified to allow radii output file and"
#echo "                              to allow reading of 4-digit years from"
#echo "                              TC vitals file."
#echo "         Oct 2000 - Marchok - Fixed bugs: (1) copygb target grid scanning mode"
#echo "                              flag had an incorrect value of 64 (this prevented"
#echo "                              NAM, NGM and ECMWF from being processed correctly);" 
#echo "                              Set it to 0.  (2) ECMWF option was using the "
#echo "                              incorrect input date (today's date instead of "
#echo "                              yesterday's)."
#echo "         Jan 2001 - Marchok - Hours now listed in script for each model and "
#echo "                              passed into program.  Script included to process"
#echo "                              GFDL & Ensemble data.  Call to DBN included to "
#echo "                              pass data to OSO and the Navy.  Forecast length"
#echo "                              extended to 5 days for GFS & MRF."
#echo " "
echo "                    In the event of a crash, you can contact Tim "
echo "                    Marchok at GFDL at (609) 452-6534 or tpm@gfdl.gov"
echo " "
echo "Current time is: `date`"
echo " "
##############################################################################
set -x

loopnum=$1
cmodel=$2
pert=$3
DATA=$4

#init_flag=$5
# USE_OPER_VITALS=NO
# USE_OPER_VITALS=INIT_ONLY
USE_OPER_VITALS=YES

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
########################################

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
#                                   gdas, gfdl, ens (ncep ensemble))
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
#     archsyndir - Directory with syndir scripts/exec/fix 
#

qid=$$
#----------------------------------------------#
#   Get input date information                 #
#----------------------------------------------#

#export PDY=${PDY:-$1}
#export cyc=${cyc:-$2}
#export cmodel=${cmodel:-$3}
export jobid=${jobid:-testjob}
export SENDCOM=${SENDCOM:-NO}
export PHASEFLAG=y
export WCORE_DEPTH=1.0
#export PHASE_SCHEME=vtt
#export PHASE_SCHEME=cps
export PHASE_SCHEME=both
export STRUCTFLAG=n
export IKEFLAG=n

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

scc=`echo ${PDY} | cut -c1-2`
syy=`echo ${PDY} | cut -c3-4`
smm=`echo ${PDY} | cut -c5-6`
sdd=`echo ${PDY} | cut -c7-8`
shh=${cyc}
symd=`echo ${PDY} | cut -c3-8`
syyyy=`echo ${PDY} | cut -c1-4`
CENT=`echo ${PDY} | cut -c1-2`

#export archsyndir=${archsyndir:-${COMROOT}/arch/prod/syndat}
archsyndir=${archsyndir:-${COMINsyn:?}}

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
# While only 1 of these sets of directories and file name 
# templates is used during a particular run of this script, 
# "gfsvitdir" is used every time, because that is the directory 
# that contains the error-checked TC vitals file that Steve Lord 
# produces, and so it is included after the case statement.
#
# NOTE: The varible PDY is now defined within the J-Jobs that
# call this script.  Therefore there is no reason to do this
# here.
#
# NOTE: The script that processes the ECMWF data defines PDY as
# the current day, and in this script we need PDY to be 
# yesterday's date (for the ecmwf ONLY).  So instead, the ecmwf
# script will pass the variable PDYm1 to this script, and in the
# case statement below we change that to PDY.
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

  ecmwf) set +x; echo " "                                  ;
       echo " ++ operational ECMWF chosen"                 ;
       echo " "; set -x                                    ;
#       ecmwfdir=${ecmwfdir:-${DCOMROOT}/us007003/${PDY}/wgrbbul/ecmwf};
       ecmwfdir=${ecmwfdir:-${DCOM:?}}                     ;
       vit_incr=6
       fcstlen=6                                           ;
       fcsthrs=$(seq -f%02g -s' ' 0 $vit_incr $fcstlen)    ;
       atcfnum=19                                          ;
       atcfname="emx "                                     ;
       atcfout="emx"                                       ;
       rundescr="xxxx"                                     ;
       atcfdescr="xxxx"                                    ;
       file_sequence="onebig"                              ;
       mslpthresh=0.0015                                   ;
       v850thresh=1.5000                                   ;
       modtyp='global'                                     ;
       lead_time_units='hours'                             ;
       model=4                                             ;;

  ukmet) set +x; echo " "                                    ;
       echo " ++ operational UKMET global model chosen" ;
       echo " "; set -x                                    ;
       ukmetdir=${ukmetdir:-${COMINukmet:?}}               ;
       ukmetgfile=pgbf                                     ;
       ukmetgfileb=.ukm.${PDY}${cyc}                       ;

       vit_incr=6
       fcstlen=6                                           ;
#       fcsthrs=$(seq -f%03g -s' ' 0 $vit_incr $fcstlen)    ;
       fcsthrs=" 00 06"                                    ;
       atcfnum=17                                          ;
       atcfname="ukx "                                     ;
       atcfout="ukx"                                       ;
       modtyp='global'                                     ;
       rundescr="xxxx"                                     ;
       atcfdescr="xxxx"                                    ;
       file_sequence="onebig"                              ;
       mslpthresh=0.0015                                   ;
       v850thresh=1.5000                                   ;
       lead_time_units='hours'                             ;
       model=3                                            ;;

  *) msg="FATAL ERROR:  Model $cmodel is not recognized."  ;
     echo "$msg"; postmsg $jlogfile "$msg"                 ;
     err_exit "FAILED ${jobid} -- UNKNOWN cmodel IN TRACKER SCRIPT - ABNORMAL EXIT";;

esac

if [ ${PHASEFLAG} = 'y' ]; then

wgrib_parmlist="UGRD:850 UGRD:700 UGRD:500 UGRD:200 VGRD:850 VGRD:700 VGRD:500 VGRD:200 SurfaceU SurfaceV PRMSL HGT:925 HGT:850 HGT:700 HGT:500 HGT:250 TMP:500 TMP:250 RH:500"
wgrib_uk_hires_parmlist="UGRD:850 UGRD:700 UGRD:500 UGRD:200 VGRD:850 VGRD:700 VGRD:500 VGRD:200 UGRD:sfc VGRD:sfc PRMSL:MSL HGT:925 HGT:850 HGT:700 HGT:500 HGT:400 HGT:300 TMP:500 TMP:400 TMP:300 RH:500"
wgrib_ec_hires_parmlist=" GH:850 GH:700 U:850 U:700 U:500 U:200 V:850 V:700 V:500 V:200 10U:sfc 10V:sfc MSL:sfc GH:300 GH:400 GH:500 GH:925 T:300 T:400 T:500 R:500"

else
  wgrib_parmlist=" HGT:850 HGT:700 UGRD:850 UGRD:700 UGRD:500 VGRD:850 VGRD:700 VGRD:500 SurfaceU SurfaceV ABSV:850 ABSV:700 PRMSL "
  wgrib_uk_hires_parmlist=' HGT:850 HGT:700 UGRD:850 UGRD:700 UGRD:500 VGRD:850 VGRD:700 VGRD:500 UGRD:sfc VGRD:sfc ABSV:850 ABSV:700 PRMSL:MSL '
  wgrib_ec_hires_parmlist=" GH:850 GH:700 U:850 U:700 U:500 V:850 V:700 V:500 10U:sfc 10V:sfc MSL:sfc"

fi

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
# UPDATE 3/27/09 MARCHOK: The SREF is run at off-synoptic times
#   (03,09,15,21Z).  There are no tcvitals issued at these offtimes,
#   so the updating of the "old" tcvitals is critical for running
#   the tracker on SREF.  For updating the old tcvitals for SREF,
#   we need to look 3h back, not 6h as for the other models that
#   run at synoptic times.
#--------------------------------------------------------------#

old_ymdh=` ${NDATE:?} -${vit_incr} ${PDY}${cyc}`
old_4ymd=` echo ${old_ymdh} | cut -c1-8`
old_ymd=` echo ${old_ymdh} | cut -c3-8`
old_hh=`  echo ${old_ymdh} | cut -c9-10`
old_str="${old_ymd} ${old_hh}00"

future_ymdh=` ${NDATE:?} ${vit_incr} ${PDY}${cyc}`
future_4ymd=` echo ${future_ymdh} | cut -c1-8`
future_ymd=` echo ${future_ymdh} | cut -c3-8`
future_hh=`  echo ${future_ymdh} | cut -c9-10`
future_str="${future_ymd} ${future_hh}00"

if [ ${modtyp} = 'global' ]
then
#  synvitdir=${COMROOT}/gfs/prod/gfs.${PDY}
  synvitdir=${COMINgfs:?}/${cyc}
  synvitfile=gfs.t${cyc}z.syndata.tcvitals.tm00
#  synvitold_dir=${COMROOT}/gfs/prod/gfs.${old_4ymd}
  synvitold_dir=${synvitdir%.*}.${old_4ymd}/${old_hh}
  synvitold_file=gfs.t${old_hh}z.syndata.tcvitals.tm00
#  synvitfuture_dir=${COMROOT}/gfs/prod/gfs.${future_4ymd}
  synvitfuture_dir=${synvitdir%.*}.${future_4ymd}/${future_hh}
  synvitfuture_file=gfs.t${future_hh}z.syndata.tcvitals.tm00
else
#  synvitdir=${COMROOT}/nam/prod/nam.${PDY}
  synvitdir=${COMINnam:?}
  synvitfile=nam.t${cyc}z.syndata.tcvitals.tm00
#  synvitold_dir=${COMROOT}/nam/prod/nam.${old_4ymd}
  synvitold_dir=${synvitdir%.*}.${old_4ymd}
  synvitold_file=nam.t${old_hh}z.syndata.tcvitals.tm00
#  synvitfuture_dir=${COMROOT}/nam/prod/nam.${future_4ymd}
  synvitfuture_dir=${synvitdir%.*}.${future_4ymd}
  synvitfuture_file=nam.t${future_hh}z.syndata.tcvitals.tm00
fi

set +x
echo " "
echo "              -----------------------------"
echo " "
echo " Now sorting and updating the TC Vitals file.  Please wait...."
echo " "
set -x

current_str="${symd} ${cyc}00"

if [ -s ${synvitdir}/${synvitfile} -o\
     -s ${synvitold_dir}/${synvitold_file} -o\
     -s ${synvitfuture_dir}/${synvitfuture_file} ]
then
  grep "${old_str}" ${synvitold_dir}/${synvitold_file}        \
                  >${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
  grep "${current_str}"  ${synvitdir}/${synvitfile}                  \
                 >>${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
  grep "${future_str}" ${synvitfuture_dir}/${synvitfuture_file}  \
                 >>${DATA}/tmpsynvit.${atcfout}.${PDY}${cyc}
else
  set +x
  echo " "
  echo " There is no (synthetic) TC vitals file for ${cyc}z in ${synvitdir},"
  echo " nor is there a TC vitals file for ${old_hh}z in ${synvitold_dir}."
  echo " nor is there a TC vitals file for ${future_hh}z in ${synvitfuture_dir},"
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
# UPDATE 5/12/98 MARCHOK: awk logic is added to screen NHC 
#   vitals such as "91L NAMELESS" or "89E NAMELESS", since TPC 
#   does not want tracks for such storms.

grep "${old_str}" ${archsyndir}/syndat_tcvitals.${CENT}${syy}   | \
      grep -v TEST | awk 'substr($0,6,1) !~ /8/ {print $0}' \
      >${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}
grep "${current_str}"  ${archsyndir}/syndat_tcvitals.${CENT}${syy}   | \
      grep -v TEST | awk 'substr($0,6,1) !~ /8/ {print $0}' \
      >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}
grep "${future_str}" ${archsyndir}/syndat_tcvitals.${CENT}${syy} | \
      grep -v TEST | awk 'substr($0,6,1) !~ /8/ {print $0}' \
      >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}

#J.Peng----2012-05-03---for genesis tc vitals--------------------
#export COMINgenvit=/global/save/wx20jp/genesis_vital_${syyyy}
#grep "${current_str}"  ${COMINgenvit}/gen_tc.vitals.gfs.gfso.2012 | \
#      grep -v TEST | awk 'substr($0,6,1) !~ /8/ {print $0}' \
#      >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}

#PRODTEST#
#PRODTEST# Use the next couple lines to test the tracker on the SP.
#PRODTEST# These next couple lines use data from a test TC Vitals file that 
#PRODTEST# I generate.  When you are ready to test this system, call me and
#PRODTEST# I'll create one for the current day, and then uncomment the next
#PRODTEST# couple lines in order to access the test vitals file.
#
#ttrkdir=/global/save/wx20tm/trak/prod/data
#ttrkdir=/global/save/wx20tm/trak/para/scripts
#grep "${current_str}" ${ttrkdir}/tcvit.01l >>${DATA}/tmprawvit.${atcfout}.${PDY}${cyc}


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

#if [ ${cmodel} = 'gfdl' ]; then
##   grep -i ${stormid} ${COMIN}/${ATCFNAME}.vitals.${syy}${smm}${sdd}${shh} >${DATA}/tmpvit
##   mv ${DATA}/tmpvit ${DATA}/vitals.${atcfout}.${PDY}${cyc}
#echo " "
#echo "!!! ERROR:  TAKE THE COMMENTS OUT OF HERE BEFORE IMPLEMENTATION    AAAA"
#echo "!!! AND TAKE OUT THESE NEXT 2 LINES AS WELL............................"
#echo " "
#grep -i ${stormid} ${DATA}/vitals.${atcfout}.${PDY}${cyc} >${DATA}/tmpvit
#mv  ${DATA}/tmpvit ${DATA}/vitals.${atcfout}.${PDY}${cyc}
#fi

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

oldymdh=` ${NDATE:?} -${vit_incr} ${PDY}${cyc}`
oldyy=`echo ${oldymdh} | cut -c3-4`
oldmm=`echo ${oldymdh} | cut -c5-6`
olddd=`echo ${oldymdh} | cut -c7-8`
oldhh=`echo ${oldymdh} | cut -c9-10`
oldymd=${oldyy}${oldmm}${olddd}

futureymdh=` ${NDATE:?} 6 ${PDY}${cyc}`
futureyy=`echo ${futureymdh} | cut -c3-4`
futuremm=`echo ${futureymdh} | cut -c5-6`
futuredd=`echo ${futureymdh} | cut -c7-8`
futurehh=`echo ${futureymdh} | cut -c9-10`
futureymd=${futureyy}${futuremm}${futuredd}

echo "&datenowin   dnow%yy=${syy}, dnow%mm=${smm},"       >${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "             dnow%dd=${sdd}, dnow%hh=${cyc}/"      >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "&dateoldin   dold%yy=${oldyy}, dold%mm=${oldmm},"    >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "             dold%dd=${olddd}, dold%hh=${oldhh}/"    >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "&datefuturein  dfuture%yy=${futureyy}, dfuture%mm=${futuremm},"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "               dfuture%dd=${futuredd}, dfuture%hh=${futurehh}/"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}
echo "&hourinfo  vit_hr_incr=${vit_incr}/"  >>${DATA}/suv_input.${atcfout}.${PDY}${cyc}

numvitrecs=`cat ${DATA}/vitals.${atcfout}.${PDY}${cyc} | wc -l`
if [ ${numvitrecs} -eq 0 ]
then

  if [ ${trkrtype} = 'tracker' ]
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

fi

# For tcgen cases, filter to use only vitals from the ocean 
# basin of interest....
#J.Peng----2012-04-13-------------------------------------
#if [ ${trkrtype} = 'tcgen' ]
#  then

#  if [ ${numvitrecs} -gt 0 ]
#  then
    
#    fullvitfile=${DATA}/vitals.${atcfout}.${PDY}${cyc}
#    cp $fullvitfile ${DATA}/vitals.all_basins.${atcfout}.${PDY}${cyc}
#    basin=` echo $regtype | cut -c1-2`

#    if [ ${basin} = 'al' ]; then
#      cat $fullvitfile | awk '{if (substr($0,8,1) == "L") print $0}' |
#               >${DATA}/vitals.tcgen_al_only.${atcfout}.${PDY}${cyc}
#      cp ${DATA}/vitals.tcgen_al_only.${atcfout}.${PDY}${cyc} \
#         ${DATA}/vitals.${atcfout}.${PDY}${cyc}
#    fi
#    if [ ${basin} = 'ep' ]; then
#      cat $fullvitfile | awk '{if (substr($0,8,1) == "E") print $0}' |
#               >${DATA}/vitals.tcgen_ep_only.${atcfout}.${PDY}${cyc}
#      cp ${DATA}/vitals.tcgen_ep_only.${atcfout}.${PDY}${cyc} \
#         ${DATA}/vitals.${atcfout}.${PDY}${cyc}
#    fi
#    if [ ${basin} = 'wp' ]; then
#      cat $fullvitfile | awk '{if (substr($0,8,1) == "W") print $0}' |
#               >${DATA}/vitals.tcgen_wp_only.${atcfout}.${PDY}${cyc}
#      cp ${DATA}/vitals.tcgen_wp_only.${atcfout}.${PDY}${cyc} \
#         ${DATA}/vitals.${atcfout}.${PDY}${cyc}
#    fi

#    cat ${DATA}/vitals.${atcfout}.${PDY}${cyc}

#  fi
    
#fi
#J.Peng----2012-04-13-------------------------------------

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

#Added by J.Peng----2012-04-12----------------------------------------------
numvitrecs=`cat ${DATA}/vitals.${atcfout}.${PDY}${cyc} | wc -l`
#-----------------------------------------------------------------
#J.Peng----2012-05-04--do not need this for TCvitals----
#numvitrecs=0

if [ ${numvitrecs} -gt 0 ]
then
  export pgm=supvit_g2
  . prep_step

  # Input file
  export FORT31=${DATA}/vitals.${atcfout}.${PDY}${cyc}

  # Output file
  export FORT51=${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}

  msg="$pgm start for $atcfout at ${cyc}z"
  postmsg "$jlogfile" "$msg"

  ${EXECens_tracker}/supvit_g2 <${DATA}/suv_input.${atcfout}.${PDY}${cyc}
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
    err_exit "FAILED ${jobid} - ERROR RUNNING supvit_g2 IN TRACKER SCRIPT- ABNORMAL EXIT"
  fi

else
#Added by J.Peng----2012-04-12----------------------------------------------
  rm -f ${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}

  touch ${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}

fi

#-----------------------------------------------------------------
# In this section, check to see if the user requested the use of 
# operational TC vitals records for the initial time only.  This 
# option might be used for a retrospective medium range forecast
# in which the user wants to initialize with the storms that are
# currently there, but then let the model do its own thing for 
# the next 10 or 14 days....


if [ ${USE_OPER_VITALS} = 'INIT_ONLY' ]; then

  if [ ${init_flag} = 'yes' ]; then
    set +x
    echo " "
    echo "NOTE: User has requested that operational historical TC vitals be used,"
    echo "      but only for the initial time, which we are currently at."
    echo " "
    set -x
  else
    set +x
    echo " "
    echo "NOTE: User has requested that operational historical TC vitals be used,"
    echo "      but only for the initial time, which we are now *PAST*."
    echo " "
    set -x
    >${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}
  fi
    
elif [ ${USE_OPER_VITALS} = 'NO' ]; then
    
  set +x
  echo " "
  echo "NOTE: User has requested that historical vitals not be used...."
  echo " "
  set -x
  >${DATA}/vitals.upd.${atcfout}.${PDY}${cyc}
    
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
  if [ ${trkrtype} = 'tracker' ]
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


#---------------------------------------------------------------#
#
#    --------  "Genesis" Vitals processing   --------
#
# May 2006:  This entire genesis tracking system is being
# upgraded to more comprehensively track and categorize storms.
# One thing that has been missing from the tracking system is
# the ability to keep track of storms from one analysis cycle
# to the next.  That is, the current system has been very
# effective at tracking systems within a forecast, but we have
# no methods in place for keeping track of storms across
# difference initial times.  For example, if we are running
# the tracker on today's 00z GFS analysis, we will get a
# position for various storms at the analysis time.  But then
# if we go ahead and run again at 06z, we have no way of
# telling the tracker that we know about the 00z position of
# this storm.  We now address that problem by creating
# "genesis" vitals, that is, when a storm is found at an
# analysis time, we not only produce "atcfunix" output to
# detail the track & intensity of a found storm, but we also
# produce a vitals record that will be used for the next
# run of the tracker script.  These "genesis vitals" records
# will be of the format:
#
#  YYYYMMDDHH_AAAH_LLLLX_TYP
#
#    Where:
#
#      YYYYMMDDHH = Date the storm was FIRST identified
#                   by the tracker.
#             AAA = Abs(Latitude) * 10; integer value
#               H = 'N' for norther hem, 'S' for southern hem
#            LLLL = Abs(Longitude) * 10; integer value
#               X = 'E' for eastern hem, 'W' for western hem
#             TYP = Tropical cyclone storm id if this is a
#                   tropical cyclone (e.g., "12L", or "09W", etc).
#                   If this is one that the tracker instead "Found
#                   On the Fly (FOF)", we simply put those three
#                   "FOF" characters in there.
#J.Peng----2012-04-12--------
#COMINgenvit=/global/save/wx20tm/gen/scripts
#COMINgenvit=/ensemble/save/Jiayi.Peng/genesis_vital_${syyyy}
genvitfile=${COMINgenvit}/genesis.vitals.${cmodel}.${atcfout}.${CENT}${syy}
touch ${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc}

if [ -f $genvitfile ]; then
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
  
  set +x
  echo " "
  echo " d6ago_str=    --->${d6ago_str}<---"
  echo " current_str=  --->${current_str}<---"
  echo " d6ahead_str=  --->${d6ahead_str}<---"
  echo " "
  #echo " Listing and contents of ${genvitfile} follow "
  #echo " for the times 6h ago, current and 6h ahead:"
  #echo " "
  set -x
  
  #J.Peng----2012-04-11-----
  ##ls -la ${COMINgenvit}/genesis.vitals.${atcfout}.${CENT}${syy}
  ##cat ${COMINgenvit}/genesis.vitals.${atcfout}.${CENT}${syy}
  #ls -la ${COMINgenvit}/genesis.vitals.${cmodel}.${atcfout}.${CENT}${syy}
  #cat ${COMINgenvit}/genesis.vitals.${cmodel}.${atcfout}.${CENT}${syy}
  
  grep "${d6ago_str}"   ${genvitfile} >>${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc}
  grep "${current_str}" ${genvitfile} >>${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc}
  grep "${d6ahead_str}" ${genvitfile} >>${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc}

  num_gen_vits=`cat ${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc} | wc -l`
else
  echo "WARNING: Genesis Vitals from previous run(s) not found!"
fi

echo "&datenowin   dnow%yy=${syyyy}, dnow%mm=${smm},"       >${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
echo "             dnow%dd=${sdd}, dnow%hh=${cyc}/"        >>${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
echo "&date6agoin  d6ago%yy=${syyyy6}, d6ago%mm=${smm6},"  >>${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
echo "             d6ago%dd=${sdd6}, d6ago%hh=${shh6}/"    >>${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
echo "&date6aheadin  d6ahead%yy=${syyyyp6}, d6ahead%mm=${smmp6}," >>${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
echo "               d6ahead%dd=${sddp6}, d6ahead%hh=${shhp6}/"  >>${DATA}/sgv_input.${atcfout}.${PDY}${cyc}

#J.Peng----2012-05-04--- need this for TC vitals------------------
num_gen_vits=0

if [ ${num_gen_vits} -gt 0 ]
then
  export pgm=supvit_gen
  . prep_step

  # Input file
  export FORT31=${DATA}/genvitals.${cmodel}.${atcfout}.${PDY}${cyc}

  # Output file
  export FORT51=${DATA}/genvitals.upd.${cmodel}.${atcfout}.${PDY}${cyc}

  msg="$pgm start for $atcfout at ${cyc}z"
  postmsg "$jlogfile" "$msg"

  ${EXECens_tracker}/supvit_gen <${DATA}/sgv_input.${atcfout}.${PDY}${cyc}
  sgvrcc=$?

  if [ ${sgvrcc} -eq 0 ]
  then
    msg="$pgm end for $atcfout at ${cyc}z completed normally"
    postmsg "$jlogfile" "$msg"
  else
    set +x
    echo " "
    echo "FATAL ERROR:  An error occurred while running supvit_gen, "
    echo "!!! which is the program that updates the genesis vitals file."
    echo "!!! Return code from supvit_gen = ${sgvrcc}"
    echo "!!! model= ${atcfout}, forecast initial time = ${PDY}${cyc}"
    echo " "
    set -x
    err_exit "FAILED ${jobid} - ERROR RUNNING SUPVIT_GEN IN TRACKER SCRIPT- ABNORMAL EXIT"
  fi
    
else
  rm -f ${DATA}/genvitals.upd.${cmodel}.${atcfout}.${PDY}${cyc} 
  touch ${DATA}/genvitals.upd.${cmodel}.${atcfout}.${PDY}${cyc}
fi


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

  if [ $loopnum -eq 1 ] 
  then

    if [ -s ${DATA}/ecgribfile.${PDY}${cyc} ]
    then
      rm ${DATA}/ecgribfile.${PDY}${cyc}
    fi

    immddhh=`echo ${PDY}${cyc}| cut -c5-`
    ict=0

    for fhour in ${fcsthrs}
    do
    
      fhr=${fhour}
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

  fi

  if [ $loopnum -eq 1 ]; then

    ${GRBINDEX:?} ${DATA}/ecgribfile.${PDY}${cyc} ${DATA}/ecixfile.${PDY}${cyc}
    export err=$?; err_chk

    catfile=${DATA}/${cmodel}.${PDY}${cyc}.catfile
    >${catfile}

    for fhour in ${fcsthrs}
    do

      set +x
      echo " "
      echo "Date in interpolation for fhour= $fhour before = `date`"
      echo " "
      set -x

      gfile=${DATA}/ecgribfile.${PDY}${cyc}
      ifile=${DATA}/ecixfile.${PDY}${cyc}
      ${GRBINDEX:?} $gfile $ifile
      export err=$?; err_chk

#J.Peng----2012-06-06---added for U-shear-----
      gparm=131
      ffile=${gfile}

      . prep_step

      # Input files
      namelist=${DATA}/ushear_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${ffile}
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}_ushear.${PDY}${cyc}.f${fhour}

      ${EXECens_tracker}/ushear_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to ushear_g1.x at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -ushear_g1.x-  AT LINE $LINENO - ABNORMAL EXIT"
      fi

      ushearfile=${DATA}/${cmodel}_ushear.${PDY}${cyc}.f${fhour}
      cat ${ushearfile} >>${catfile}
#J.Peng----2012-05-29---added for U-shear-----

#     ----------------------------------------------------
#     First, interpolate height data to get data from 
#     300 to 900 mb, every 50 mb....

      gparm=156

      . prep_step

      # Input files
      namelist=${DATA}/vint_input.${PDY}${cyc}.z
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${gfile}
      export FORT16=${FIXens_tracker}/ecmwf_hgt_levs.txt
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}.${PDY}${cyc}.z.f${fhour}

      ${EXECens_tracker}/vint_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to vint_g1.x for GPH at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -vint_g1.x-  for GPH AT LINE $LINENO - ABNORMAL EXIT"
      fi

#     ----------------------------------------------------
#     Now interpolate temperature data to get data from
#     300 to 500 mb, every 50 mb....

      gparm=130

      . prep_step

      # Input files
      namelist=${DATA}/vint_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${gfile}
      export FORT16=${FIXens_tracker}/ecmwf_tmp_levs.txt
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}

      ${EXECens_tracker}/vint_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to vint_g1.x for T at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -vint_g1.x-  for T AT LINE $LINENO - ABNORMAL EXIT"
      fi

#     ----------------------------------------------------
#     Now average the temperature data that we just 
#     interpolated to get the mean 300-500 mb temperature...

      ffile=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}
      ifile=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}.i
      ${GRBINDEX:?} ${ffile} ${ifile}
      export err=$?; err_chk

      . prep_step

      # Input files
      namelist=${DATA}/tave_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${ffile}
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}_tave.${PDY}${cyc}.f${fhour}

      ${EXECens_tracker}/tave_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to tave_g1.x at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -tave_g1.x-  AT LINE $LINENO - ABNORMAL EXIT"
      fi

      tavefile=${DATA}/${cmodel}_tave.${PDY}${cyc}.f${fhour}
      zfile=${DATA}/${cmodel}.${PDY}${cyc}.z.f${fhour}
      cat ${zfile} ${tavefile} >>${catfile}

      set +x
      echo " "
      echo "Date in interpolation for fhour= $fhour after = `date`"
      echo " "
      set -x

    done

    cat ${catfile} >>${gfile}

  fi 

  ${GRBINDEX:?} ${DATA}/ecgribfile.${PDY}${cyc} ${DATA}/ecixfile.${PDY}${cyc}
  export err=$?; err_chk
  gribfile=${DATA}/ecgribfile.${PDY}${cyc}
  ixfile=${DATA}/ecixfile.${PDY}${cyc}

fi

# ------------------------------------------------------
#   Process UKMET hi-res deterministic, if selected
# ------------------------------------------------------
if [ ${model} -eq 3 ]
then

  if [ $loopnum -eq 1 ]
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

    set +x
    echo " "
    echo "Time after wgrib loop is `date`"
    echo " "
    set -x

    # Now run through the work to get data for phase checking....

    ${GRBINDEX:?} ${DATA}/ukmetgribfile.${PDY}${cyc} ${DATA}/ukmetixfile.${PDY}${cyc}
    export err=$?; err_chk

    catfile=${DATA}/${cmodel}.${PDY}${cyc}.catfile
    >${catfile}

    for fhour in ${fcsthrs}
    do

      set +x
      echo " "
      echo "Date in interpolation for fhour= $fhour before = `date`"
      echo " "
      set -x

      gfile=${DATA}/ukmetgribfile.${PDY}${cyc}
      ifile=${DATA}/ukmetixfile.${PDY}${cyc}
      ${GRBINDEX:?} $gfile $ifile
      export err=$?; err_chk

#J.Peng----2012-05-29---added for U-shear-----
      gparm=33
      ffile=${gfile}

      . prep_step
      # Input files
      namelist=${DATA}/ushear_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${ffile}
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}_ushear.${PDY}${cyc}.f${fhour}

      ${EXECens_tracker}/ushear_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to ushear_g1.x at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -ushear_g1.x-  AT LINE $LINENO - ABNORMAL EXIT"
      fi

      ushearfile=${DATA}/${cmodel}_ushear.${PDY}${cyc}.f${fhour}
      cat ${ushearfile} >>${catfile}
#J.Peng----2012-05-29---added for U-shear-----

#     ----------------------------------------------------
#     First, interpolate height data to get data from
#     300 to 900 mb, every 50 mb....

      gparm=7
      . prep_step
      # Input files
      namelist=${DATA}/vint_input.${PDY}${cyc}.z
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${gfile}
      export FORT16=${FIXens_tracker}/ukmet_hgt_levs.txt
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}.${PDY}${cyc}.z.f${fhour}

      ${EXECens_tracker}/vint_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to vint_g1.x for GPH at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -vint_g1.x-  for GPH AT LINE $LINENO - ABNORMAL EXIT"
      fi

#     ----------------------------------------------------
#     Now interpolate temperature data to get data from
#     300 to 500 mb, every 50 mb....

      gparm=11
      . prep_step

      # Input files
      namelist=${DATA}/vint_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${gfile}
      export FORT16=${FIXens_tracker}/ukmet_tmp_levs.txt
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}

      ${EXECens_tracker}/vint_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
        echo " "
        echo "FATAL ERROR in call to vint_g1.x for T at fhour= $fhour"
        echo "rcc= $rcc      EXITING.... "
        echo " "
        set -x
        err_exit "FAILED ${jobid} -vint_g1.x-  for T AT LINE $LINENO - ABNORMAL EXIT"
      fi

#     ----------------------------------------------------
#     Now average the temperature data that we just
#     interpolated to get the mean 300-500 mb temperature...

      gparm=11
      ffile=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}
      ifile=${DATA}/${cmodel}.${PDY}${cyc}.t.f${fhour}.i
      ${GRBINDEX:?} ${ffile} ${ifile}
      export err=$?; err_chk

      . prep_step
      # Input files
      namelist=${DATA}/tave_input.${PDY}${cyc}
      echo "&timein ifcsthour=${fhour}, iparm=${gparm}/"  >${namelist}
      export FORT11=${ffile}
      export FORT31=${ifile}

      # Output file
      export FORT51=${DATA}/${cmodel}_tave.${PDY}${cyc}.f${fhour}

      ${EXECens_tracker}/tave_g1.x <${namelist}
      rcc=$?

      if [ $rcc -ne 0 ]; then
        set +x
	echo " "
	echo "FATAL ERROR in call to tave_g1.x at fhour= $fhour"
	echo "rcc= $rcc      EXITING.... "
	echo " "
	set -x
	err_exit "FAILED ${jobid} -tave_g1.x-  AT LINE $LINENO - ABNORMAL EXIT"
      fi

      tavefile=${DATA}/${cmodel}_tave.${PDY}${cyc}.f${fhour}
      zfile=${DATA}/${cmodel}.${PDY}${cyc}.z.f${fhour}
      cat ${zfile} ${tavefile} >>${catfile}

      set +x
      echo " "
      echo "Date in interpolation for fhour= $fhour after = `date`"
      echo " "
      set -x

    done  
    gfile=${DATA}/ukmetgribfile.${PDY}${cyc}
    cat ${catfile} >>${gfile}

  fi
  gribfile=${DATA}/ukmetgribfile.${PDY}${cyc}
  ixfile=${DATA}/ukmetixfile.${PDY}${cyc}
  ${GRBINDEX:?} ${gribfile} ${ixfile}
  export err=$?; err_chk

fi

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

if [ ! -s ${DATA}/last_fcst_hour.${atcfout}.${PDY}${cyc} ]
then
  for fhr in $fcsthrs; do
    if [ $fhr -ne 99 ]; then
      last_fcst_hour=$fhr
    fi
  done
  echo ${last_fcst_hour} >${DATA}/last_fcst_hour.${atcfout}.${PDY}${cyc}
fi

namelist=${DATA}/input.${atcfout}.${PDY}${cyc}
ATCFNAME=` echo "${atcfname}" | tr '[a-z]' '[A-Z]'`

export atcfymdh=${scc}${syy}${smm}${sdd}${shh}

contour_interval=100.0
write_vit=y

echo "&datein inp%bcc=${scc},inp%byy=${syy},inp%bmm=${smm},"      >${namelist}
echo "        inp%bdd=${sdd},inp%bhh=${shh},inp%model=${model}," >>${namelist}
echo "        inp%modtyp='${modtyp}',"                           >>${namelist}
echo "        inp%lt_units='${lead_time_units}',"                >>${namelist}
echo "        inp%file_seq='${file_sequence}',"                  >>${namelist}
echo "        inp%nesttyp='${nest_type}'/"                       >>${namelist}
echo "&atcfinfo atcfnum=${atcfnum},atcfname='${ATCFNAME}',"      >>${namelist}
echo "          atcfymdh=${atcfymdh}/"                           >>${namelist}
echo "&trackerinfo trkrinfo%westbd=${trkrwbd},"                  >>${namelist}
echo "      trkrinfo%eastbd=${trkrebd},"                         >>${namelist}
echo "      trkrinfo%northbd=${trkrnbd},"                        >>${namelist}
echo "      trkrinfo%southbd=${trkrsbd},"                        >>${namelist}
echo "      trkrinfo%type='${trkrtype}',"                        >>${namelist}
echo "      trkrinfo%mslpthresh=${mslpthresh},"                  >>${namelist}
echo "      trkrinfo%v850thresh=${v850thresh},"                  >>${namelist}
echo "      trkrinfo%gridtype='${modtyp}',"                      >>${namelist}
echo "      trkrinfo%contint=${contour_interval},"               >>${namelist}
echo "      trkrinfo%out_vit='${write_vit}'/"                    >>${namelist}
echo "&phaseinfo phaseflag='${PHASEFLAG}',"                      >>${namelist}
echo "           phasescheme='${PHASE_SCHEME}',"                 >>${namelist}
echo "           wcore_depth=${WCORE_DEPTH}/"                    >>${namelist}
echo "&structinfo structflag='${STRUCTFLAG}',"                   >>${namelist}
echo "            ikeflag='${IKEFLAG}'/"                         >>${namelist}
echo "&fnameinfo  gmodname='${atcfname}',"                       >>${namelist}
echo "            rundescr='${rundescr}',"                       >>${namelist}
echo "            atcfdescr='${atcfdescr}'/"                     >>${namelist}
echo "&verbose verb=3/"                                          >>${namelist}
echo "&waitinfo use_waitfor='n',"                                >>${namelist}
echo "          wait_min_age=10,"                                >>${namelist}
echo "          wait_min_size=100,"                              >>${namelist}
echo "          wait_max_wait=1800,"                             >>${namelist}
echo "          wait_sleeptime=5,"                               >>${namelist}
echo "          per_fcst_command=''/"                            >>${namelist}

export pgm=gettrk_gen_g1
. prep_step

export FORT11=${gribfile}
export FORT12=${DATA}/vitals.upd.${atcfout}.${PDY}${shh}
#export FORT13=${DATA}/genvitals.upd.${atcfout}.${PDY}${shh}
export FORT14=${DATA}/genvitals.upd.${cmodel}.${atcfout}.${PDY}${cyc}
export FORT15=${FIXens_tracker}/${cmodel}.genesis_leadtimes
export FORT31=${ixfile}

if [ ${trkrtype} = 'tracker' ]; then
  if [ ${atcfout} = 'gfdt' -o ${atcfout} = 'gfdl' -o \
       ${atcfout} = 'hwrf' -o ${atcfout} = 'hwft' ]; then
    export FORT61=${DATA}/trak.${atcfout}.all.${stormenv}.${PDY}${cyc}
    export FORT62=${DATA}/trak.${atcfout}.atcf.${stormenv}.${PDY}${cyc}
    export FORT63=${DATA}/trak.${atcfout}.radii.${stormenv}.${PDY}${cyc}
    export FORT64=${DATA}/trak.${atcfout}.atcfunix.${stormenv}.${PDY}${cyc}
    export FORT66=${DATA}/trak.${atcfout}.atcf_gen.${stormenv}.${PDY}${cyc}
    export FORT68=${DATA}/trak.${atcfout}.atcf_sink.${stormenv}.${PDY}${cyc}
    export FORT69=${DATA}/trak.${atcfout}.atcf_hfip.${stormenv}.${PDY}${cyc}
  else
    export FORT61=${DATA}/trak.${atcfout}.all.${PDY}${cyc}
    export FORT62=${DATA}/trak.${atcfout}.atcf.${PDY}${cyc}
    export FORT63=${DATA}/trak.${atcfout}.radii.${PDY}${cyc}
    export FORT64=${DATA}/trak.${atcfout}.atcfunix.${PDY}${cyc}
    export FORT66=${DATA}/trak.${atcfout}.atcf_gen.${PDY}${cyc}
    export FORT68=${DATA}/trak.${atcfout}.atcf_sink.${PDY}${cyc}
    export FORT69=${DATA}/trak.${atcfout}.atcf_hfip.${PDY}${cyc}
  fi
else
  export FORT61=${DATA}/trak.${atcfout}.all.${regtype}.${PDY}${cyc}
  export FORT62=${DATA}/trak.${atcfout}.atcf.${regtype}.${PDY}${cyc}
  export FORT63=${DATA}/trak.${atcfout}.radii.${regtype}.${PDY}${cyc}
  export FORT64=${DATA}/trak.${atcfout}.atcfunix.${regtype}.${PDY}${cyc}
  export FORT66=${DATA}/trak.${atcfout}.atcf_gen.${regtype}.${PDY}${cyc}
  export FORT68=${DATA}/trak.${atcfout}.atcf_sink.${regtype}.${PDY}${cyc}
  export FORT69=${DATA}/trak.${atcfout}.atcf_hfip.${regtype}.${PDY}${cyc}
fi

if [ ${atcfname} = 'aear' ]
then
  export FORT65=${DATA}/trak.${atcfout}.initvitl.${PDY}${cyc}
fi

if [ ${write_vit} = 'y' ]
then
  export FORT67=${DATA}/output_genvitals.${atcfout}.${PDY}${shh}
fi

if [ ${PHASEFLAG} = 'y' ]; then
  if [ ${atcfout} = 'gfdt' -o ${atcfout} = 'gfdl' -o \
       ${atcfout} = 'hwrf' -o ${atcfout} = 'hwft' ]; then
    export FORT71=${DATA}/trak.${atcfout}.cps_parms.${stormenv}.${PDY}${cyc}
  else
    export FORT71=${DATA}/trak.${atcfout}.cps_parms.${PDY}${cyc}
  fi
fi

if [ ${STRUCTFLAG} = 'y' ]; then
  if [ ${atcfout} = 'gfdt' -o ${atcfout} = 'gfdl' -o \
       ${atcfout} = 'hwrf' -o ${atcfout} = 'hwft' ]; then
    export FORT72=${DATA}/trak.${atcfout}.structure.${stormenv}.${PDY}${cyc}
    export FORT73=${DATA}/trak.${atcfout}.fractwind.${stormenv}.${PDY}${cyc}
    export FORT76=${DATA}/trak.${atcfout}.pdfwind.${stormenv}.${PDY}${cyc}
  else
    export FORT72=${DATA}/trak.${atcfout}.structure.${PDY}${cyc}
    export FORT73=${DATA}/trak.${atcfout}.fractwind.${PDY}${cyc}
    export FORT76=${DATA}/trak.${atcfout}.pdfwind.${PDY}${cyc}
  fi
fi

if [ ${IKEFLAG} = 'y' ]; then
  if [ ${atcfout} = 'gfdt' -o ${atcfout} = 'gfdl' -o \
       ${atcfout} = 'hwrf' -o ${atcfout} = 'hwft' ]; then
    export FORT74=${DATA}/trak.${atcfout}.ike.${stormenv}.${PDY}${cyc}
  else
    export FORT74=${DATA}/trak.${atcfout}.ike.${PDY}${cyc}
  fi
fi

if [ ${trkrtype} = 'midlat' -o ${trkrtype} = 'tcgen' ]; then
  export FORT77=${DATA}/trkrmask.${atcfout}.${regtype}.${PDY}${cyc}
fi

msg="$pgm start for $atcfout at ${cyc}z"
postmsg "$jlogfile" "$msg"

set +x
echo "+++ TIMING: BEFORE gettrk  ---> `date`"
set -x

ulimit -c unlimited

${EXECens_tracker}/gettrk_gen_g1 <${namelist}
gettrk_rcc=$?

set +x
echo "+++ TIMING: AFTER  gettrk  ---> `date`"
set -x

#--------------------------------------------------------------#
# Now copy the output track files to different directories
#--------------------------------------------------------------#

if [ ${gettrk_rcc} -eq 0 ]; then
  set +x
  echo " "
  echo " -----------------------------------------------"
  echo "    NOW COPYING OUTPUT TRACK FILES TO COM  "
  echo " -----------------------------------------------"
  echo " "
  set -x

  if [ -s ${DATA}/output_genvitals.${atcfout}.${PDY}${shh} ]; then
    if [ "$SENDCOM" = 'YES' ]; then
      cp ${DATA}/output_genvitals.${atcfout}.${PDY}${shh} ${COMOUTgenvit:?}/genesis.vitals.${cmodel}.${atcfout}.${CENT}${syy}
      #if [ "$SENDDBN" = 'YES' ]; then
      #  $DBNROOT/bin/dbn_alert ${cmodel^^} GENESIS $job ${COMOUTgenvit}/genesis.vitals.${cmodel}.${atcfout}.${CENT}${syy}
      #fi
    fi
  fi
  msg="$pgm end for $atcfout at ${cyc}z completed normally"
  postmsg "$jlogfile" "$msg"
else
  set +x
  echo " "
  echo "FATAL ERROR:  An error occurred while running gettrk_gen_g1, "
  echo "!!! which is the program that actually gets the track."
  echo "!!! Return code from gettrk_gen_g1 = ${gettrk_rcc}"
  echo "!!! model= ${atcfout}, forecast initial time = ${PDY}${cyc}"
  echo " "
  set -x
  err_exit "FAILED ${jobid} - ERROR RUNNING gettrk_gen_g1 IN TRACKER SCRIPT- ABNORMAL EXIT"
fi
