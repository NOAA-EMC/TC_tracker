      program tave
c
c     ABSTRACT: This program averages the temperatures from an input 
c     grib file and produces an output grib file containing the mean
c     temperature in the 300-500 mb layer.  For each model and each
c     lead time, there will need to be data from 300 to 500 mb in 
c     50 mb increments, such that all 5 of these layers then get
c     averaged together.
c
c     Written by Tim Marchok

      implicit none

      integer, parameter :: lugb=11,lulv=16,lugi=31,lout=51
      integer, parameter :: nlevsout=1,nlevsin=5
      integer  kpds(200),kgds(200)
      integer  iriret,iogret,kf,iggret,igdret,iidret
      integer  iha,iho,iva,irfa,iodret,ifcsthour,iia,iparm
      integer  ilevs(nlevsin)
      real, allocatable :: xinptmp(:,:),xouttmp(:)
      logical(1), allocatable :: valid_pt(:),readflag(:)
      real     xoutlev

      namelist/timein/ifcsthour,iparm
c
      data ilevs   /300, 350, 400, 450, 500/
      xoutlev = 401.
c
      read (5,NML=timein,END=201)
  201 continue
      print *,' '
      print *,'*---------------------------------------------*'
      print *,' '
      print *,' +++ Top of tave +++ '
      print *,' '
      print *,'After tave namelist read, input forecast hour= '
     &       ,ifcsthour
      print *,'                          input GRIB parm= ',iparm

c      ilevs = -999
c      call read_input_levels (lulv,nlevsin,ilevs,iriret)
c
c      if (iriret /= 0) then
c        print *,' '
c        print *,'!!! RETURN CODE FROM read_input_levels /= 0'
c        print *,'!!! RETURN CODE = iriret = ',iriret
c        print *,'!!! EXITING....'
c        print *,' '
c        goto 899
c      endif

      call open_grib_files (lugb,lugi,lout,iogret)

      if (iogret /= 0) then
        print '(/,a45,i4,/)','!!! ERROR: in tave open_grib_files, rc= '
     &        ,iogret
        STOP 93
      endif

      call getgridinfo (lugb,lugi,kf,kpds,kgds,ifcsthour,iparm,iggret)

      allocate (xinptmp(kf,nlevsin),stat=iha)
      allocate (xouttmp(kf),stat=iho)
      allocate (valid_pt(kf),stat=iva)
      allocate (readflag(nlevsin),stat=irfa)
      if (iha /= 0 .or. iho /= 0 .or. iva /= 0 .or. irfa /= 0) then
        print *,' '
        print *,'!!! ERROR in tave allocating arrays.'
        print *,'!!! ERROR allocating the xinptmp, readflag, or the'
        print *,'!!! valid_pt array, iha= ',iha,' iva= ',iva
        print *,'!!! irfa= ',irfa,' iho= ',iho
        print *,'  '
        STOP 96
      endif

      call getdata (lugb,lugi,kf,valid_pt,nlevsin,ilevs
     &             ,readflag,xinptmp,ifcsthour,iparm,igdret)

      call average_data (kf,valid_pt,nlevsin,ilevs,readflag
     &                  ,xinptmp,xouttmp,iidret)

      call output_data (lout,kf,kpds,kgds,xouttmp,valid_pt
     &                ,xoutlev,nlevsout,iodret)

      deallocate (xinptmp)
      deallocate (xouttmp)
      deallocate (valid_pt)
      deallocate (readflag)

  899 continue
c 
      stop
      end
c
c---------------------------------------------------------------------
c
c---------------------------------------------------------------------
      subroutine read_input_levels (lulv,nlevsin,ilevs,iriret)
c 
c     ABSTRACT: This subroutine reads in a text file that contains
c     the number of input pressure levels for a given model.  The
c     format of the file goes like this, from upper levels to 
c     lower, for example:
c
c        1       200
c        2       400
c        3       500
c        4       700
c        5       850
c        6       925
c        7      1000
c
c
      implicit none

      integer    lulv,nlevsin,iriret,inplev,ict,lvix
      integer    ilevs(nlevsin)
c
      ict = 0
      do while (.true.)
        
        print *,'Top of while loop in tave read_input_levels'

        read (lulv,85,end=130) lvix,inplev

        if (inplev > 0 .and. inplev <= 1000) then
          ict = ict + 1
          ilevs(ict) = inplev
        else
          print *,' '
          print *,'!!! ERROR: Input level not between 0 and 1000'
          print *,'!!!        in tave.  inplev= ',inplev
          print *,'!!! STOPPING EXECUTION'
          STOP 91
        endif

        print *,'tave readloop, ict= ',ict,' inplev= ',inplev

      enddo

   85 format (i4,1x,i4)
  130 continue

      nlevsin = ict

      print *,' '
      print *,'Total number of tave levels read in = ',nlevsin
c 
      return
      end

c---------------------------------------------------------------------
c
c---------------------------------------------------------------------
      subroutine getgridinfo (lugb,lugi,kf,kpds,kgds,ifcsthour,iparm
     &                       ,iggret)
c
c     ABSTRACT: The purpose of this subroutine is just to get the max
c     values of i and j and the dx and dy grid spacing intervals for the
c     grid to be used in the rest of the program.  So just read the
c     grib file to get the lon and lat data.  Also, get the info for
c     the data grid's boundaries.  This boundary information will be
c     used later in the tracking algorithm, and is accessed via Module
c     grid_bounds.
c
      implicit none
c
      logical(1), allocatable :: lb(:)
      integer, parameter :: jf=4000000
      integer   jpds(200),jgds(200)
      integer   kpds(200),kgds(200)
      integer   ila,ifa,iret,ifcsthour,imax,jmax
      integer   lugb,lugi,kf,j,k,iggret,iparm
      real, allocatable :: f(:)
      real      dx,dy
c
      iggret = 0

      allocate (lb(jf),stat=ila) 
      allocate (f(jf),stat=ifa)
      if (ila /= 0 .or. ifa /= 0) then
        print *,' '
        print *,'!!! ERROR in tave.'
        print *,'!!! ERROR in getgridinfo allocating either lb or f'
        print *,'!!! ila = ',ila,' ifa= ',ifa
        iggret = 97
        return
      endif

      jpds = -1
      jgds = -1

      j=0

      jpds(5)  = iparm  ! Get a temperature record
      jpds(6)  = 100    ! Get a record on a standard pressure level
      jpds(14) = ifcsthour
         
      call getgb(lugb,lugi,jf,j,jpds,jgds,
     &                     kf,k,kpds,kgds,lb,f,iret)

      if (iret.ne.0) then
        print *,' '
        print *,'!!! ERROR in tave getgridinfo calling getgb'
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

      print *,' '
      print *,'In getgridinfo, grid dimensions follow:'
      print *,'imax= ',imax,' jmax= ',jmax
      print *,'  dx= ',dx,'  dy= ',dy
      print *,'number of gridpoints = ',kf
      
      deallocate (lb); deallocate(f)
      
      return
      end

c---------------------------------------------------------------------
c
c---------------------------------------------------------------------
      subroutine getdata (lugb,lugi,kf,valid_pt,nlevsin,ilevs
     &             ,readflag,xinptmp,ifcsthour,iparm,igdret)
c
c     ABSTRACT: This subroutine reads the input GRIB file for the
c     tracked parameters.

      implicit none
c
      logical(1)  valid_pt(kf),lb(kf),readflag(nlevsin)
      integer, parameter :: jf=4000000
      integer   ilevs(nlevsin)
      integer   jpds(200),jgds(200),kpds(200),kgds(200)
      integer   lugb,lugi,kf,nlevsin,igdret,iparm
      integer   i,j,k,ict,np,lev,ifcsthour,iret
      real      f(kf),xinptmp(kf,nlevsin)
      real      dmin,dmax
c
      ict = 0

      level_loop: do lev = 1,nlevsin

        print *,' '
        print *,'In tave getdata read loop, lev= ',lev,' level= '
     &         ,ilevs(lev)

        jpds = -1
        jgds = -1
        j=0

        jpds(5) = iparm       ! parameter id for temperature
        jpds(6) = 100         ! level id to indicate a pressure level
        jpds(7) = ilevs(lev)  ! actual level of the layer
        jpds(14) = ifcsthour  ! lead time to search for

        call getgb (lugb,lugi,jf,j,jpds,jgds,
     &                        kf,k,kpds,kgds,lb,f,iret)

        print *,' '
        print *,'After tave getgb call, j= ',j,' k= ',k,' level= '
     &         ,ilevs(lev),' iret= ',iret

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
  31      format (' rec#  parm# levt lev  byy   bmm  bdd  bhh  fhr   np'
     &           ,'ts  minval       maxval')
          print '(i4,2x,8i5,i8,2g12.4)',
     &         k,(kpds(i),i=5,11),kpds(14),kf,dmin,dmax

          do np = 1,kf
            xinptmp(np,lev) = f(np) 
          enddo

        else

          print *,' '
          print *,'!!! ERROR: TAVE READ FAILED FOR LEVEL LEV= ',LEV
          print *,' '

          readflag(lev) = .FALSE.

          do np = 1,kf
            xinptmp(np,lev) = -99999.0
          enddo

        endif

      enddo level_loop
c
      return
      end
c
c-----------------------------------------------------------------------
c
c-----------------------------------------------------------------------
      subroutine average_data (kf,valid_pt,nlevsin,ilevs,readflag
     &                 ,xinptmp,xouttmp,iidret)
c
c     ABSTRACT: This routine averages data between 300 and 500 mb to get
c     a mean temperature at 400 mb.  The input data should be at 50 mb 
c     resolution, giving 5 input levels in total.

      implicit none

      logical(1)   valid_pt(kf),readflag(nlevsin)
      integer      ilevs(nlevsin)
      integer      nlevsin,kf,k,n,iidret
      real         xinptmp(kf,nlevsin),xouttmp(kf)
      real         xinlevs_p(nlevsin),xinlevs_lnp(nlevsin)
      real         xsum
c
      print *,'*----------------------------------------------*'
      print *,'         Top of average data routine'
      print *,'*----------------------------------------------*'
      print *,' '

      do n = 1,kf
        xsum = 0.0
        do k = 1,nlevsin
          xsum = xsum + xinptmp(n,k)
        enddo
        xouttmp(n) = xsum / float(nlevsin)
      enddo
c
      return
      end
c
c----------------------------------------------------------------------
c
c----------------------------------------------------------------------
      subroutine output_data (lout,kf,kpds,kgds,xouttmp,valid_pt
     &                      ,xoutlev,nlevsout,iodret)
c
c     ABSTRACT: This routine writes out the  output data on the 
c     specified output pressure levels.

      implicit none

      logical(1) valid_pt(kf)
      integer  lout,kf,lugb,lugi,iodret,nlevsout,igoret,ipret,lev
      integer  kpds(200),kgds(200)
      real     xouttmp(kf),xoutlev
c
c      call baopenw (lout,"fort.51",igoret)
c      print *,'baopenw: igoret= ',igoret
c
c      if (igoret /= 0) then
c        print *,' '
c        print *,'!!! ERROR in sub output_data opening'
c        print *,'!!! **OUTPUT** grib file.  baopenw return codes:'
c        print *,'!!! grib file 1 return code = igoret = ',igoret
c        STOP 95
c        return
c      endif

c      kpds(7)  =     850  ;    kpds(8)  =      02
c      kpds(9)  =      11  ;    kpds(10) =       4
c      kpds(11) =       0  ;    kpds(12) =       0
c      kpds(13) =       1  ;    kpds(14) =  ifcsthour
c      kpds(15) =       0  ;    kpds(16) =      10
c      kpds(17) =       0  ;    kpds(18) =       1
c      kpds(19) =       2  ;    kpds(20) =       0
c      kpds(21) =      21  ;    kpds(22) =       0
c      kpds(23) =       0  ;    kpds(24) =       0
c      kpds(25) =       0
c      kgds(1)  =       0  ;    kgds(2)  =    imax
c      kgds(3)  =    jmax  ;    kgds(4)  =   90000
c      kgds(5)  =       0  ;    kgds(6)  =     128
c      kgds(7)  =  -90000  ;    kgds(8)  =   -1000
c      kgds(9)  =    1000  ;    kgds(10) =    1000
c      kgds(11) =       0  ;    kgds(12) =       0
c      kgds(13) =       0  ;    kgds(14) =       0
c      kgds(15) =       0  ;    kgds(16) =       0
c      kgds(17) =       0  ;    kgds(18) =       0
c      kgds(19) =       0  ;    kgds(20) =     255

      kpds(6) = 100

      do lev = 1,nlevsout 

        kpds(7) = int(xoutlev)

        print *,'tave:  just before call to putgb, kf= ',kf
        call putgb (lout,kf,kpds,kgds,valid_pt,xouttmp,ipret)
        print *,'tave:  just after call to putgb, kf= ',kf
        if (ipret == 0) then
          print *,' '
          print *,'+++ IPRET = 0 after call to putgb'
          print *,' '
        else
          print *,' '
          print *,'!!!!!! ERROR in tave'
          print *,'!!!!!! ERROR: IPRET NE 0 AFTER CALL TO PUTGB !!!'
          print *,'!!!!!!        Level index= ',lev
          print *,'!!!!!!           pressure= ',xoutlev
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

      enddo

  980 format('    kpds(1)  = ',i7,'  kpds(2)  = ',i7)
  981 format('    kpds(3)  = ',i7,'  kpds(4)  = ',i7)
  982 format('    kpds(5)  = ',i7,'  kpds(6)  = ',i7)
  983 format('    kpds(7)  = ',i7,'  kpds(8)  = ',i7)
  984 format('    kpds(9)  = ',i7,'  kpds(10) = ',i7)
  985 format('    kpds(11) = ',i7,'  kpds(12) = ',i7)
  986 format('    kpds(13) = ',i7,'  kpds(14) = ',i7)
  987 format('    kpds(15) = ',i7,'  kpds(16) = ',i7)
  988 format('    kpds(17) = ',i7,'  kpds(18) = ',i7)
  989 format('    kpds(19) = ',i7,'  kpds(20) = ',i7)
  990 format('    kpds(21) = ',i7,'  kpds(22) = ',i7)
  991 format('    kpds(23) = ',i7,'  kpds(24) = ',i7)
  992 format('    kpds(25) = ',i7)
  880 format('    kgds(1)  = ',i7,'  kgds(2)  = ',i7)
  881 format('    kgds(3)  = ',i7,'  kgds(4)  = ',i7)
  882 format('    kgds(5)  = ',i7,'  kgds(6)  = ',i7)
  883 format('    kgds(7)  = ',i7,'  kgds(8)  = ',i7)
  884 format('    kgds(9)  = ',i7,'  kgds(10) = ',i7)
  885 format('    kgds(11) = ',i7,'  kgds(12) = ',i7)
  886 format('    kgds(13) = ',i7,'  kgds(14) = ',i7)
  887 format('    kgds(15) = ',i7,'  kgds(16) = ',i7)
  888 format('    kgds(17) = ',i7,'  kgds(18) = ',i7)
  889 format('    kgds(19) = ',i7,'  kgds(20) = ',i7)
  890 format('    kgds(20) = ',i7,'  kgds(22) = ',i7)

c
      return
      end
c
c-----------------------------------------------------------------------
c
c-----------------------------------------------------------------------
      subroutine open_grib_files (lugb,lugi,lout,iret)

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
      print *,'tave baopen: igoret= ',igoret,' iioret= ',iioret
     &       ,' iooret= ',iooret
      
      if (igoret /= 0 .or. iioret /= 0 .or. iooret /= 0) then
        print *,' '
        print *,'!!! ERROR in tave'
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
