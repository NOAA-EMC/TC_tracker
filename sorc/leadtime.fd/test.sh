#------------------------
export TRKDATA=/gpfs/dell2/emc/modeling/noscrub/Jiayi.Peng/ens_tracker.v1.1.15.1/sorc/leadtime.fd
export FHMAX_CYCLONE=180
export FHOUT_CYCLONE=3
export cmodel=gfs
export PDY=20190729
export cyc=00
export EXECens_tracker=${TRKDATA} 
# Input files
namelist_4_fix=${TRKDATA}/namelist_input.${PDY}${cyc}
echo "&timein maxhrs=${FHMAX_CYCLONE},"       >${namelist_4_fix}
echo "        dthrs=${FHOUT_CYCLONE}/"       >>${namelist_4_fix}

# Output file
export FORT10=${TRKDATA}/${cmodel}.tracker_leadtimes

${EXECens_tracker}/leadtime <${namelist_4_fix}
