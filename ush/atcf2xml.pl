#!/usr/bin/perl
#From Dick, 05/13/2013  ###################################
###########################################################
# Author : Mike Charles
#
# History:
#
# v0.1     03 MAR 2008    Initial Development
# v0.9     28 MAY 2008    Greatly expanded functionality
# v1.0     04 JUN 2008    Finished all coding and documentation
# v1.1     10 JUN 2008    Added code to sort input ATCF file by 
#                         ID, Fhr before processesing
# v1.1.1   30 JUN 2008    Added 3-letter basin codes inside each
#                         disturbance tag
# v1.2     09 JUL 2008    Adapted code to accept both old ATCF
#                         format (with integer ID) and new ATCF
#                         format (DATE_FFFF_LAT_LON ID)
# v1.2.1   18 JUL 2008    Added code to specify the input and output
#                         directory as input arguments
#
# Requires: XML::LibXML
###########################################################

use Getopt::Long; # For command line options
use Time::Local;  # For time functions

#################################################
# Directories
#
#$home_DIR = '/ensemble/save/Jiayi.Peng/atcf2xml';
#$dest_DIR = '/ensemble/save/Jiayi.Peng/atcf2xml';
#$cxml_DIR = "/ensemble/save/Jiayi.Peng/atcf2xml";

#################################################
# Get Command Line Arguments
#
GetOptions (
	'h'			=> \$help,
	'date=s'	=> \$date,
	'model=s'	=> \$model,
	'basin=s'	=> \$basin,
	'zip'		=> \$zip,
	'atcf_dir=s'=> \$atcf_DIR,
	'cxml_dir=s'=> \$cxml_DIR,
	'cxml_file=s' => \$cxml_file,
	'trop'	=> \$trop
);

#################################################
# RLW 20110524 make work_DIR unique among models
# Directories
#
#$work_DIR = "$dest_DIR/work/$model";
$work_DIR = "$cxml_DIR/$model";
#################################################
# Print Help For User
#
if ($help or !(defined($date) and defined($model) and defined($basin))) {
	print "Usage: atcf2cxml.pl [OPTIONS]\n";
	print "  options:\n";
	print "      --date       date          YYYYMMDDHH\n";
	print "      --model      model         GFS, GEFS, CENS\n";
	print "      --basin      basin         altg, eptg, wptg, ecml, glob\n";
	print "      --zip                      Compress CXML output using gzip\n";
	print "      --atcf_dir   /path/to/atcf\n";
	print "      --cxml_dir   /path/to/cxml\n";
	print "      --cxml_file  cxml file name\n";
	print "      --trop       process ATCF file assuming tropical cyclones only\n";
	exit;
}

#################################################
# Parse Input Date
#
($y,$m,$d,$h) = parse_date($date);
$yyyymm   = "$y$m";
$yyyymmdd = "$y$m$d";
$hh = $h;

#################################################
# Set Model Preferences
#
($basin_str,$bbb) = basin_string($basin);
set_model_prefs($model);

#################################################
# Calculate Times
#
$base_time = cxml_time($date);
my $ss,$mm,$h2,$d2,$m2,$y2 ;
($ss,$mm,$h2,$d2,$m2,$y2) = gmtime(time) ; $m2=$m2+1;$y2=$y2+1900;
$creation_time = cxml_time(sprintf("%4d%02d%02d%02d%02d%02d",$y2,$m2,$d2,$h2,$mm,$ss));

#################################################
# Print More Information
#
#print "Script Home    : $home_DIR\n";
print "Work Directory : $work_DIR\n";
print "ATCF Directory : $atcf_DIR\n";
print "CXML Directory : $cxml_DIR\n";
print "CXML File Name : $cxml_file\n";
print "Base Time      : $base_time\n";
print "Current Time   : $creation_time\n";
print "Basin          : $basin ($basin_str)\n";

#################################################
# Change to work directory and empty
#
unless (-e "$work_DIR") {`mkdir -p $work_DIR`; }
chdir($work_DIR) or die "Cannot change to work directory: $!\n";
`rm -f $work_DIR/*`;
#################################################
# Copy all ATCF files to work directory
#
copy_atcf();

#################################################
# OPEN CXML FILE
#
open(CXML,">$cxml_file");

#################################################
# Write CXML header
#
write_header();

#################################################
# Insert all cyclone forecasts
#
foreach my $memb_num (0..$#atcf_model_name) {
	my $memb = $atcf_model_name[$memb_num];
	#############################################
	# Insert Forecast
	$atcf_file = "$memb.tracks";
	insert_forecast($atcf_file,$memb_num);
}

#################################################
# Finish CXML File
#
print CXML "</cxml>\n";
close CXML;
close ATCF;

#################################################
# Move Output And Clean Up
#
# Compress CXML file
if ($zip) {
	`gzip $cxml_file`;
	$cxml_file="$cxml_file.gz";
}
# Create output directory if it doesn't exist
unless (-e "$cxml_DIR/$yyyymm") {`mkdir -p $cxml_DIR/$yyyymm`; }
unless (-e "$cxml_DIR/$yyyymm/$yyyymmdd") {`mkdir -p $cxml_DIR/$yyyymm/$yyyymmdd`; }
# Move CXML file to output CXML directory
`mv -f $cxml_file $cxml_DIR/$yyyymm/$yyyymmdd`;
# Clean out work directory
#`rm -f $work_DIR/*`;

exit;

#############################################################
#            # # # # # # # # # # # # # # # # # #            #
#      # # # # # # # # # # # # # # # # # # # # # # # #      #
# # # # # # # # # # # # SUB  ROUTINES # # # # # # # # # # # #
#      # # # # # # # # # # # # # # # # # # # # # # # #      #
#            # # # # # # # # # # # # # # # # # #            #
#############################################################

			
###########################################################
# PARSE_DATE
#
# Input  : date              date to parse (YYYYMMDDHH[mmSS])
#
# Output : year              year   (YYYY)
#          month             month  (MM)
#          day               day    (DD)
#          hour              hour   (HH)
#          minute            minute (mm)
#          second            second (SS)
#
sub parse_date {
    my $year ; my $month ; my $day ; my $hour ; my $minute ; my $second ;
    my $date    = $_[0] ;
    $year    = substr($date,0,4) ;
    $month   = substr($date,4,2) ;
    $day     = substr($date,6,2) ;
    $hour    = substr($date,8,2) ;

	if (length($date)==14) {
		$minute = substr($date,10,2) ;
		$second = substr($date,12,2) ;
		return ($year,$month,$day,$hour,$minute,$second);
	} else {
	    return ($year,$month,$day,$hour);
	}
}
###########################################################
# VALID_TIME
#
# Input  : time              Analysis time (YYYYMMDDHH)
#          fhr               Forecast Hour
#
# Output : valid_time        Valid time (YYYYMMDDHH)
#
sub valid_time {
    my $time = $_[0];
    my $fhr  = $_[1];

    (my $year,my $month,my $day,my $hour) = parse_date($time);

    my $fcst = timegm(0,0,$hour,$day,$month-1,$year-1900);
    my $obsv = $fcst + 3600*$fhr;

    ($junk,$junk,$hour,$day,$month,$year) = gmtime($obsv);
    $year=$year+1900;
    $month=$month+1;

    return sprintf("%04d%02d%02d%02d",$year,$month,$day,$hour);
}
###########################################################
# CXML_TIME
#
# Converts YYYYMMDDHH time into the time format used by CXML
#
# Input  : old_time          Time in YYYYMMDDHH format
#
# Output : new_time          Time in CXML format (YYYY-MM-DD HH:mm:ss)
#
sub cxml_time {
	my $old_time = $_[0];
	my ($y,$m,$d,$h,$mm,$ss) = parse_date($old_time);
#	my $mm = 0;
#	my $ss = 0;
	my $new_time = sprintf("%4d-%02d-%02dT%02d:%02d:%02dZ",$y,$m,$d,$h,$mm,$ss);
	return $new_time;
}
###########################################################
# TRIM
#
# Perl trim function to remove whitespace from the start
# and end of the string
#
# Input  : in_string         String containing whitespace
#
# Output : out_string        String without whitespace
#
sub trim($) {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}
###########################################################
# BASIN_STRING
#
# Input  : basin             TC basin (ALTG, EPTG, WPTG)
#
# Output : string            String describing basin
#          bbb               3-letter CXML basin code
#
# Vars set: cxml_region      fills <subRegion> tag in CXML file
#           cxml_track_type  Added at the end of the CXML file; 
#                                tctr: Tropical
#                                sttr: Extratropical and Tropical
#           bb               Basin code found in ATCF files
#
sub basin_string {
	my $basin = $_[0];
	my $string ;
	my $bbb ;
	if ($basin eq "altg") {
		$string = "Tropical Atlantic Basin";
		$cxml_region = "Atlantic";
		$cxml_track_type = "tctr";
		if ($trop) {
			$cxml_track_type = "tctr";
		} else {
			$cxml_track_type = "sttr";
		}
		$bbb = "ATL";
		$bb  = "AL";
	} elsif ($basin eq "eptg") {
		$string = "Tropical Eastern Pacific Basin";
		$cxml_region = "Eastern Pacific";
		$cxml_track_type = "tctr";
		$bbb = "NEP";
		$bb  = "EP";
	} elsif ($basin eq "wptg") {
		$string = "Tropical Western Pacific Basin";
		$cxml_region = "Western Pacific";
		$cxml_track_type = "tctr";
		$bbb = "NWP";
		$bb  = "WP";
	} elsif ($basin eq "ecml") {
		$string = "Extratropical North America";
		$cxml_region = "North America";
		$cxml_track_type = "sttr";
		$bbb = "NAM";
		$bb  = "ML";
	} elsif ($basin eq "glob") {
		$string = "Global";
		$cxml_region = "Global";
		if ($trop) {
			$cxml_track_type = "tctr";
		} else {
			$cxml_track_type = "sttr";
		}
		$bbb = "GLO";
		$bb  = "ML";
	} else {
		die "Basin \"$basin\" not recognized, please rerun with a different basin...\n"; 
	}
	return ($string,$bbb);
}
###########################################################
# COPY_ATCF
#
#
sub copy_atcf {
	my $file;
	foreach $member (@atcf_model_name) {
		if ($trop) {
			$file = "$atcf_DIR/$yyyymm/$yyyymmdd/trak.$member.atcf_gen.$basin.$date.trop";
		} else {
			$file = "$atcf_DIR/$yyyymm/$yyyymmdd/trak.$member.atcf_gen.$basin.$date";
		}
		print "Grepping $file for \"$date\"\n";
		`grep -e \"$date\" $file | grep -e "34, NEQ" >$member.tracks`;
	}
}
###########################################################
# PULL_TRACKS
#
# Input  : basin             TC basin (ALTG, EPTG, WPTG)
#          n                 Cyclone ID number
#          type              Model Type (determ./ens.)
#
# Output : 
#
sub pull_tracks {
	my $basin = $_[0];
	my $nnn   = $_[1];
	my $memb  = $_[2];

	system "grep -e \"$date\" $atcf_model_name[$memb].tracks >temp.tracks";
}
###########################################################
# WRITE_HEADER
#
# Input:
#
# Output:
#
sub write_header {
	print CXML <<BLOCK;
<?xml version="1.0" encoding="UTF-8"?>
<cxml xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:noNamespaceSchemaLocation="http://www.bom.gov.au/bmrc/projects/THORPEX/CXML/cxml.0.2.xsd">
    <header>
        <product>Cyclone Forecast</product>
        <generatingApplication>
            <applicationType>$application_type</applicationType>
            <model>
                <name>$model_name</name>
                <domain>$model_domain</domain>
                <modelResolution>$model_resolution</modelResolution>
                <dataResolution units="deg">$data_resolution</dataResolution>
                <productionStatus>$production_status</productionStatus>
            </model>
        </generatingApplication>
        <productionCenter>$production_center
            <subCenter>$sub_center</subCenter>
        </productionCenter>
        <moreInfo>http://www.nco.ncep.noaa.gov/pmb/nwprod/analysis/</moreInfo>
        <moreMetadata></moreMetadata>
        <baseTime>$base_time</baseTime>
        <creationTime>$creation_time</creationTime>
        <spatialReferenceSystem>
            <name>$spatial_ref_name</name>
            <radius units="km">6378.137</radius>
        </spatialReferenceSystem>
    </header>
BLOCK
}
###########################################################
# INSERT_FORECAST
#
# Input  : 
#
# Output : 
#
sub insert_forecast {
	my $atcf_file = $_[0];
	my $memb_num  = $_[1];

	# Start <data type=xxx> section
	if (-s $atcf_file == 0) { 
		if ($model_type =~ /^deterministic$/i) {
			print CXML "    <data type=\"forecast\" />\n";
		} elsif ($model_type =~ /^ensemble$/i) {
			print CXML "    <data type=\"ensembleForecast\" member=\"$memb_num\" />\n";
		}
		return;
	}

	# OPEN ATCF FILE
	open(ATCF,"<$atcf_file");

	if ($model_type =~ /^deterministic$/i) {
		print CXML "    <data type=\"forecast\">\n";
	} elsif ($model_type =~ /^ensemble$/i) {
		print CXML "    <data type=\"ensembleForecast\" member=\"$memb_num\">\n";
	}

	# Sort ATCF data by ID (col 2), then by Fhr (col 7)
	my @data = map {$_->[0]}
	sort { $a->[2] cmp $b->[2] || $a->[7] <=> $b->[7] }
	map {chomp;[$_,split(/,/)]} <ATCF>;

	close(ATCF);

	################################################
	# Loop thru ATCF file
    #
	$old_id = -99;$any_storms=0;my $line;
	foreach $line (@data) {
		# split line
		my ($basin,$id_short,$id_long,$date,$junk,$model,$fhr,$lat,$lon,$max_wind,$min_slp,
		$junk,$junk,$junk,$junk,$junk,$junk,$junk,$junk,$junk,$junk,$junk,$junk,$phase_b,
		$phase_vtl,$phase_vtu,$junk,$junk,$junk,$junk,$storm_name) = split(/\,/,$line);
		# Is this bad data?
		if ($lat==0 && $lon==0 && $min_slp==0) { next;}
		# Is this in the correct basin?
#		if (!($basin eq $bb or $basin eq "TG" or $basin eq "ML")) { next;}
		# If we got up to here, then we've found at least one storm
		$any_storms = 1;
		# Clean up formatting
		($basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,
		$phase_b,$phase_vtu,$phase_vtl,$storm_name,$lat_long,$lon_long) = 
		&reformat($basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,
		$phase_b,$phase_vtu,$phase_vtl,$storm_name);
		# Is this a new storm?
		############################### if test chaned from "!=" to "ne" on 20100723 RLW JP
		if ($id_short ne $old_id) {
			unless ($old_id==-99) {
				# Close previous <disturbance> tag
				print CXML "        </disturbance>\n";
			}
			print CXML "        <disturbance ID=\"${date}_${lat_long}_${lon_long}\">\n";
			# If the storm name is a string, write it into the CXML
#                       print "Storm Name: $storm_name\n";
#J.Peng                 if ($storm_name =~ /^[A-Za-z]+$/) {
#                          print CXML "            <cycloneName>$storm_name</cycloneName>\n";
#                          print CXML "            <cycloneNumber>" . substr($id_short,0,2) . "</cycloneNumber>\n";
#                       }

                        print CXML "            <cycloneName>$storm_name</cycloneName>\n";
			print CXML "            <cycloneNumber>" . substr($id_short,0,2) . "</cycloneNumber>\n";

			print CXML "            <basin>$basin</basin>\n";
		}
		# Insert fix
		insert_fix($basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,
		$phase_b,$phase_vtu,$phase_vtl,$storm_name);
		$old_id = $id_short;
	}
	# Close previous <disturbance> tag
	if ($any_storms) { print CXML "        </disturbance>\n";}
	print CXML "    </data>\n";
}
###########################################################
# GET_BASIN
#
sub get_basin {
    my $atcf_basin = $_[0];
    if ($atcf_basin eq "L") {
        $cxml_basin = "ATL";
    } elsif ($atcf_basin eq "E") {
        $cxml_basin = "NEP";
    } elsif ($atcf_basin eq "W") {
        $cxml_basin = "NWP";
    } elsif ($atcf_basin eq "B") {
        $cxml_basin = "NIO";
    } elsif ($atcf_basin eq "S") {
        $cxml_basin = "SWI";
    } elsif ($atcf_basin eq "U") {
        $cxml_basin = "SEI";
    } elsif ($atcf_basin eq "P") {
        $cxml_basin = "SWP";
    } elsif ($atcf_basin eq "GLO") {
        $cxml_basin = "TG";
    }
    return $cxml_basin;
}

###########################################################
# INSERT_FIX
#
# Input  : basin             TC basin (ALTG, EPTG, WPTG)
#          id                Cyclone ID num
#          date              Initialization date (YYYYMMDDHH)
#          model             Model (GFS, GEFS, CENS, CMC)
#          fhr               Forecast Hour
#          lat               Latitude (deg)
#          lon               Longitude (deg)
# 20101021 RLW+JP change label from m/s to kt to correspond to the value output by the tracker
####       max_wind          Maximum wind speed (m/s)
#          max_wind          Maximum wind speed (kt)
#          min_slp           Minimum sea level pressure (mb)
#
# Output :
#
sub insert_fix {
	#$basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,$phase_b,$phase_vtu,$phase_vtl,$storm_name
	my $basin      = $_[0];
	my $id_short   = $_[1];
	my $id_long    = $_[2];
	my $date       = $_[3];
	my $model      = $_[4];
	my $fhr        = $_[5];
	my $lat        = $_[6];
	my $lon        = $_[7];
	my $max_wind   = $_[8];
	my $min_slp    = $_[9];
	my $phase_b    = $_[10];
	my $phase_vtu  = $_[11];
	my $phase_vtl  = $_[12];
	my $storm_name = $_[13];
	my $new_time   = cxml_time(valid_time($date,$fhr));
	
	print CXML <<BLOCK;
			<fix hour="$fhr">
                <validTime>$new_time</validTime>
                <latitude units="deg N">$lat</latitude>
                <longitude units="deg E">$lon</longitude>
                <subRegion>$cxml_region</subRegion>
                <cycloneData biasCorrected="$bias_corrected">
                    <minimumPressure>
                        <pressure units="hPa">$min_slp</pressure>
                    </minimumPressure>
                    <maximumWind>
                        <speed units="kt">$max_wind</speed>
                    </maximumWind>
                    <cyclonePhase>
                        <stormRelThkSymmetry units="m">$phase_b</stormRelThkSymmetry>
                        <thermalWindLower units="m/s">$phase_vtl</thermalWindLower>
                        <thermalWindUpper units="m/s">$phase_vtu</thermalWindUpper>
                    </cyclonePhase>
                </cycloneData>
            </fix>
BLOCK
}
###########################################################
# REFORMAT
#
# Input  :
#
# Output : 
# $basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,$phase_b,$phase_vtu,$phase_vtl

sub reformat {
	my $basin      = trim($_[0]);
	my $id_short   = trim($_[1]);
	my $id_long    = trim($_[2]);
	my $date       = trim($_[3]);
	my $model      = trim($_[4]);
	my $fhr        = sprintf('%d',trim($_[5]));
	my $lat        = trim($_[6]);
	my $lon        = trim($_[7]);
	my $max_wind   = trim($_[8]);
	my $min_slp    = trim($_[9]);
	my $phase_b    = trim($_[10]);
	my $phase_vtu  = trim($_[11]);
	my $phase_vtl  = trim($_[12]);
	my $storm_name = trim($_[13]);
	my $lat_long = sprintf("%03d",$lat) . substr($lat,-1,1);
	my $lon_long = sprintf("%04d",$lon) . substr($lon,-1,1);
	# convert longitude to decimal (out of 360)
	if (substr($lon,-1,1) eq 'W') {
		$lon = (360 - substr($lon,0,-1) / 10);
	} else {
		$lon = substr($lon,0,-1) / 10 ;
	}
	# convert latitude to decimal
	# RLW JP 20110119 add test to make south latitude negative
	if (substr($lat,-1,1) eq 'N') {
		$lat =  substr($lat,0,-1) /  10 ;
	} else {
		$lat =  substr($lat,0,-1) / (-10) ;
	}
	# convert storm name into Upper-lowercase
	$storm_name = ucfirst(lc($storm_name));
	return ($basin,$id_short,$id_long,$date,$model,$fhr,$lat,$lon,$max_wind,$min_slp,
	$phase_b,$phase_vtu,$phase_vtl,$storm_name,$lat_long,$lon_long);
}
###########################################################
# SET_MODEL_PREFS
#
# Input  : model             GFS, GEFS, CENS, CMC
#
# Output : atcf_model_name   model name in ATCF file
#          atcf_dir          directory containing ATCF files
#          cxml_file         name of output cxml file
#
# Vars   : application_type  "Manual Analysis", "NWP forecast"...
#          model_name        GFS, GEFS, CENS, CMC...
#          model_type        Deterministic, Ensemble
#          model_domain      global, lat/lon boundaries...
#          short_domain      glob, lam (Limited Area Model)...
#          cxml_ens_flag     e for ensemble, otherwise blank
#          model_resolution  T382L64, T190L64...
#          data_resolution   1, 0.5... (degrees)
#          spatial_ref_name  
#          bias_corrected    0 or 1
#          production_status prod, para, test...
#          production_center NCEP, MSC...
#          sub_center        EMC...
#          more_info         website
#          atcf_model_name   gfsx (gfs) | ap01,ap02...ap20 (gefs membs) [in ATCF file]
#          atcf_DIR          DIR containing atcf files

sub set_model_prefs {
	my $model = $_[0];
	if ($model =~ /^GFS$/i) {
		#---------------------- GFS -----------------------#
		$application_type  = "Global Model";
		$model_name        = "GFS";
		$model_type        = "Deterministic";
		$model_domain      = "global";
		$short_domain      = "glob";
		$cxml_ens_flag     = "";
		$model_resolution  = "T574L64 to 192h, T190L64 to 384h";
		$data_resolution   = "0.5";
		$spatial_ref_name  = "";
		$bias_corrected    = "0";
		$production_status = "prod";
		$production_center = "NCEP";
		$sub_center        = "EMC";
		$more_info         = "http://www.nco.ncep.noaa.gov/pmb/nwprod/analysis/";
		@atcf_model_name   = ('gfsx');
		#$atcf_DIR          = "/com/gfs/prod/gfs.$yyyymmdd";
		#unless ($atcf_DIR) {$atcf_DIR = "/cpc/save/wx53mc/tracking/data/atcf/$yyyymmdd";}
		unless ($atcf_DIR) {$atcf_DIR = "/global/noscrub/wx20rw/t/tracking/data/atcf/$yyyymmdd";}
	} elsif ($model =~ /^CMC$/i) {
		#---------------------- CMC -----------------------#
		$application_type  = "Global Model";
		$model_name        = "CMC";
		$model_type        = "Deterministic";
		$model_domain      = "global";
		$short_domain      = "glob";
		$cxml_ens_flag     = "";
		$model_resolution  = "T382L64 to 180h, T190L64 to 384h";
		$data_resolution   = "0.5";
		$spatial_ref_name  = "";
		$bias_corrected    = "0";
		$production_status = "prod";
		$production_center = "MSC";
		$sub_center        = "CMC";
		$more_info         = "http://www.weatheroffice.gc.ca/ensemble/index_e.html";
		@atcf_model_name   = ('cmc');
		#$atcf_DIR          = "/com/gfs/prod/gfs.$yyyymmdd";
		#unless ($atcf_DIR) {$atcf_DIR = "/cpc/save/wx53mc/tracking/data/atcf/$yyyymmdd";}
		unless ($atcf_DIR) {$atcf_DIR = "/global/noscrub/wx20rw/t/tracking/data/atcf/$yyyymmdd";}
	} elsif ($model =~ /^GEFS$/i) {
		#---------------------- GEFS ----------------------#
		$application_type  = "Global Ensemble";
		$model_name        = "GEFS";
		$model_type        = "Ensemble";
		$model_domain      = "global";
		$short_domain      = "glob";
		$cxml_ens_flag     = "e";
		$model_resolution  = "T254L42";
		$data_resolution   = "1";
		$spatial_ref_name  = "";
		$bias_corrected    = "0";
		$production_status = "prod";
		$production_center = "NCEP";
		$sub_center        = "EMC";
		$more_info         = "http://www.nco.ncep.noaa.gov/pmb/nwprod/analysis/";
		@atcf_model_name   = ('ac00','ap01','ap02','ap03','ap04','ap05','ap06','ap07','ap08','ap09','ap10',
							'ap11','ap12','ap13','ap14','ap15','ap16','ap17','ap18','ap19','ap20');
		#$atcf_DIR          = "/com/gens/prod/gefs.$yyyymmdd/$hh/track";
		#unless ($atcf_DIR) {$atcf_DIR = "/cpc/save/wx53mc/tracking/data/atcf/$yyyymmdd";}
		unless ($atcf_DIR) {$atcf_DIR = "/global/noscrub/wx20rw/t/tracking/data/atcf/$yyyymmdd";}
	} elsif ($model =~ /^CENS$/i) {
		#---------------------- CENS ----------------------#
		$application_type  = "Global Ensemble";
		$model_name        = "CENS";
		$model_type        = "Ensemble";
		$model_domain      = "global";
		$short_domain      = "glob";
		$cxml_ens_flag     = "e";
		$model_resolution  = "0.9 deg";
		$data_resolution   = "1";
		$spatial_ref_name  = "";
		$bias_corrected    = "0";
		$production_status = "prod";
		$production_center = "MSC";
		$sub_center        = "CMC";
		$more_info         = "http://www.weatheroffice.gc.ca/ensemble/index_e.html";
		@atcf_model_name   = ('cc00','cp01','cp02','cp03','cp04','cp05','cp06','cp07','cp08','cp09','cp10',
							'cp11','cp12','cp13','cp14','cp15','cp16','cp17','cp18','cp19','cp20');
		#$atcf_DIR          = "/com/gens/prod/cmce.$yyyymmdd/$hh/track";
		#unless ($atcf_DIR) {$atcf_DIR = "/cpc/save/wx53mc/tracking/data/atcf/$yyyymmdd";}
		unless ($atcf_DIR) {$atcf_DIR = "/global/noscrub/wx20rw/t/tracking/data/atcf/$yyyymmdd";}
	} else {
		die "Model \"$model\" not recognized, please rerun with a different model...\n";
	}
	unless (defined($cxml_file)) {
		$cxml_file         = "kwbc_${date}0000_${model_name}_${short_domain}_${production_status}_${cxml_ens_flag}${cxml_track_type}_" . lc(${bbb}) . ".xml";
	}
}
