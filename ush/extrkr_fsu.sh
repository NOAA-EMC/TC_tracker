#!/bin/ksh
export PS4=' + extrkr_fsu.sh line $LINENO: '

set +x
##############################################################################
echo " "
echo "------------------------------------------------"
echo "         TC genesis Tracking from FSU         "
echo "                Models:GFS       "
echo "------------J.Peng DEC.11, 2019 ----------------"
echo "Current time is: `date`"
echo " "
##############################################################################
set -x

cmodel=$1
ymdh=$2
TRKDATA=$3
gfsdir=$4

msg="has begun for ${cmodel} at ${ymdh}z"
postmsg "$jlogfile" "$msg"

#cp $HOMEens_tracker/tclogg/genesis_guidance/model_config.cfg_bak $TRKDATA/model_config.cfg
#  creating $TRKDATA/model_config.cfg
#----------------------------------------------------
#[gfs]
#fname_template = /gpfs/dell1/nco/ops/com/gfs/prod/gfs.{date:%Y%m%d}/{date:%H}/gfs.t{date:%H}z.pgrb2.0p25.f{fhr:03}
# min_fhr = 0
# max_fhr = 120
# delta_fhr = 6
#---------------------------------------------------
cd $TRKDATA
#namelist=${TRKDATA}/model_config.cfg
#echo "[${cmodel}]"       >${namelist}
#echo "fname_template = ${gfsdir}/gfs.{date:%Y%m%d}/{date:%H}/gfs.t{date:%H}z.pgrb2.0p25.f{fhr:03}"          >>${namelist}

#unlink $HOMEens_tracker/tclogg/genesis_guidance/model_config.cfg
#ln -sf ${namelist} $HOMEens_tracker/tclogg/genesis_guidance/model_config.cfg

#export file_name=${gfsdir}/gfs.{date:%Y%m%d}/{date:%H}/gfs.t{date:%H}z.pgrb2.0p25.f{fhr:03}
export COMPONENT=${COMPONENT:-atmos}
export file_name=${gfsdir}/gfs.{date:%Y%m%d}/{date:%H}/${COMPONENT}/gfs.t{date:%H}z.pgrb2.0p25.f{fhr:03}
${BINens_tracker}/tclogg_track --date ${ymdh} --odir $TRKDATA --fname_template=${file_name}

#if [ "$SENDCOM" = 'YES' ]; then
#  cp -r ${TRKDATA}/tracker ${COMOUT}/.
#fi
