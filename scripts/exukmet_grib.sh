#!/bin/ksh
export PS4=' + ukmet_grib.sh line $LINENO: '

#--------------------------------------------------------------------------------
# Fanglin Yang    June 2014
#  merge ukm hires data in 8 patches into one global array at 1-deg resolution
#
# Jiayi Peng  05/31/2016
# Adopted into TC tracker/genesis package
# Jiayi Peng 11/14/2018
# Updated for MPMD run 
#--------------------------------------------------------------------------------
cd $DATA  
cp ${ukmetdcom}/GAB${cyc}* .

#J.Peng----11142018----split GRIB1 data---------------------------

rm -f GAB${cyc}JJT.GRB.ix GAB${cyc}KKT.GRB.ix GAB${cyc}PPA.GRB.ix
${WGRIB} -s GAB${cyc}JJT.GRB > GAB${cyc}JJT.GRB.ix
${WGRIB} -s GAB${cyc}KKT.GRB > GAB${cyc}KKT.GRB.ix
${WGRIB} -s GAB${cyc}PPA.GRB > GAB${cyc}PPA.GRB.ix

cp GAB${cyc}AAT.GRB pgbf00.ukmet.${PDY}${cyc}
cp GAB${cyc}BBT.GRB pgbf06.ukmet.${PDY}${cyc}
cp GAB${cyc}CCT.GRB pgbf12.ukmet.${PDY}${cyc}
cp GAB${cyc}DDT.GRB pgbf18.ukmet.${PDY}${cyc}
cp GAB${cyc}EET.GRB pgbf24.ukmet.${PDY}${cyc}
cp GAB${cyc}FFT.GRB pgbf30.ukmet.${PDY}${cyc}
cp GAB${cyc}GGT.GRB pgbf36.ukmet.${PDY}${cyc}
cp GAB${cyc}HHT.GRB pgbf42.ukmet.${PDY}${cyc}
cp GAB${cyc}IIT.GRB pgbf48.ukmet.${PDY}${cyc}

grep "54hr" GAB${cyc}JJT.GRB.ix | ${WGRIB} -s GAB${cyc}JJT.GRB -i -grib -append -o pgbf54.ukmet.${PDY}${cyc}
grep "60hr" GAB${cyc}JJT.GRB.ix | ${WGRIB} -s GAB${cyc}JJT.GRB -i -grib -append -o pgbf60.ukmet.${PDY}${cyc}

grep "66hr" GAB${cyc}KKT.GRB.ix | ${WGRIB} -s GAB${cyc}KKT.GRB -i -grib -append -o pgbf66.ukmet.${PDY}${cyc}
grep "72hr" GAB${cyc}KKT.GRB.ix | ${WGRIB} -s GAB${cyc}KKT.GRB -i -grib -append -o pgbf72.ukmet.${PDY}${cyc}

cp GAB${cyc}QQT.GRB pgbf78.ukmet.${PDY}${cyc}
cp GAB${cyc}LLT.GRB pgbf84.ukmet.${PDY}${cyc}
cp GAB${cyc}TTT.GRB pgbf90.ukmet.${PDY}${cyc}
cp GAB${cyc}MMT.GRB pgbf96.ukmet.${PDY}${cyc}
cp GAB${cyc}UUT.GRB pgbf102.ukmet.${PDY}${cyc}
cp GAB${cyc}NNT.GRB pgbf108.ukmet.${PDY}${cyc}
cp GAB${cyc}VVT.GRB pgbf114.ukmet.${PDY}${cyc}
cp GAB${cyc}OOT.GRB pgbf120.ukmet.${PDY}${cyc}
cp GAB${cyc}11T.GRB pgbf126.ukmet.${PDY}${cyc}

grep "132hr" GAB${cyc}PPA.GRB.ix | ${WGRIB} -s GAB${cyc}PPA.GRB -i -grib -append -o pgbf132.ukmet.${PDY}${cyc}
cp GAB${cyc}22T.GRB pgbf138.ukmet.${PDY}${cyc}
grep "144hr" GAB${cyc}PPA.GRB.ix | ${WGRIB} -s GAB${cyc}PPA.GRB -i -grib -append -o pgbf144.ukmet.${PDY}${cyc}

#-------------------------------------------------------
hrstring=" 00  06  12  18  24  30  36  42  48  54
           60  66  72  78  84  90  96 102 108 114
          120 126 132 138 144"

>trkr.cmdfile
for leadhr in ${hrstring}; do
  outfile=${DATA}/ukmetgrib.${leadhr}.out
  echo "${EXECukmet}/ukm_hires_merge pgbf${leadhr}.ukmet.${PDY}${cyc} pgbf${leadhr}.ukm.${PDY}${cyc} ${leadhr} 2>&1 >${outfile}" >>trkr.cmdfile
done

chmod u+x trkr.cmdfile
export MP_PGMMODEL=mpmd
export MP_CMDFILE=${DATA}/trkr.cmdfile

mac=`echo ${SITE}`
if [ $mac = TIDE -o $mac = GYRE ] ; then # For WCOSS
  machine=wcoss
  mpirun.lsf
elif [ $mac = LUNA -o $mac = SURGE ] ; then # For CRAY
  machine=cray
  ${APRUNTRACK} cfp ${MP_CMDFILE}
fi

cp pgb*.ukm.${PDY}${cyc} ${COMOUT}/.
