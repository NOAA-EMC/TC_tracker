      program rhum_g2
c
c     ABSTRACT: This program calculates the relative humidity from an
c     input grib2 files(SPFH/T) and produces an output grib2 file 
c     containing the RH for different layers.
c
c     fort.11----input grib2 file (SPFH/T)
c     fort.31----input gribindex file
c     fort.16----cmc_tmp_levs.txt 
c     fort.51----output RH gri2b file
c     Written by J.Peng--04-10-2017
c

      USE params
      USE grib_mod

      implicit none

      type(gribfield) :: holdgfld
      integer, parameter :: lugb=11,lulv=16,lugi=31,lout=51,maxlev=200
      integer, parameter :: ix=1500,jy=751
      integer  kpds(200),kgds(200)
      integer  nlevsin,iriret,iogret,kf,iggret,igdret,iidret,ixo,k,n
      integer  iho,iva,irfa,iodret,ifcsthour,iia,nlevsout
      integer  ihq,iht,iparmq,iparmt
      integer  gribver,g2_jpdtn
cJ.Peng---------------------------------------------      
      integer  g2_model
      integer  ilevs(maxlev)
      real, allocatable :: xinpdatq(:,:),xoutdat(:,:),xoutlevs_p(:)
      real, allocatable :: xinpdatt(:,:)
      logical(1), allocatable :: valid_pt(:),readflag(:)
cJ.Peng---------------------------------------------
      namelist/timein/ifcsthour,iparmq,iparmt,gribver,g2_jpdtn,g2_model
c
      read (5,NML=timein,END=201)
  201 continue
      print *,' '
      print *,' +++          Top of RH                            +++'
      print *,'*----------------------------------------------------*'
      print *,'After namelist read, input forecast hour = ',ifcsthour
      print *,'            input grib parm = ',iparmq,iparmt
      print *,'                         GRIB version= ',gribver
      print *,'                         GRIB2 g2_jpdtn= ',g2_jpdtn
      print *,'                         g2_model= ',g2_model



      ilevs = -999
      call read_input_levels (lulv,maxlev,nlevsin,ilevs,iriret)

      if (iriret /= 0) then
        print *,' '
        print *,'!!! RETURN CODE FROM read_input_levels /= 0'
        print *,'!!! RETURN CODE = iriret = ',iriret
        print *,'!!! EXITING....'
        print *,' '
        goto 899
      endif

      nlevsout = nlevsin
      allocate (xoutlevs_p(nlevsout),stat=ixo)
      if (ixo /= 0) then
        print *,' '
        print *,'!!! ERROR in RH allocating the xoutlevs_p array.'
        print *,'!!! ixo= ',ixo
        print *,' '
        goto 899
      endif

      do k = 1,nlevsout
        xoutlevs_p(k) = ilevs(k)*1.0
      enddo  

      call open_grib_files (lugb,lugi,lout,gribver,iogret)

      if (iogret /= 0) then
        print '(/,a45,i4,/)','!!! ERROR: in RH open_grib_files, rc= '
     &        ,iogret
        STOP 93
      endif

      call getgridinfo (lugb,lugi,kf,kpds,kgds,holdgfld,ifcsthour,iparmq
     &                 ,gribver,g2_jpdtn,iggret)

      allocate (xinpdatq(kf,nlevsin),stat=ihq)
      allocate (xinpdatt(kf,nlevsin),stat=iht)

      allocate (xoutdat(kf,nlevsout),stat=iho)
      allocate (valid_pt(kf),stat=iva)
      allocate (readflag(nlevsin),stat=irfa)
      if (ihq /= 0 .or. iht /= 0 .or. iho /= 0 
     &   .or. iva /= 0 .or. irfa /= 0) then
        print *,' '
        print *,'!!! ERROR in RH.'
        print *,'!!! ERROR allocating the xinpdatq/t, readflag, or the'
        print *,'!!! valid_pt array, ihq= ',ihq,' iht= ',iht
        print *,'!!! irfa= ',irfa,' iho= ',iho, ' iva= ',iva
        print *,' '
        STOP 96
      endif

      print *,'hold check, holdgfld%ipdtlen = ',holdgfld%ipdtlen
      do n = 1,holdgfld%ipdtlen
        print *,'hold check, n= ',n,' holdgfld%ipdtmpl= '
     &         ,holdgfld%ipdtmpl(n)
      enddo
cJ.Peng-----------------------------------------------------
      call getdata (lugb,lugi,kf,valid_pt,nlevsin,ilevs,maxlev
     &           ,readflag,xinpdatq,ifcsthour,iparmq,gribver,g2_jpdtn
     &           ,g2_model,igdret)

      call getdata (lugb,lugi,kf,valid_pt,nlevsin,ilevs,maxlev
     &           ,readflag,xinpdatt,ifcsthour,iparmt,gribver,g2_jpdtn
     &           ,g2_model,igdret)

c      call interp_data (kf,valid_pt,nlevsin,ilevs,maxlev,readflag
c     &                 ,xinpdat,xoutdat,xoutlevs_p,nlevsout,iidret)

      call rh_data(kf,ix,jy,nlevsout,xoutlevs_p, 
     &                 xinpdatq,xinpdatt,xoutdat)  
cJ.Peng-----------------------------------------------------
      call output_data (lout,kf,kpds,kgds,holdgfld,xoutdat,valid_pt
     &                ,xoutlevs_p,nlevsout,gribver,g2_model,iodret)
c      call output_data1(lout,kf,holdgfld,xoutdat
c     &                 ,xoutlevs_p,nlevsout,g2_model,iodret) 

      deallocate (xinpdatq)
      deallocate (xinpdatt)
      deallocate (xoutdat)
      deallocate (valid_pt)
      deallocate (readflag)
      deallocate (xoutlevs_p)

  899 continue
c 
      stop
      end
c
c---------------------------------------------------------------------
c
      subroutine rh_data(kf,ix,jy,nlevsout,xoutlevs_p,
     &                    xinpdatq,xinpdatt,xoutdat)
c
c     ABSTRACT: This routine calculates relative humidity

      implicit none
      integer      kf,ix,jy,nlevsout,nn
      integer      i,j,k
      real         xoutlevs_p(nlevsout) 
      real         xinpdatq(kf,nlevsout),
     &             xinpdatt(kf,nlevsout),xoutdat(kf,nlevsout)
      real         p2d(ix,jy),t2d(ix,jy),q2d(ix,jy),rh2d(ix,jy)

      print *,'*----------------------------------------------*'
      print *,'  Top of relative humidity subroutine rh_data'
      print *,'*----------------------------------------------*'
      print *,' '

      do k=1,nlevsout
        nn=0
        do j=1,jy
        do i=1,ix
          nn=nn+1
          p2d(i,j)=xoutlevs_p(k)*100.0
          q2d(i,j)=xinpdatq(nn,k)
          t2d(i,j)=xinpdatt(nn,k)
        enddo
        enddo

        call calrh_gfs(ix,jy,p2d,t2d,q2d,rh2d)

        nn=0
        do j=1,jy
        do i=1,ix
          nn=nn+1
          xoutdat(nn,k)=rh2d(i,j)*100.0
        enddo
        enddo
      enddo

      return
      end

c---------------------------------------------------------------------
c
c---------------------------------------------------------------------
      subroutine read_input_levels (lulv,maxlev,nlevsin,ilevs,iriret)
c 
c     ABSTRACT: This subroutine reads in a text file that contains
c     the number of input pressure levels for a given model.  The
c     format of the file goes like this, from upper levels to 
c     lower, for example:
c
c        1       200
c        2       250
c        3       500
c        4       700
c        5       850
c        6       925
c        7      1000
c
c
      implicit none

      integer    lulv,nlevsin,maxlev,iriret,inplev,ict,lvix
      integer    ilevs(maxlev)
c
      iriret=0
      ict = 0
      do while (.true.)
        
        print *,'Top of while loop in RH read_input_levels'

        read (lulv,85,end=130) lvix,inplev

        if (inplev > 0 .and. inplev <= 1000) then
          ict = ict + 1
          ilevs(ict) = inplev
        else
          print *,' '
          print *,'!!! ERROR: Input level not between 0 and 1000'
          print *,'!!!        in RH.  inplev= ',inplev
          print *,'!!! STOPPING EXECUTION'
          STOP 91
        endif

        print *,'RH readloop, ict= ',ict,' inplev= ',inplev

      enddo

   85 format (i4,1x,i4)
  130 continue

      nlevsin = ict

      print *,' '
      print *,'Total number of RH levels read in = ',nlevsin
c 
      return
      end

c---------------------------------------------------------------------
c
c---------------------------------------------------------------------
      subroutine getgridinfo (lugb,lugi,kf,kpds,kgds,holdgfld,ifcsthour
     &                       ,iparm,gribver,g2_jpdtn,iggret)      
c
c     ABSTRACT: The purpose of this subroutine is just to get the max
c     values of i and j and the dx and dy grid spacing intervals for the
c     grid to be used in the rest of the program.  So just read the
c     grib file to get the lon and lat data.  Also, get the info for
c     the data grid's boundaries.  This boundary information will be
c     used later in the tracking algorithm, and is accessed via Module
c     grid_bounds.
c
C     INPUT:
C     lugb     The Fortran unit number for the GRIB data file
C     lugi     The Fortran unit number for the GRIB index file
c     ifcsthour input forecast hour to search for
c     iparm    input grib parm to search for
c     gribver  integer (1 or 2) to indicate if using GRIB1 / GRIB2
c     g2_jpdtn If GRIB2 data being read, this is the value for JPDTN
c              that is input to getgb2.
C
C     OUTPUT:
c     kf       Number of gridpoints on the grid
c     kpds     pds array for a GRIB1 record
c     kgds     gds array for a GRIB1 record
c     holdgfld info for a GRIB2 record
c
C     iggret   The return code from this subroutine
c
      USE params
      USE grib_mod

      implicit none
c
      type(gribfield) :: gfld,prevfld,holdgfld
      integer,dimension(200) :: jids,jpdt,jgdt
      logical(1), allocatable :: lb(:)
      integer, parameter :: jf=4000000
      integer   jpds(200),jgds(200)
      integer   kpds(200),kgds(200)
      integer :: listsec1(13)
      integer   ila,ifa,iret,ifcsthour,imax,jmax,jskp,jdisc
      integer   lugb,lugi,kf,j,k,iggret,iparm,gribver,g2_jpdtn
      integer   jpdtn,jgdtn,npoints,icount,ipack,krec
      integer :: listsec0(2)=(/0,2/)
      integer :: igds(5)=(/0,0,0,0,0/),previgds(5)
      integer :: idrstmpl(200)
      integer :: currlen=1000000
      logical :: unpack=.true.
      logical :: open_grb=.false.
      real, allocatable :: f(:)
      real      dx,dy
c
      iggret = 0

      allocate (lb(jf),stat=ila) 
      allocate (f(jf),stat=ifa)
      if (ila /= 0 .or. ifa /= 0) then
        print *,' '
        print *,'!!! ERROR in RH.'
        print *,'!!! ERROR in getgridinfo allocating either lb or f'
        print *,'!!! ila = ',ila,' ifa= ',ifa
        iggret = 97
        return
      endif

      if (gribver == 2) then

        ! Search for a record from a GRIB2 file

        !
        ! ---  Initialize Variables ---
        !

        gfld%idsect => NULL()
        gfld%local => NULL()
        gfld%list_opt => NULL()
        gfld%igdtmpl => NULL()
        gfld%ipdtmpl => NULL()
        gfld%coord_list => NULL()
        gfld%idrtmpl => NULL()
        gfld%bmap => NULL()
        gfld%fld => NULL()

        jdisc=0 ! meteorological products
        jids=-9999
        jpdtn=g2_jpdtn ! 0 = analysis or forecast; 1 = ens fcst
        jgdtn=0 ! lat/lon grid
        jgdt=-9999
        jpdt=-9999

        npoints=0
        icount=0
        jskp=0

c       Search for Temperature or GP Height by production template....

        JPDT(1:15)=(/-9999,-9999,-9999,-9999,-9999,-9999,-9999,-9999
     &             ,-9999,-9999,-9999,-9999,-9999,-9999,-9999/)

        if (iparm == 7) then  ! SPFH
          jpdt(1) = 1   ! Param category from Table 4.1
          jpdt(2) = 0   ! Param number from Table 4.2-0-3
        elseif (iparm == 11) then  ! Temperature
          jpdt(1) = 0   ! Param category from Table 4.1
          jpdt(2) = 0   ! Param category from Table 4.2
        endif

        jpdt(9) = ifcsthour

        call getgb2(lugb,lugi,jskp,jdisc,jids,jpdtn,jpdt,jgdtn,jgdt
     &             ,unpack,krec,gfld,iret)
        if ( iret.ne.0) then
          print *,' '
          print *,' ERROR: getgb2 error in getgridinfo = ',iret
        endif

c       Determine packing information from GRIB2 file
c       The default packing is 40  JPEG 2000

        ipack = 40

        print *,' gfld%idrtnum = ', gfld%idrtnum

        !   Set DRT info  ( packing info )
        if ( gfld%idrtnum.eq.0 ) then      ! Simple packing
          ipack = 0
        elseif ( gfld%idrtnum.eq.2 ) then  ! Complex packing
          ipack = 2
        elseif ( gfld%idrtnum.eq.3 ) then  ! Complex & spatial packing
          ipack = 31
        elseif ( gfld%idrtnum.eq.40.or.gfld%idrtnum.eq.15 ) then
          ! JPEG 2000 packing
          ipack = 40
        elseif ( gfld%idrtnum.eq.41 ) then  ! PNG packing
          ipack = 41
        endif

        print *,'After check of idrtnum, ipack= ',ipack

        print *,'Number of gridpts= gfld%ngrdpts= ',gfld%ngrdpts
        print *,'Number of elements= gfld%igdtlen= ',gfld%igdtlen
        print *,'PDT num= gfld%ipdtnum= ',gfld%ipdtnum
        print *,'GDT num= gfld%igdtnum= ',gfld%igdtnum

        imax = gfld%igdtmpl(8)
        print *,'at A'
        jmax = gfld%igdtmpl(9)
        print *,'at B'
        dx   = float(gfld%igdtmpl(17))/1.e6
        print *,'at C'
        dy   = float(gfld%igdtmpl(17))/1.e6
        print *,'at D'
        kf   = gfld%ngrdpts
        print *,'at E'

        holdgfld = gfld

      else

        ! Search for a record from a GRIB1 file

        jpds = -1
        jgds = -1

        j=0

        jpds(5)  = iparm ! Get a record for the input parm selected
        jpds(6)  = 100   ! Get a record on a standard pressure level
        jpds(14) = ifcsthour
         
        call getgb(lugb,lugi,jf,j,jpds,jgds,
     &                       kf,k,kpds,kgds,lb,f,iret)
      
        if (iret.ne.0) then
          print *,' '
          print *,'!!! ERROR in RH getgridinfo calling getgb'
          print *,'!!! Return code from getgb = iret = ',iret
          iggret = iret
          return
        else
          iggret=0
          imax = kgds(2)
          jmax = kgds(3)
          dx   = float(kgds(9))/1000.
          dy   = float(kgds(10))/1000.
        endif

      endif
      
      print *,' '
      print *,'In RH getgridinfo, grid dimensions follow:'
      print *,'imax= ',imax,' jmax= ',jmax
      print *,'  dx= ',dx,'  dy= ',dy
      print *,'number of gridpoints = ',kf
      
      deallocate (lb); deallocate(f)
      
      return
      end

c---------------------------------------------------------------------
c
cJ.Peng        ------------------------------------------------------
      subroutine getdata (lugb,lugi,kf,valid_pt,nlevsin,ilevs,maxlev
     &             ,readflag,xinpdat,ifcsthour,iparm,gribver,g2_jpdtn
     &             ,g2_model,igdret)
c
c     ABSTRACT: This subroutine reads the input GRIB file for the
c     tracked parameters.

      USE params
      USE grib_mod

      implicit none
c
      type(gribfield) :: gfld,prevfld
      CHARACTER(len=8) :: pabbrev
      integer,dimension(200) :: jids,jpdt,jgdt
      logical(1)  valid_pt(kf),lb(kf),readflag(nlevsin)
      integer, parameter :: jf=4000000
      integer   ilevs(maxlev)
      integer   jpds(200),jgds(200),kpds(200),kgds(200)
      integer   lugb,lugi,kf,nlevsin,maxlev,igdret,jskp,jdisc
      integer   i,j,k,ict,np,lev,ifcsthour,iret,iparm,gribver,g2_jpdtn
cJ.Peng -------------------------------------------------------------      
      integer   g2_model
      integer   jpdtn,jgdtn,npoints,icount,ipack,krec
      integer   pdt_4p0_vert_level,pdt_4p0_vtime,mm
      integer :: listsec0(2)=(/0,2/)
      integer :: listsec1(13)
      integer :: igds(5)=(/0,0,0,0,0/),previgds(5)
      integer :: idrstmpl(200)
      integer :: currlen=1000000
      logical :: unpack=.true.
      logical :: open_grb=.false.
      real      f(kf),xinpdat(kf,nlevsin),xtemp(kf)
      real      dmin,dmax,firstval,lastval
c
      igdret=0
      ict = 0

      level_loop: do lev = 1,nlevsin

        print *,' '
        print *,'In RH getdata read loop, lev= ',lev,' level= '
     &         ,ilevs(lev)

        if (gribver == 2) then

          !
          ! ---  Initialize Variables ---
          !

          gfld%idsect => NULL()
          gfld%local => NULL()
          gfld%list_opt => NULL()
          gfld%igdtmpl => NULL()
          gfld%ipdtmpl => NULL()
          gfld%coord_list => NULL()
          gfld%idrtmpl => NULL()
          gfld%bmap => NULL()
          gfld%fld => NULL()

          jdisc=0  ! meteorological products
          jids=-9999
          jpdtn=g2_jpdtn  ! 0 = analysis or forecast; 1 = ens fcst
          jgdtn=0  ! lat/lon grid
          jgdt=-9999
          jpdt=-9999

          npoints=0
          icount=0
          jskp=0

c         Search for input parameter by production template 4.0.  This
c         RH program is used primarily for temperature, but still we
c         will leave that as a variable and not-hard wire it in case we
c         choose to average something else in the future.

          ! We are looking for Temperature or GP Height here.  This 
          ! block of code, or even the smaller subset block of code that
          ! contains the JPDT(1) and JPDT(2) assignments, can of course 
          ! be modified if this program is to be used for interpolating
          ! other variables....

          ! Set defaults for JPDT, then override in array
          ! assignments below...

          JPDT(1:15)=(/-9999,-9999,-9999,-9999,-9999,-9999,-9999,-9999
     &               ,-9999,-9999,-9999,-9999,-9999,-9999,-9999/)

          print *,' '
          print *,'In getdata RH, iparm= ',iparm

          if (iparm == 7) then  ! SPFH
            jpdt(1) = 1   ! Param category from Table 4.1
            jpdt(2) = 0   ! Param number from Table 4.2-0-3
          elseif (iparm == 11) then  ! Temperature
            jpdt(1) = 0   ! Param category from Table 4.1
            jpdt(2) = 0   ! Param category from Table 4.2
          endif

          JPDT(9)  = ifcsthour

cJ.Peng--------------------------------------------------------
          print *, "g2_model=", g2_model
          if(g2_model == 1 .or. g2_model == 10 
     &      .or. g2_model == 7 .or. g2_model == 22) then 
            JPDT(10) = 100 ! Isobaric surface requested (Table 4.5)
            JPDT(11) =  0
            JPDT(12) = ilevs(lev) * 100 ! value of specific level
          elseif (g2_model == 16 .or. g2_model == 15) then
            JPDT(10) = 100
            if (ilevs(lev) == 200 .or. ilevs(lev) == 500
     &       .or. ilevs(lev) == 700) then       
              JPDT(11) =  -4
              JPDT(12) = ilevs(lev)/100
            elseif(ilevs(lev) == 250 .or. ilevs(lev) == 850) then
              JPDT(11) =  -3
              JPDT(12) = ilevs(lev)/10
            elseif(ilevs(lev) == 925) then  
              JPDT(11) =  -2
              JPDT(12) = ilevs(lev)
            elseif(ilevs(lev) == 1000) then
              JPDT(11) =  -5
              JPDT(12) = ilevs(lev)/1000
            endif  
          endif  

          print *,'before getgb2 call, value of unpack = ',unpack

          do mm = 1,15
            print *,'RH getdata mm= ',mm,' JPDT(mm)= ',JPDT(mm)
          enddo

          call getgb2(lugb,lugi,jskp,jdisc,jids,jpdtn,jpdt,jgdtn,jgdt
     &             ,unpack,krec,gfld,iret)

          print *,'iret from getgb2 in getdata = ',iret

          print *,'after getgb2 call, value of unpacked = '
     &           ,gfld%unpacked

          print *,'after getgb2 call, gfld%ndpts = ',gfld%ndpts
          print *,'after getgb2 call, gfld%ibmap = ',gfld%ibmap

          if ( iret == 0) then

c           Determine packing information from GRIB2 file
c           The default packing is 40  JPEG 2000

            ipack = 40

            print *,' gfld%idrtnum = ', gfld%idrtnum

            !   Set DRT info  ( packing info )
            if ( gfld%idrtnum.eq.0 ) then      ! Simple packing
              ipack = 0
            elseif ( gfld%idrtnum.eq.2 ) then  ! Complex packing
              ipack = 2
            elseif ( gfld%idrtnum.eq.3 ) then  ! Complex & spatial
     &                                         ! packing
              ipack = 31
            elseif ( gfld%idrtnum.eq.40.or.gfld%idrtnum.eq.15 ) then
              ! JPEG 2000 packing
              ipack = 40
            elseif ( gfld%idrtnum.eq.41 ) then  ! PNG packing
              ipack = 41
            endif

            print *,'After check of idrtnum, ipack= ',ipack

            print *,'Number of gridpts= gfld%ngrdpts= ',gfld%ngrdpts
            print *,'Number of elements= gfld%igdtlen= ',gfld%igdtlen
            print *,'GDT num= gfld%igdtnum= ',gfld%igdtnum

            kf = gfld%ndpts  ! Number of gridpoints returned from read

            do np = 1,kf
              xinpdat(np,lev)  = gfld%fld(np)
              xtemp(np)        = gfld%fld(np)
              if (gfld%ibmap == 0) then
                valid_pt(np)     = gfld%bmap(np)
              else
                valid_pt(np)     = .true.
              endif
            enddo

            readflag(lev) = .TRUE.
c            call bitmapchk(kf,gfld%bmap,gfld%fld,dmin,dmax)
            call bitmapchk(kf,valid_pt,xtemp,dmin,dmax)

            if (ict == 0) then
c              do np = 1,kf
c                valid_pt(np) = gfld%bmap(np)
c              enddo
              ict = ict + 1
            endif

            firstval=gfld%fld(1)
            lastval=gfld%fld(kf)

            print *,' '
            print *,' SECTION 0: discipl= ',gfld%discipline
     &             ,' gribver= ',gfld%version
            print *,' '
            print *,' SECTION 1: '

            do j = 1,gfld%idsectlen
              print *,'     sect1, j= ',j,' gfld%idsect(j)= '
     &               ,gfld%idsect(j)
            enddo

            if ( associated(gfld%local).AND.gfld%locallen.gt.0) then
              print *,' '
              print *,' SECTION 2: ',gfld%locallen,' bytes'
            else
              print *,' '
              print *,' SECTION 2 DOES NOT EXIST IN THIS RECORD'
            endif

            print *,' '
            print *,' SECTION 3: griddef= ',gfld%griddef
            print *,'            ngrdpts= ',gfld%ngrdpts
            print *,'            numoct_opt= ',gfld%numoct_opt
            print *,'            interp_opt= ',gfld%interp_opt
            print *,'            igdtnum= ',gfld%igdtnum
            print *,'            igdtlen= ',gfld%igdtlen

            print *,' '
            print '(a17,i3,a2)',' GRID TEMPLATE 3.',gfld%igdtnum,': '
            do j=1,gfld%igdtlen
              print *,'    j= ',j,' gfld%igdtmpl(j)= ',gfld%igdtmpl(j)
            enddo

            print *,' '
            print *,'     PDT num (gfld%ipdtnum) = ',gfld%ipdtnum
            print *,' '
            print '(a20,i3,a2)',' PRODUCT TEMPLATE 4.',gfld%ipdtnum,': '
            do j=1,gfld%ipdtlen
              print *,'    sect 4  j= ',j,' gfld%ipdtmpl(j)= '
     &               ,gfld%ipdtmpl(j)
            enddo

c           Print out values for data representation type

            print *,' '
            print '(a21,i3,a2)',' DATA REP TEMPLATE 5.',gfld%idrtnum
     &            ,': '
            do j=1,gfld%idrtlen
              print *,'    sect 5  j= ',j,' gfld%idrtmpl(j)= '
     &               ,gfld%idrtmpl(j)
            enddo

c           Get parameter abbrev for record that was retrieved

            pdt_4p0_vtime      = gfld%ipdtmpl(9)

cJ.Peng---------------------------------------------------            
            pdt_4p0_vert_level = gfld%ipdtmpl(12)

            pabbrev=param_get_abbrev(gfld%discipline,gfld%ipdtmpl(1)
     &                              ,gfld%ipdtmpl(2))

            print *,' '
            write (6,131)
 131        format (' rec#   param     level  byy  bmm  bdd  bhh  '
     &             ,'fhr      npts  firstval    lastval     minval   '
     &             ,'   maxval')
            print '(i5,3x,a8,2x,6i5,2x,i8,4g12.4)'
     &          ,krec,pabbrev,pdt_4p0_vert_level,gfld%idsect(6)
     &             ,gfld%idsect(7),gfld%idsect(8),gfld%idsect(9)
     &             ,pdt_4p0_vtime,gfld%ndpts,firstval,lastval,dmin,dmax
c&          ,krec,pabbrev,pdt_4p0_vert_level/100,gfld%idsect(6)

            do np = 1,kf
              xinpdat(np,lev) = gfld%fld(np)
            enddo

          else

            print *,' '
            print *,'!!! ERROR: GRIB2 VINT READ IN GETDATA FAILED FOR '
     &             ,'LEVEL LEV= ',LEV
            print *,' '

            readflag(lev) = .FALSE.

            do np = 1,kf
              xinpdat(np,lev) = -99999.0
            enddo

          endif

        else

        ! Reading a GRIB1 file....

          jpds = -1
          jgds = -1
          j=0

          jpds(5) = iparm       ! grib parameter id to read in
          jpds(6) = 100         ! level id to indicate a pressure level
          jpds(7) = ilevs(lev)  ! actual level of the layer
          jpds(14) = ifcsthour  ! lead time to search for

          call getgb (lugb,lugi,jf,j,jpds,jgds,
     &                          kf,k,kpds,kgds,lb,f,iret)

          print *,' '
          print *,'After RH getgb call, j= ',j,' k= ',k,' level= '
     &           ,ilevs(lev),' iret= ',iret

          if (iret == 0) then

            readflag(lev) = .TRUE.
            call bitmapchk(kf,lb,f,dmin,dmax)

            if (ict == 0) then
              do np = 1,kf
                valid_pt(np) = lb(np)
              enddo
              ict = ict + 1
            endif

            write (6,31)
  31        format (' rec#  parm# levt lev  byy   bmm  bdd  bhh  fhr   '
     &             ,'npts  minval       maxval')
            print '(i4,2x,8i5,i8,2g12.4)',
     &           k,(kpds(i),i=5,11),kpds(14),kf,dmin,dmax

            do np = 1,kf
              xinpdat(np,lev) = f(np) 
            enddo

          else

            print *,' '
            print *,'!!! ERROR: VINT READ FAILED FOR LEVEL LEV= ',LEV
            print *,' '
  
            readflag(lev) = .FALSE.

            do np = 1,kf
              xinpdat(np,lev) = -99999.0
            enddo

          endif

        endif

      enddo level_loop
c
      return
      end
c
c-----------------------------------------------------------------------
c
c-----------------------------------------------------------------------
      subroutine interp_data (kf,valid_pt,nlevsin,ilevs,maxlev,readflag
     &                 ,xinpdat,xoutdat,xoutlevs_p,nlevsout,iidret)
c
c     ABSTRACT: This routine interpolates data in between available
c     pressure levels to get data resolution at the 50-mb
c     resolution that we need for the cyclone phase space
c     diagnostics.

      implicit none

      logical(1)   valid_pt(kf),readflag(nlevsin)
      integer      ilevs(maxlev)
      integer      nlevsin,nlevsout,maxlev,kf,kout,kin,k,n,kup,klo
      integer      iidret
      real         xinpdat(kf,nlevsin),xoutdat(kf,nlevsout)
      real         xoutlevs_p(nlevsout),xoutlevs_lnp(nlevsout)
      real         xinlevs_p(nlevsin),xinlevs_lnp(nlevsin)
      real         pdiff,pdiffmin,xu,xo,xl,yu,yl
c
      iidret=0
      print *,' '
      print *,'*----------------------------------------------*'
      print *,' Listing of standard output levels follows....'
      print *,'*----------------------------------------------*'
      print *,' '

      do k = 1,nlevsout
        xoutlevs_lnp(k) = log(xoutlevs_p(k))
        write (6,81) k,xoutlevs_p(k),xoutlevs_lnp(k)
      enddo
   81 format (1x,'k= ',i3,'    p= ',f6.1,'   ln(p)= ',f9.6)

      do k = 1,nlevsin
        xinlevs_p(k) = float(ilevs(k))
        xinlevs_lnp(k) = log(xinlevs_p(k))
      enddo

c     -----------------------------------------------------------------
c     We want to loop through for all the *output* levels that we need.
c     We may have some input levels that match perfectly, often at 
c     least the standard levels like 500, 700, 850.  For these levels, 
c     just take the data directly from the input file.  For other 
c     output levels that fall between the input levels, we need to 
c     find the nearest upper and lower levels.

      output_loop: do kout = 1,nlevsout

        print *,' '
        print *,'+------------------------------------------------+'
        print *,'Top of RH output_loop, kout= ',kout,'  pressure= '
     &         ,xoutlevs_p(kout)
        
        ! Loop through all of the input levels and find the level 
        ! that is closest to the  output level from the *upper* side.
        ! And again, in this upper loop, if we hit a level that 
        ! exactly matches a needed output level, just copy that data
        ! and then cycle back to the top of output_loop.

        kup = -999
        klo = -999

        pdiffmin = 9999.0

        inp_loop_up: do kin = 1,nlevsin
          if (xinlevs_p(kin) == xoutlevs_p(kout)) then
            print *,' '
            print *,'+++ Exact level found.  kout= ',kout
            print *,'+++                    level= ',xoutlevs_p(kout)
            print *,'+++ Data copied.  No interpolation needed.'
            if (readflag(kin)) then
              do n = 1,kf
                xoutdat(n,kout) = xinpdat(n,kin)
              enddo
              cycle  output_loop
            else
              print *,' '
              print *,'!!! ERROR: readflag is FALSE in interp_data for'
              print *,'!!! level kin= ',kin,', which is a level that '
              print *,'!!! exactly matches a required output level, and'
              print *,'!!! the user has identified as being an input '
              print *,'!!! level with valid data for this model.  We '
              print *,'!!! will get the data from a different level.'
            endif
          else
            pdiff = xoutlevs_p(kout) - xinlevs_p(kin)
            if (pdiff > 0.) then  ! We have a level higher than outlev
              if (pdiff < pdiffmin) then
                pdiffmin = pdiff
                kup = kin
              endif
            endif
          endif
        enddo inp_loop_up

        pdiffmin = 9999.0

        inp_loop_lo: do kin = 1,nlevsin
          pdiff = xinlevs_p(kin) - xoutlevs_p(kout)
          if (pdiff > 0.) then  ! We have a level lower than outlev
            if (pdiff < pdiffmin) then
              pdiffmin = pdiff
              klo = kin
            endif
          endif 
        enddo inp_loop_lo

        if (kup == -999 .or. klo == -999) then
          print *,' '
          print *,'!!! ERROR: While interpolating, could not find '
          print *,'!!! either an upper or lower input level to use'
          print *,'!!! for interpolating *from*.'
          print *,'!!! kup= ',kup,' klo= ',klo
          print *,' '
          print *,'!!! STOPPING....'
          stop 91
        endif

        if (.not. readflag(kup) .or. .not. readflag(klo)) then
          print *,' '
          print *,'!!! ERROR: In interp_data, either the upper or the'
          print *,'!!! lower input level closest to the target output'
          print *,'!!! level did not have valid data read in.'
          print *,'!!! '
          write (6,91) '  upper level k= ',kup,xinlevs_p(kup)
     &                ,xinlevs_lnp(kup)
          write (6,101) xoutlevs_p(kout),xoutlevs_lnp(kout)
          write (6,91) '  lower level k= ',klo,xinlevs_p(klo)
     &                ,xinlevs_lnp(klo)
          print *,'!!! readflag upper = ',readflag(kup)
          print *,'!!! readflag lower = ',readflag(klo)
          print *,'!!! EXITING....'
          stop 92
        endif

        print *,' '
        write (6,91) '  upper level k= ',kup,xinlevs_p(kup)
     &              ,xinlevs_lnp(kup)
        write (6,101) xoutlevs_p(kout),xoutlevs_lnp(kout)
        write (6,91) '  lower level k= ',klo,xinlevs_p(klo)
     &              ,xinlevs_lnp(klo)

   91   format (1x,a17,1x,i3,'  pressure= ',f6.1,' ln(p)= ',f9.6)
  101   format (13x,'Target output pressure= ',f6.1,' ln(p)= ',f9.6)

        !--------------------------------------------------------------
        ! Now perform the linear interpolation.  Here is the notation 
        ! used in the interpolation:
        ! 
        !  xu = ln of pressure at upper level
        !  xo = ln of pressure at output level
        !  xl = ln of pressure at lower level
        !  yu = data value at upper level
        !  yl = data value at lower level
        !--------------------------------------------------------------

        xu = xinlevs_lnp(kup)
        xo = xoutlevs_lnp(kout)
        xl = xinlevs_lnp(klo)

        do n = 1,kf
          yu = xinpdat(n,kup)
          yl = xinpdat(n,klo)
          xoutdat(n,kout) = ((yl * (xo - xu)) - (yu * (xo - xl))) 
     &                    / (xl - xu)
        enddo

      enddo output_loop
c
      return
      end
c
c----------------------------------------------------------------------
c
cJ.Peng  -------------------------------------------------------------
      subroutine output_data (lout,kf,kpds,kgds,holdgfld,xoutdat
     &        ,valid_pt,xoutlevs_p,nlevsout,gribver,g2_model,iodret)
c
c     ABSTRACT: This routine writes out the  output data on the 
c     specified output pressure levels.

      USE params
      USE grib_mod

      implicit none

      CHARACTER(len=1),pointer,dimension(:) :: cgrib
      type(gribfield) :: holdgfld
      logical(1) valid_pt(kf),bmap(kf)
      integer  lout,kf,lugb,lugi,iodret,nlevsout,igoret,ipret,lev
      integer  gribver,ierr,ipack,lengrib,npoints,newlen,idrsnum
      integer  numcoord,ica,n,j
      integer :: idrstmpl(200)
      integer :: currlen=1000000
      integer :: listsec0(2)=(/0,2/)
      integer :: igds(5)=(/0,0,0,0,0/),previgds(5)
      integer  kpds(200),kgds(200)
cJ.Peng----------------------------      
      integer  g2_model, ijk
      integer(4), parameter::idefnum=1
      integer(4) ideflist(idefnum),ibmap
      real     coordlist
      real     xoutdat(kf,nlevsout),xoutlevs_p(nlevsout)
c
      iodret=0
c      call baopenw (lout,"fort.51",igoret)
c      print *,'baopenw: igoret= ',igoret
c
c      if (igoret /= 0) then
c        print *,' '
c        print *,'!!! ERROR in RH in sub output_data opening'
c        print *,'!!! **OUTPUT** grib file.  baopenw return codes:'
c        print *,'!!! grib file 1 return code = igoret = ',igoret
c        STOP 95
c        return
c      endif

      levloop: do lev = 1,nlevsout

        if (gribver == 2) then
  
          ! Write data out as a GRIB2 message....

          allocate(cgrib(currlen),stat=ica)
          if (ica /= 0) then
            print *,' '
            print *,'ERROR in output_data allocating cgrib'
            print *,'ica=  ',ica
            iodret=95
            return
          endif

          !  Ensure that cgrib array is large enough

          if (holdgfld%ifldnum == 1 ) then    ! start new GRIB2 message
             npoints=holdgfld%ngrdpts
          else
             npoints=npoints+holdgfld%ngrdpts
          endif
          newlen=npoints*4
          if ( newlen.gt.currlen ) then
ccc            if (allocated(cgrib)) deallocate(cgrib)
            if (associated(cgrib)) deallocate(cgrib)
            allocate(cgrib(newlen),stat=ierr)
c            call realloc (cgrib,currlen,newlen,ierr)
            if (ierr == 0) then
              print *,' '
              print *,'re-allocate for large grib msg: '
              print *,'  currlen= ',currlen
              print *,'  newlen=  ',newlen
              currlen=newlen
            else
              print *,'ERROR returned from 2nd allocate cgrib = ',ierr
              stop 95
            endif
          endif

          !  Create new GRIB Message
          listsec0(1)=holdgfld%discipline
          listsec0(2)=holdgfld%version

          print *,'output, holdgfld%idsectlen= ',holdgfld%idsectlen
          do j = 1,holdgfld%idsectlen
            print *,'     sect1, j= ',j,' holdgfld%idsect(j)= '
     &             ,holdgfld%idsect(j)
          enddo

          call gribcreate(cgrib,currlen,listsec0,holdgfld%idsect,ierr)
          if (ierr.ne.0) then
             write(6,*) ' ERROR creating new GRIB2 field (gribcreate)= '
     &                  ,ierr
             stop 95
          endif

          previgds=igds
          igds(1)=holdgfld%griddef
          igds(2)=holdgfld%ngrdpts
          igds(3)=holdgfld%numoct_opt
          igds(4)=holdgfld%interp_opt
          igds(5)=holdgfld%igdtnum

          if (igds(3) == 0) then
            ideflist = 0
          endif

          call addgrid (cgrib,currlen,igds,holdgfld%igdtmpl
     &                 ,holdgfld%igdtlen,ideflist,idefnum,ierr)

          if (ierr.ne.0) then
            write(6,*) ' ERROR from addgrid adding GRIB2 grid = ',ierr
            stop 95
          endif

cJ.Peng----04-18-2017---definition for RH-------------------------
          holdgfld%ipdtmpl(1) = 1
          holdgfld%ipdtmpl(2) = 1
          holdgfld%ipdtmpl(14) = 0
          holdgfld%ipdtmpl(15) = 0

cJ.Peng-----2014-10-21 --------------------------------------------
c          holdgfld%ipdtmpl(12) = int(xoutlevs_p(lev)) * 100

          ijk = int(xoutlevs_p(lev))
          if(g2_model == 1 .or. g2_model == 10 .or. g2_model == 16
     & .or. g2_model == 7 .or. g2_model == 22 .or. g2_model == 15) then
            holdgfld%ipdtmpl(10) = 100 
            holdgfld%ipdtmpl(11) =  0
            holdgfld%ipdtmpl(12) = ijk * 100
          elseif(g2_model == 26) then
            holdgfld%ipdtmpl(10) = 100
            if( ijk == 300 .or. ijk == 400 .or. ijk == 500
     &       .or. ijk == 600 .or. ijk == 700 .or. ijk == 800
     &       .or. ijk == 900 ) then 
              holdgfld%ipdtmpl(11) = -4 
              holdgfld%ipdtmpl(12) = ijk/100
            elseif( ijk == 350 .or. ijk == 450 .or. ijk == 550
     &       .or. ijk == 650 .or. ijk == 750 .or. ijk == 850
     &       ) then
              holdgfld%ipdtmpl(11) = -3
              holdgfld%ipdtmpl(12) = ijk/10
            endif
          endif

          ipack      = 40
          idrsnum    = ipack
          idrstmpl   = 0

          idrstmpl(2)= holdgfld%idrtmpl(2)
cJ.Peng----04-18-2017---definition for RH-------------------------          
c          idrstmpl(3)= holdgfld%idrtmpl(3)
          idrstmpl(3)= 1

          idrstmpl(6)= 0
          idrstmpl(7)= 255

          numcoord=0
          coordlist=0.0  ! Only needed for hybrid vertical coordinate,
                         ! not here, so set it to 0.0

         ! 0   - A bit map applies to this product and is specified in
         ! this section
         ! 255 - A bit map does not apply to this product
         ibmap=255     ! Bitmap indicator (see Code Table 6.0)

         print *,' '
         print *,'output, holdgfld%ipdtlen= ',holdgfld%ipdtlen
         do n = 1,holdgfld%ipdtlen
           print *,'output, n= ',n,' holdgfld%ipdtmpl= '
     &            ,holdgfld%ipdtmpl(n)
         enddo

         print *,'output, kf= ',kf
c         do n = 1,kf
c           print *,'output, n= ',n,' xoutdat(n)= ',xoutdat(n)
c         enddo

         call addfield (cgrib,currlen,holdgfld%ipdtnum,holdgfld%ipdtmpl
     &                 ,holdgfld%ipdtlen,coordlist
     &                 ,numcoord
     &                 ,idrsnum,idrstmpl,200
     &                 ,xoutdat(1,lev),kf,ibmap,bmap,ierr)

          if (ierr /= 0) then
            write(6,*) ' ERROR from addfield adding GRIB2 data = ',ierr
            stop 95
          endif

!         Finalize  GRIB message after all grids
!         and fields have been added.  It adds the End Section ( "7777" )

          call gribend(cgrib,currlen,lengrib,ierr)
          call wryte(lout,lengrib,cgrib)

          if (ierr == 0) then
            print *,' '
            print *,'+++ GRIB2 write successful. '
            print *,'    Len of message = currlen= ',currlen
            print *,'    Len of entire GRIB2 message = lengrib= '
     &             ,lengrib
          else
            print *,' ERROR from gribend writing GRIB2 msg = ',ierr
            stop 95
          endif

        else

          ! Write data out as a GRIB1 message....

          kpds(7) = int(xoutlevs_p(lev))

          print *,'In RH, just before call to putgb, kf= ',kf
          call putgb (lout,kf,kpds,kgds,valid_pt,xoutdat(1,lev),ipret)
          print *,'In RH, just after call to putgb, kf= ',kf
          if (ipret == 0) then
            print *,' '
            print *,'+++ IPRET = 0 after call to putgb in RH'
            print *,' '
          else
            print *,' '
            print *,'!!!!!! ERROR in RH.'
            print *,'!!!!!! ERROR: IPRET NE 0 AFTER CALL TO PUTGB !!!'
            print *,'!!!!!!        Level index= ',lev
            print *,'!!!!!!           pressure= ',xoutlevs_p(lev)
            print *,' '
          endif

          write(*,980) kpds(1),kpds(2)
          write(*,981) kpds(3),kpds(4)
          write(*,982) kpds(5),kpds(6)
          write(*,983) kpds(7),kpds(8)
          write(*,984) kpds(9),kpds(10)
          write(*,985) kpds(11),kpds(12)
          write(*,986) kpds(13),kpds(14)
          write(*,987) kpds(15),kpds(16)
          write(*,988) kpds(17),kpds(18)
          write(*,989) kpds(19),kpds(20)
          write(*,990) kpds(21),kpds(22)
          write(*,991) kpds(23),kpds(24)
          write(*,992) kpds(25)
          write(*,880) kgds(1),kgds(2)
          write(*,881) kgds(3),kgds(4)
          write(*,882) kgds(5),kgds(6)
          write(*,883) kgds(7),kgds(8)
          write(*,884) kgds(9),kgds(10)
          write(*,885) kgds(11),kgds(12)
          write(*,886) kgds(13),kgds(14)
          write(*,887) kgds(15),kgds(16)
          write(*,888) kgds(17),kgds(18)
          write(*,889) kgds(19),kgds(20)
          write(*,890) kgds(21),kgds(22)

  980     format('    kpds(1)  = ',i7,'  kpds(2)  = ',i7)
  981     format('    kpds(3)  = ',i7,'  kpds(4)  = ',i7)
  982     format('    kpds(5)  = ',i7,'  kpds(6)  = ',i7)
  983     format('    kpds(7)  = ',i7,'  kpds(8)  = ',i7)
  984     format('    kpds(9)  = ',i7,'  kpds(10) = ',i7)
  985     format('    kpds(11) = ',i7,'  kpds(12) = ',i7)
  986     format('    kpds(13) = ',i7,'  kpds(14) = ',i7)
  987     format('    kpds(15) = ',i7,'  kpds(16) = ',i7)
  988     format('    kpds(17) = ',i7,'  kpds(18) = ',i7)
  989     format('    kpds(19) = ',i7,'  kpds(20) = ',i7)
  990     format('    kpds(21) = ',i7,'  kpds(22) = ',i7)
  991     format('    kpds(23) = ',i7,'  kpds(24) = ',i7)
  992     format('    kpds(25) = ',i7)
  880     format('    kgds(1)  = ',i7,'  kgds(2)  = ',i7)
  881     format('    kgds(3)  = ',i7,'  kgds(4)  = ',i7)
  882     format('    kgds(5)  = ',i7,'  kgds(6)  = ',i7)
  883     format('    kgds(7)  = ',i7,'  kgds(8)  = ',i7)
  884     format('    kgds(9)  = ',i7,'  kgds(10) = ',i7)
  885     format('    kgds(11) = ',i7,'  kgds(12) = ',i7)
  886     format('    kgds(13) = ',i7,'  kgds(14) = ',i7)
  887     format('    kgds(15) = ',i7,'  kgds(16) = ',i7)
  888     format('    kgds(17) = ',i7,'  kgds(18) = ',i7)
  889     format('    kgds(19) = ',i7,'  kgds(20) = ',i7)
  890     format('    kgds(20) = ',i7,'  kgds(22) = ',i7)

        endif

      enddo levloop
c
      return
      end
c
c-----------------------------------------------------------------------
c
c-----------------------------------------------------------------------
      subroutine open_grib_files (lugb,lugi,lout,gribver,iret)

C     ABSTRACT: This subroutine must be called before any attempt is
C     made to read from the input GRIB files.  The GRIB and index files
C     are opened with a call to baopenr.  This call to baopenr was not
C     needed in the cray version of this program (the files could be
C     opened with a simple Cray assign statement), but the GRIB-reading
C     utilities on the SP do require calls to this subroutine (it has
C     something to do with the GRIB I/O being done in C on the SP, and
C     the C I/O package needs an explicit open statement).
C
C     INPUT:
C     lugb     The Fortran unit number for the GRIB data file
C     lugi     The Fortran unit number for the GRIB index file
C     lout     The Fortran unit number for the  output grib file
c     gribver  integer (1 or 2) to indicate if using GRIB1 / GRIB2
C
C     OUTPUT:
C     iret     The return code from this subroutine

      implicit none

      character(2)   lugb_c,lugi_c,lout_c
c      character(120) fnameg,fnamei,fnameo
cPeng 05/28/2018 Bug Fixed for FV3-GFS Job Crashed.
      character(255) fnameg,fnamei,fnameo
      character(6)   enameb,enamei,enameo
      integer   iret,gribver,lugb,lugi,lout,igoret,iioret,iooret

      iret=0
      write(lugb_c,'(i2)')lugb
      write(lugi_c,'(i2)')lugi
      write(lout_c,'(i2)')lout
      enameb='FORT'//adjustl(lugb_c)
      enamei='FORT'//adjustl(lugi_c)
      enameo='FORT'//adjustl(lout_c)
      call get_environment_variable(enameb, fnameg, status=igoret)
      call get_environment_variable(enamei, fnamei, status=iioret)
      call get_environment_variable(enameo, fnameo, status=iooret)
      if (igoret /= 0 .or. iioret /= 0 .or. iooret /= 0) then
        fnameg(1:5) = "fort."
        fnamei(1:5) = "fort."
        fnameo(1:5) = "fort."
        write(fnameg(6:7),'(I2)') lugb
        write(fnamei(6:7),'(I2)') lugi
        write(fnameo(6:7),'(I2)') lout
      endif
      call baopenr (lugb,fnameg,igoret)
      call baopenr (lugi,fnamei,iioret)
      call baopenw (lout,fnameo,iooret)

      print *,' '
      print *,'RH:  baopen: igoret= ',igoret,' iioret= ',iioret
     &       ,' iooret= ',iooret
      
      if (igoret /= 0 .or. iioret /= 0 .or. iooret /= 0) then
        print *,' '
        print *,'!!! ERROR in RH.'
        print *,'!!! ERROR in sub open_grib_files opening grib file'
        print *,'!!! or grib index file.  baopen return codes:'
        print *,'!!! grib  file return code = igoret = ',igoret
        print *,'!!! index file return code = iioret = ',iioret
        print *,'!!! output file return code = iooret = ',iooret
        iret = 93
        return
      endif

      return
      end
c
c-------------------------------------------------------------------
c
c-------------------------------------------------------------------
      subroutine bitmapchk (n,ld,d,dmin,dmax)
c
c     This subroutine checks the bitmap for non-existent data values.
c     Since the data from the regional models have been interpolated
c     from either a polar stereographic or lambert conformal grid
c     onto a lat/lon grid, there will be some gridpoints around the
c     edges of this lat/lon grid that have no data; these grid
c     points have been bitmapped out by Mark Iredell's interpolater.
c     To provide another means of checking for invalid data points
c     later in the program, set these bitmapped data values to a
c     value of -999.0.  The min and max of this array are also
c     returned if a user wants to check for reasonable values.
c
      logical(1) ld
      dimension  ld(n),d(n)
c
      dmin=1.E15
      dmax=-1.E15
c
      do i=1,n
        if (ld(i)) then
          dmin=min(dmin,d(i))
          dmax=max(dmax,d(i))
        else
          d(i) = -999.0
        endif
      enddo
c
      return
      end

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c------------------------------------------------------------------------
      SUBROUTINE CALRH_GFS(ix,jy,P1,T1,Q1,RH)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!                .      .    .     
! SUBPROGRAM:    CALRH       COMPUTES RELATIVE HUMIDITY
!   PRGRMMR: TREADON         ORG: W/NP2      DATE: 92-12-22       
!     
! ABSTRACT:  
!     THIS ROUTINE COMPUTES RELATIVE HUMIDITY GIVEN PRESSURE, 
!     TEMPERATURE, SPECIFIC HUMIDITY. AN UPPER AND LOWER BOUND
!     OF 100 AND 1 PERCENT RELATIVE HUMIDITY IS ENFORCED.  WHEN
!     THESE BOUNDS ARE APPLIED THE PASSED SPECIFIC HUMIDITY 
!     ARRAY IS ADJUSTED AS NECESSARY TO PRODUCE THE SET RELATIVE
!     HUMIDITY.
!   .     
!     
! PROGRAM HISTORY LOG:
!   ??-??-??  DENNIS DEAVEN
!   92-12-22  RUSS TREADON - MODIFIED AS DESCRIBED ABOVE.
!   98-06-08  T BLACK      - CONVERSION FROM 1-D TO 2-D
!   98-08-18  MIKE BALDWIN - MODIFY TO COMPUTE RH OVER ICE AS IN MODEL
!   98-12-16  GEOFF MANIKIN - UNDO RH COMPUTATION OVER ICE
!   00-01-04  JIM TUCCILLO - MPI VERSION
!   02-06-11  MIKE BALDWIN - WRF VERSION
!     
! USAGE:    CALL CALRH(P1,T1,Q1,RH)
!   INPUT ARGUMENT LIST:
!     P1     - PRESSURE (PA)
!     T1     - TEMPERATURE (K)
!     Q1     - SPECIFIC HUMIDITY (KG/KG)
!
!   OUTPUT ARGUMENT LIST: 
!     RH     - RELATIVE HUMIDITY  (DECIMAL FORM)
!     Q1     - ADJUSTED SPECIFIC HUMIDITY (KG/KG)
!     
!   OUTPUT FILES:
!     NONE
!     
!   SUBPROGRAMS CALLED:
!     UTILITIES:
!     LIBRARY:
!       NONE
!     
!   ATTRIBUTES:
!     LANGUAGE: FORTRAN
!     MACHINE : CRAY C-90
!$$$  
!
c      use params_mod, only: rhmin
c      use ctlblk_mod, only: jsta, jend, spval, im, jm
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      implicit none
!
      real,parameter:: con_rd      =2.8705e+2 ! gas constant air    (J/kg/K)
      real,parameter:: con_rv      =4.6150e+2 ! gas constant H2O 
      real,parameter:: con_eps     =con_rd/con_rv
      real,parameter:: con_epsm1   =con_rd/con_rv-1

      real :: spval=9.9e10
      real, parameter :: rhmin=1.0E-6     ! minimal RH bound

!      real,external::FPVSNEW

      INTERFACE
        ELEMENTAL FUNCTION FPVSNEW (t)
          REAL  FPVSNEW
          REAL, INTENT(IN) :: t
        END FUNCTION FPVSNEW
      END INTERFACE
!
c      REAL,dimension(IM,JM),intent(in):: P1,T1
c      REAL,dimension(IM,JM),intent(inout):: Q1,RH
      REAL,dimension(ix,jy),intent(in):: P1,T1
      REAL,dimension(ix,jy),intent(inout):: Q1,RH

      REAL ES,QC
      integer :: I,J
      integer :: jsta, jend, im, jm, ix, jy
!***************************************************************
      JSTA=1
      JEND=jy
      IM=ix
      JM=jy
!
!     START CALRH.
!
      DO J=JSTA,JEND
      DO I=1,IM
        IF (T1(I,J).LT.SPVAL .AND. P1(I,J).LT.SPVAL
     &         .AND.Q1(I,J)/=SPVAL) THEN
          IF (ABS(P1(I,J)).GT.1) THEN
	    ES=FPVSNEW(T1(I,J))
	    ES=MIN(ES,P1(I,J))
	    QC=CON_EPS*ES/(P1(I,J)+CON_EPSM1*ES)
!           QC=PQ0/P1(I,J)
!     1          *EXP(A2*(T1(I,J)-A3)/(T1(I,J)-A4))

            RH(I,J)=Q1(I,J)/QC

!   BOUNDS CHECK
!
            IF (RH(I,J).GT.1.0) THEN
              RH(I,J)=1.0
              Q1(I,J)=RH(I,J)*QC
            ENDIF
!           IF (RH(I,J).LT.0.01) THEN
            IF (RH(I,J).LT.RHmin) THEN  !use smaller RH limit for stratosphere
              RH(I,J)=RHmin
              Q1(I,J)=RH(I,J)*QC
            ENDIF
          ENDIF
        ELSE
          RH(I,J)=SPVAL
        ENDIF
      ENDDO
      ENDDO

      RETURN
      END
c-----------------------------------------------------------------------------      
      elemental function fpvsnew(t)
!$$$     Subprogram Documentation Block
!
! Subprogram: fpvsnew         Compute saturation vapor pressure
!   Author: N Phillips            w/NMC2X2   Date: 30 dec 82
!
! Abstract: Compute saturation vapor pressure from the temperature.
!   A linear interpolation is done between values in a lookup table
!   computed in gpvs. See documentation for fpvsx for details.
!   Input values outside table range are reset to table extrema.
!   The interpolation accuracy is almost 6 decimal places.
!   On the Cray, fpvs is about 4 times faster than exact calculation.
!   This function should be expanded inline in the calling routine.
!
! Program History Log:
!   91-05-07  Iredell             made into inlinable function
!   94-12-30  Iredell             expand table
! 1999-03-01  Iredell             f90 module
! 2001-02-26  Iredell             ice phase
!
! Usage:   pvs=fpvsnew(t)
!
!   Input argument list:
!     t          Real(krealfp) temperature in Kelvin
!
!   Output argument list:
!     fpvsnew       Real(krealfp) saturation vapor pressure in Pascals
!
! Attributes:
!   Language: Fortran 90.
!
!$$$
      implicit none
      integer,parameter:: nxpvs=7501
      real,parameter:: con_ttp     =2.7316e+2 ! temp at H2O 3pt
      real,parameter:: con_psat    =6.1078e+2 ! pres at H2O 3pt
      real,parameter:: con_cvap    =1.8460e+3 ! spec heat H2O gas   (J/kg/K)
      real,parameter:: con_cliq    =4.1855e+3 ! spec heat H2O liq
      real,parameter:: con_hvap    =2.5000e+6 ! lat heat H2O cond
      real,parameter:: con_rv      =4.6150e+2 ! gas constant H2O
      real,parameter:: con_csol    =2.1060e+3 ! spec heat H2O ice
      real,parameter:: con_hfus    =3.3358e+5 ! lat heat H2O fusion
      real,parameter:: tliq=con_ttp
      real,parameter:: tice=con_ttp-20.0
      real,parameter:: dldtl=con_cvap-con_cliq
      real,parameter:: heatl=con_hvap
      real,parameter:: xponal=-dldtl/con_rv
      real,parameter:: xponbl=-dldtl/con_rv+heatl/(con_rv*con_ttp)
      real,parameter:: dldti=con_cvap-con_csol
      real,parameter:: heati=con_hvap+con_hfus
      real,parameter:: xponai=-dldti/con_rv
      real,parameter:: xponbi=-dldti/con_rv+heati/(con_rv*con_ttp)
      real tr,w,pvl,pvi
      real fpvsnew
      real,intent(in):: t
      integer jx
      real  xj,x,tbpvs(nxpvs),xp1
      real xmin,xmax,xinc,c2xpvs,c1xpvs
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      xmin=180.0
      xmax=330.0
      xinc=(xmax-xmin)/(nxpvs-1)
!   c1xpvs=1.-xmin/xinc
      c2xpvs=1./xinc
      c1xpvs=1.-xmin*c2xpvs
!    xj=min(max(c1xpvs+c2xpvs*t,1.0),real(nxpvs,krealfp))
      xj=min(max(c1xpvs+c2xpvs*t,1.0),float(nxpvs))
      jx=min(xj,float(nxpvs)-1.0)
      x=xmin+(jx-1)*xinc
      
      tr=con_ttp/x
      if(x.ge.tliq) then
        tbpvs(jx)=con_psat*(tr**xponal)*exp(xponbl*(1.-tr))
      elseif(x.lt.tice) then
        tbpvs(jx)=con_psat*(tr**xponai)*exp(xponbi*(1.-tr))
      else
        w=(t-tice)/(tliq-tice)
        pvl=con_psat*(tr**xponal)*exp(xponbl*(1.-tr))
        pvi=con_psat*(tr**xponai)*exp(xponbi*(1.-tr))
        tbpvs(jx)=w*pvl+(1.-w)*pvi
      endif
      
      xp1=xmin+(jx-1+1)*xinc      
     
      tr=con_ttp/xp1
      if(xp1.ge.tliq) then
        tbpvs(jx+1)=con_psat*(tr**xponal)*exp(xponbl*(1.-tr))
      elseif(xp1.lt.tice) then
        tbpvs(jx+1)=con_psat*(tr**xponai)*exp(xponbi*(1.-tr))
      else
        w=(t-tice)/(tliq-tice)
        pvl=con_psat*(tr**xponal)*exp(xponbl*(1.-tr))
        pvi=con_psat*(tr**xponai)*exp(xponbi*(1.-tr))
        tbpvs(jx+1)=w*pvl+(1.-w)*pvi
      endif
      
      fpvsnew=tbpvs(jx)+(xj-jx)*(tbpvs(jx+1)-tbpvs(jx))
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      end function fpvsnew
c-----------------------------------------------------------------------
c
c-----------------------------------------------------------------------
      subroutine output_data1(lout,kf,holdgfld,xoutdat
     &                ,xoutlevs_p,nlevsout,g2_model,iodret)
c
c     ABSTRACT: This routine writes out the  output data on the
c     specified output pressure levels.

      USE params
      USE grib_mod
      
      implicit none
      type(gribfield) :: holdgfld
      integer  lout,kf,nlevsout,g2_model,iodret,lev
      integer  ijk,ierr1,nn
      real xoutdat(kf,nlevsout),xoutlevs_p(nlevsout)
      real     f(kf)

      iodret=0
      ierr1=0

      levloop: do lev = 1,nlevsout
cJ.Peng----04-18-2017---definition for RH--
        holdgfld%ipdtmpl(1) = 1
        holdgfld%ipdtmpl(2) = 1
        holdgfld%ipdtmpl(14) =  0
        holdgfld%ipdtmpl(15) =  0

        ijk = int(xoutlevs_p(lev))
        if(g2_model == 1 .or. g2_model == 10 .or. g2_model == 16
     & .or. g2_model == 7 .or. g2_model == 22 .or. g2_model == 15) then
          holdgfld%ipdtmpl(10) = 100
          holdgfld%ipdtmpl(11) =  0
          holdgfld%ipdtmpl(12) = ijk * 100
        endif

cJ.Peng----04-18-2017---definition for RH--decimal scale factor-----
        holdgfld%idrtmpl(3) = 1

        do nn=1,kf
          f(nn)=xoutdat(nn,lev)
        enddo

        holdgfld%fld(1:kf)=f(1:kf)
        call putgb2(lout,holdgfld,ierr1)
        
        if (ierr1 .eq. 0) then
          print *,'+++ GRIB2 write successful. '
          iodret=0
        else
          print *,' ERROR from putgb2 adding GRIB2 data = ',ierr1
          iodret=ierr1
        endif

      enddo levloop
      return
      end
