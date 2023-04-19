#!/bin/ksh
export PS4=' + data_check_ukmet.sh line $LINENO: '
set -x

####################################
#------ data checking for each hour--------------------------
export filelist="AAT BBT CCT DDT EET FFT GGT HHT IIT JJT KKT \
                 QQT LLT TTT MMT UUT NNT VVT OOT 11T PPA 22T"
for nfile in $filelist; do

  ifile=${ukmetdcom}/GAB${cyc}${nfile}.GRB
  echo "ifile = $ifile"

  let attempts=1
  while [ $attempts -le 30 ]; do
     if [ -s $ifile ]; then
        break
     else
        sleep 60
        let attempts=attempts+1
     fi
  done
  if [ $attempts -gt 30 ] && [ ! -s $ifile ]; then
     set +x; echo " "
     echo "FATAL ERROR:  $ifile still not available after waiting 30 minutes... exiting"
     echo " "; set -x
     err_exit
  fi
done
