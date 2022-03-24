# TCLOGG Tracker

This contains a pared down wcoss python 2.7 version of the NHC TCLOGG tracker.

The tracker ingests GFS grib files, follows MSLET minima and outputs text files
containing track locations and pertinent storm relative variables.

This version has been developed to work around significant operational limitations and
extra files in this directory are to simulate external dependencies which can not be utilized
in the operational system.

tclogg source files are within the genesis_guidance directory.


## Installation

Installation is a simple 1 step process, just run `make`.
`make` will just create a modulefile to make sure the other modules are loaded in the right order and that `PATH` and `PYTHONPATH` are set up.  
This is generated for the current working directory so it the code moves, the file will need to be remade.  Code in make_modulefile.py. 


## Running the tracker

    module use ./modulefiles
    module load tclogg 
    tclogg_track --date 2019111312  


## Setup

`genesis_guidance/model_config.cfg` specfies input data parameters.  
Default is to run on realtime gfs output on wcoss.  
`fname_template` is a python date time string format,  
`date` = the init time of the forecast   
`fhr` = forecast hour of the file  
 

## Scripting

This tracker can also be called from a python script

    from genesis_guidance import tracker

    tracker.tctracker('gfs', rundate, './', ['natl','epac'])
