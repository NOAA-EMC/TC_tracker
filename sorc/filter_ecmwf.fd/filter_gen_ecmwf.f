c##### filtering for TC genesis ######################
c###J.Peng  2012-05-09  ###############################
c mean RH>=80%     mean U shear < 0.0
c Tmax-Tmin >1.0 Vorticity(850hPa)>150
c######################################################
c-----------------------------------------------------------------------
      module define_atcfunix_rec
        type atcfunix_card    ! Define a new type for an atcfunix card
          sequence
          character*2   atx_basin       ! Hurricane Center Acronym
          character*2   atx_storm_num   ! Storm number (03, etc)
          character*10  atx_ymdh        ! Fcst start date (yyyymmddhh)
          character*2   atx_technum     ! Always equal to 03 for models
          character*4   atx_model       ! Name of forecast model
          integer       atx_fcsthr      ! Fcst hour (i3.3)
          integer       atx_lat         ! Storm Lat (*10), always >0
          character*1   atx_latns       ! 'N' or 'S'
          integer       atx_lon         ! Storm Lon (*10), always >0
          character*1   atx_lonew       ! 'E' or 'W'
          integer       atx_vmax        ! max sfc wind speed (knots)
          integer       atx_pcen        ! Min central pressure (mb)
          character*2   atx_stype       ! Storm type (= 'XX' for now)
          integer       atx_wthresh     ! Wind threshold (34, 50, 64 kt)
          character*3   atx_quad_id     ! NEQ = start with NE quadrant
          integer       atx_ne_quad     ! Wind radius in NE quad (nm)
          integer       atx_se_quad     ! Wind radius in SE quad (nm)
          integer       atx_sw_quad     ! Wind radius in SW quad (nm)
          integer       atx_nw_quad     ! Wind radius in NW quad (nm)
        end type atcfunix_card
      end module define_atcfunix_rec

c---------------------------------------------------------------------
      module define_atcf_gen_rec
        type atcf_gen_card    ! Define a new type for an atcf_gen card
          sequence
          character*2   gen_basin       ! Hurricane Center Acronym
          character*4   gen_storm_num   ! Storm number (03, etc)
          character*30  gen_storm_id    ! Storm ID
          character*10  gen_ymdh        ! Fcst start date (yyyymmddhh)
          character*2   gen_technum     ! Always equal to 03 for models
          character*4   gen_model       ! Name of forecast model
          integer       gen_fcsthr      ! Fcst hour (i3.3)
          integer       gen_lat         ! Storm Lat (*10), always >0
          character*1   gen_latns       ! 'N' or 'S'
          integer       gen_lon         ! Storm Lon (*10), always >0
          character*1   gen_lonew       ! 'E' or 'W'
          integer       gen_vmax        ! max sfc wind speed (knots)
          integer       gen_pcen        ! Min central pressure (mb)
          character*2   gen_stype       ! Storm type (= 'XX' for now)
          integer       gen_wthresh     ! Wind threshold (34, 50, 64 kt)
          character*3   gen_quad_id     ! NEQ = start with NE quadrant
          integer       gen_ne_quad     ! Wind radius in NE quad (nm)
          integer       gen_se_quad     ! Wind radius in SE quad (nm)
          integer       gen_sw_quad     ! Wind radius in SW quad (nm)
          integer       gen_nw_quad     ! Wind radius in NW quad (nm)
          integer       gen_pclose      ! pressure (mb) outer circle
          integer       gen_rpclose     ! Radius of pressure (mb) outer circle
          integer       gen_rmw         ! Radius of Maximum Wind
          integer       gen_cps1        ! CPS Parameter_B
          integer       gen_cps2        ! CPS VTL
          integer       gen_cps3        ! CPS VTU
          character*1   gen_wcore       ! Warm core 300-500mb mean
          integer       gen_mdir        ! Vortex translational direction
          integer       gen_mspd        ! Vortex translational speed
          integer       gen_cbm850      ! Vorticity Barnes mean at 850mb
          integer       gen_cgrd850     ! Vorticity grid maximum at 850mb
          integer       gen_cbm700      ! Vorticity Barnes mean at 700mb
          integer       gen_cgrd700     ! Vorticity grid maximum at 700mb
          real          gen_tbm1        ! Temperature Barnes mean at 300-500mb
          real          gen_tmean       ! Temperature mean(10X10) at 300-500mb
          real          gen_ush_min     ! Ushear 200-850mb minimum
          real          gen_ush_mean    ! Ushear 200-850mb mean (10X10 degree)
          real          gen_rh_min      ! RH minimum 500mb
          real          gen_rh_mean     ! RH mean (10X10 degree) 500mb
          real          gen_tbm2        ! Temperature Barnes mean at 300-500mb
          real          gen_tgrd        ! Temperature grid maximum at 300-500mb
        end type atcf_gen_card
      end module define_atcf_gen_rec

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      program filter_gen_track
      USE define_atcfunix_rec
      USE define_atcf_gen_rec

      type (atcfunix_card) inprec
      type (atcf_gen_card) stm
      real tdif

      readloop: do while (.true.)

        read (41,85,end=870) stm

        if(stm%gen_basin/='TG') then

        tdif=stm%gen_tgrd-stm%gen_tmean  

c        if(stm%gen_vmax.ge.10.and.tdif.ge.0.5
c     &     .and.abs(stm%gen_cgrd850).ge.100
c     &     .and.stm%gen_ush_min.lt.0.0
c     &     .and.stm%gen_rh_mean.ge.60.0 ) then

c        print *,stm%gen_basin, stm%gen_vmax, tdif, abs(stm%gen_cgrd850)
        if(stm%gen_vmax.ge.10.and.tdif.ge.0.5
     &     .and.abs(stm%gen_cgrd850).ge.100 ) then

          write (42,86) stm

          inprec%atx_basin=stm%gen_basin
          inprec%atx_storm_num=stm%gen_storm_num(2:3)
          inprec%atx_ymdh=stm%gen_ymdh
          inprec%atx_technum=stm%gen_technum
          inprec%atx_model=stm%gen_model
          inprec%atx_fcsthr=stm%gen_fcsthr
          inprec%atx_lat=stm%gen_lat
          inprec%atx_latns=stm%gen_latns 
          inprec%atx_lon=stm%gen_lon
          inprec%atx_lonew=stm%gen_lonew
          inprec%atx_vmax=stm%gen_vmax
          inprec%atx_pcen=stm%gen_pcen
          inprec%atx_stype=stm%gen_stype
          inprec%atx_wthresh=stm%gen_wthresh
          inprec%atx_quad_id=stm%gen_quad_id          
          inprec%atx_ne_quad=stm%gen_ne_quad
          inprec%atx_se_quad=stm%gen_se_quad
          inprec%atx_sw_quad=stm%gen_sw_quad
          inprec%atx_nw_quad=stm%gen_nw_quad

          write (43,81) inprec%atx_basin, inprec%atx_storm_num,
     & inprec%atx_ymdh, inprec%atx_technum, inprec%atx_model,
     & inprec%atx_fcsthr, inprec%atx_lat, inprec%atx_latns,
     $ inprec%atx_lon, inprec%atx_lonew, inprec%atx_vmax,
     & inprec%atx_pcen, inprec%atx_stype, inprec%atx_wthresh,
     & inprec%atx_quad_id, inprec%atx_ne_quad, inprec%atx_se_quad,
     & inprec%atx_sw_quad, inprec%atx_nw_quad
        endif
        endif
      enddo readloop

 85   format (a2,2x,a4,2x,a30,2x,a10,2x,a2,2x,a4,2x,i3
     &       ,2x,i3,a1,2x,i4,a1,2x
     &       ,i3,2x,i4,2x,a2,2x,i3,2x,a3,4(2x,i4),3(2x,i4),3(2x,i6)
     &       ,2x,a1,6(2x,i4),8(2x,f8.1))
 86   format (a2,', ',a4,', ',a30,', ',a10,', ',a2
     &       ,', ',a4,', ',i3.3,', ',i3,a1 ,', ',i4,a1
     &       ,', ',i3,', ',i4,', ',a2,', ',i3,', '
     &       ,a3,4(', ',i4.4),3(', ',i4),3(', ',i6),', ',a1
     &       ,6(', ',i4),8(', ',f8.1))
 81   format (a2,', ',a2,', ',a10,', ',a2,', ',a4,
     &       ', ',i3.3,', ',i3,a1,', ',i4,a1,', '
     &       ,i3,', ',i4,', ',a2,', ',i3,', ',a3,4(', ',i4.4))
 870  continue
      stop
      end
c-----------------------------------------------------------------------
