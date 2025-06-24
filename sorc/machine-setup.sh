# Create a test function for sh vs. bash detection.  The name is
# randomly generated to reduce the chances of name collision.
__ms_function_name="setup__test_function__$$"
eval "$__ms_function_name() { /bin/true ; }"

# Determine which shell we are using
__ms_ksh_test=$( eval '__text="text" ; if [[ $__text =~ ^(t).* ]] ; then printf "%s" ${.sh.match[1]} ; fi' 2> /dev/null | cat )
__ms_bash_test=$( eval 'if ( set | grep '$__ms_function_name' | grep -v name > /dev/null 2>&1 ) ; then echo t ; fi ' 2> /dev/null | cat )

if [[ ! -z "$__ms_ksh_test" ]] ; then
    __ms_shell=ksh
elif [[ ! -z "$__ms_bash_test" ]] ; then
    __ms_shell=bash
else
    # Not bash or ksh, so assume sh.
    __ms_shell=sh
fi

target=""
USERNAME=`echo $LOGNAME | awk '{ print tolower($0)'}`

if [[ -d /lfs5 ]] ; then
     # We are on NOAA Jet
    if ( ! eval module help > /dev/null 2>&1 ) ; then
        echo load the module command 1>&2
        source /apps/lmod/lmod/init/$__ms_shell
    fi
    target=jet
    module purge
elif [[ -d /scratch3/NCEPDEV ]] ; then
    # We are on NOAA Hera or Ursa
    mount=$(findmnt -n -o SOURCE /home)
    if [[ ${mount} =~ "ursa" ]]; then
      target=ursa
    else
      target=hera
    fi
    module purge
elif [[ -d /work2/noaa ]]; then
  # We are on MSU Orion or Hercules
  mount=$(findmnt -n -o SOURCE /home)
  if [[ ${mount} =~ "hercules" ]]; then
    target=hercules
  else
    target=orion
  fi
    module purge
elif [[ -d /gpfs/f5 ]]; then
  # We are on GAEAC5.
  target=gaeac5
elif [[ -d /gpfs/f6 ]]; then
  # We are on GAEAC6.
  target=gaeac6
elif [[ -d /lfs/h1 && -d /lfs/h2 ]] ; then
    target=wcoss2
    . $MODULESHOME/init/sh
else
    echo WARNING: UNKNOWN PLATFORM 1>&2
fi

unset __ms_shell
unset __ms_ksh_test
unset __ms_bash_test
unset $__ms_function_name
unset __ms_function_name

