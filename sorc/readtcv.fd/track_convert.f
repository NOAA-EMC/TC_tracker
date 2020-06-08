c###J.Peng  2013-05-09  TC track atcfunix to genesis format  cccccccccc
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

      module def_vitals
        type tcvcard         ! Define a new type for a TC Vitals card
          sequence
          character*4   tcv_center      ! Hurricane Center Acronym
          character*3   tcv_storm_id    ! Storm ID Letter Identifier (03L, etc)
          character*9   tcv_storm_name  ! Storm name
          integer*4       tcv_century     ! 2-digit century id (19 or 20)
          integer*4       tcv_yymmdd      ! Date of observation
          integer*4       tcv_hhmm        ! Time of observation (UTC)
          integer*4       tcv_lat         ! Storm Lat (*10), always >0
          character*1   tcv_latns       ! 'N' or 'S'
          integer*4       tcv_lon         ! Storm Lon (*10), always >0
          character*1   tcv_lonew       ! 'E' or 'W'
          integer*4       tcv_stdir       ! Storm motion vector (in degr)
          integer*4       tcv_stspd       ! Spd of storm movement (m/s*10)
          character*85  tcv_chunk       ! Remainder of vitals record;
                                        ! will just be read & written
        end type tcvcard
      end module def_vitals

c---------------------------------------------------------------------
      program trackgen
      USE define_atcfunix_rec
      type (atcfunix_card) inprec

      character*1 tc_tail
      character*3 storm_num
      character*9 storm_name

      character*3 stormid(100)
      character*9 stormname(100)

      integer       atx_lat_id         
      character*1   atx_latns_id      
      integer       atx_lon_id       
      character*1   atx_lonew_id    

      call read_tcv_file (stormid,stormname,ict)

      ik=0
      readloop: do while (.true.)
        read (11,85,end=870) inprec
        ik=ik+1

	if(inprec%atx_basin == 'AL') then
	  tc_tail='L'
        elseif(inprec%atx_basin == 'EP') then
	  tc_tail='E'
        elseif(inprec%atx_basin == 'WP') then
	  tc_tail='W'
        elseif(inprec%atx_basin == 'CP') then
	  tc_tail='C'
        elseif(inprec%atx_basin == 'SC') then
          tc_tail='O'
        elseif(inprec%atx_basin == 'EC') then
	  tc_tail='T'
        elseif(inprec%atx_basin == 'AU') then
          tc_tail='U'
        elseif(inprec%atx_basin == 'SP') then
	  tc_tail='P'
        elseif(inprec%atx_basin == 'SI') then
	  tc_tail='S'
        elseif(inprec%atx_basin == 'BB') then
	  tc_tail='B'
        elseif(inprec%atx_basin == 'NA') then
	  tc_tail='A'
        else
	  tc_tail='X'
        endif
       
	storm_num=inprec%atx_storm_num//tc_tail
        do i=1,ict
          if(stormid(i)== storm_num) then
	    storm_name=stormname(i)
            goto 199
          else
            storm_name="No_nameTC"
          endif
        enddo
 199    continue

	if(inprec%atx_fcsthr.eq.0) then
          atx_lat_id=inprec%atx_lat
	  atx_latns_id=inprec%atx_latns
	  atx_lon_id=inprec%atx_lon
	  atx_lonew_id=inprec%atx_lonew
        endif

        write (66,87) inprec%atx_basin,storm_num
     &        ,inprec%atx_ymdh,inprec%atx_fcsthr
     &        ,atx_lat_id,atx_latns_id
     &        ,atx_lon_id,atx_lonew_id
     &        ,storm_num,inprec%atx_ymdh
     &        ,inprec%atx_model,inprec%atx_fcsthr
     &        ,inprec%atx_lat,inprec%atx_latns
     &        ,inprec%atx_lon,inprec%atx_lonew
     &        ,inprec%atx_vmax, inprec%atx_pcen
     &        ,'XX,  34, NEQ'
     &        ,inprec%atx_ne_quad,inprec%atx_se_quad
     &        ,inprec%atx_sw_quad,inprec%atx_nw_quad
     &        ,-999,-999,-99,-99,-99
     &        ,-99,-9999,-9999
     &        ,-999,-999,-999,-999
     &        ,storm_name

      enddo readloop
  870 continue

   87 format (a2,', ',a4,', ',a10,'_F',i3.3,'_',i3.3,a1,'_',i4.4,a1
     &       ,'_',a3,', ',a10,', 03, ',a4,', ',i3.3,', ',i3,a1
     &       ,', ',i4,a1,', ',i3,', ',i4,', ',a12,4(', ',i4.4)
     &       ,', ',2(i4,', '),4(i3,', '),2(i5,', '),4(i4,', '),a9)
cPENG bug fixed on 04/20/2018---------------------------------
 85   format (a2,2x,a2,2x,a10,2x,a2,2x,a4,2x,i3,2x,i3,a1,2x,i4,a1,2x
     &       ,i3,2x,i4,2x,a2,3x,i2,2x,a3,4(2x,i4))
c 85   format (a2,2x,a2,2x,a10,2x,a2,2x,a4,2x,i3,2x,i3,a1,2x,i4,a1,2x
c     &       ,i3,2x,i4,2x,a2,2x,i2,2x,a3,4(2x,i3))

      stop
      end
c-----------------------------------------------------------------------
      subroutine read_tcv_file (stormid,stormname,ict)
      USE def_vitals
      type (tcvcard) ts
      character*3 stormid(100)
      character*9 stormname(100)

      ict=0
      do while (.true.)
        read (31,21,END=801) ts
        ict=ict+1
        stormid(ict)=ts%tcv_storm_id
        stormname(ict)=ts%tcv_storm_name
      enddo
   21 format (a4,1x,a3,1x,a9,1x,i2,i6,1x,i4,1x,i3,a1,1x,i4,a1
     &       ,1x,i3,1x,i3,a85)
  801 continue
      return
      end
