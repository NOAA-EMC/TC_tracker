      program ecmwfensh
C$$$  MAIN PROGRAM DOCUMENTATION BLOCK
C
C MAIN PROGRAM: ECMWFENS
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2004-09-12
C
C ABSTRACT: This program converts GRIB ensemble header
c   extensions from ECMWF's format to NCEP's format.  It
c   also calculates ensemble mean and spread fields.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
c   99-09-29  MARCHOK     converted to run on Cray5
c   00-03-17  Wobus       IBM version
C   01-01-16  WOBUS       added DOCBLOCK, removed nonstandard
c                         output
c   04-09-12  Wobus       converted for high resolution
c                         and additional variables
C
C USAGE:
C   INPUT FILES:
c     unit 5   - Namelist NAMIN parameters:  
c                     resflag=2 for 2.5x2.5
c                     maxmem = number of members
c     unit 11  - input GRIB file for one forecast length
c     unit 21  - GRIB index file corresponding to unit 11
C
C   OUTPUT FILES:  (INCLUDING SCRATCH FILES)
C     unit   6 - standard output
C     unit  51 - GRIB output for t200
C     unit 151 - GRIB output for t200 stats
C     unit  52 - GRIB output for t500
C     unit 152 - GRIB output for t500 stats
C     unit  53 - GRIB output for t700
C     unit 153 - GRIB output for t700 stats
C     unit  54 - GRIB output for t850
C     unit 154 - GRIB output for t850 stats
C     unit  55 - GRIB output for t2m
C     unit 155 - GRIB output for t2m stats
C     unit  56 - GRIB output for t2max
C     unit 156 - GRIB output for t2max stats
C     unit  57 - GRIB output for t2min
C     unit 157 - GRIB output for t2min stats
C     unit  58 - GRIB output for td2m
C     unit 158 - GRIB output for td2m stats
C     unit  61 - GRIB output for z200
C     unit 162 - GRIB output for z200 stats
C     unit  62 - GRIB output for z500
C     unit 162 - GRIB output for z500 stats
C     unit  63 - GRIB output for z700
C     unit 162 - GRIB output for z700 stats
C     unit  64 - GRIB output for z850
C     unit 162 - GRIB output for z850 stats
C     unit  65 - GRIB output for z1000
C     unit 165 - GRIB output for z1000 stats
C     unit  71 - GRIB output for rh500
C     unit 171 - GRIB output for rh500 stats
C     unit  72 - GRIB output for rh700
C     unit 172 - GRIB output for rh700 stats
C     unit  73 - GRIB output for rh850
C     unit 173 - GRIB output for rh850 stats
C     unit  81 - GRIB output for mslp
C     unit 181 - GRIB output for mslp stats
C     unit  82 - GRIB output for psfc
C     unit 182 - GRIB output for psfc stats
C     unit  83 - GRIB output for prcp
C     unit 183 - GRIB output for prcp stats
C     unit  84 - GRIB output for tcdc 
C     unit 184 - GRIB output for tcdc stats
C     unit 101 - GRIB output for u200
C     unit 102 - GRIB output for v200
C     unit 103 - GRIB output for u500
C     unit 104 - GRIB output for v500
C     unit 105 - GRIB output for u700
C     unit 106 - GRIB output for v700
C     unit 107 - GRIB output for u850
C     unit 108 - GRIB output for v850
C     unit 109 - GRIB output for u10m
C     unit 110 - GRIB output for v10m
C
C   SUBPROGRAMS CALLED: (LIST ALL CALLED FROM ANYWHERE IN CODES)
C     UNIQUE:    - 
c       INCLUDED - create_stats, adjpds, adjext, output, output_stats,
c                  grange, srange, getgbece, ecmext,
c                  grib_close, grib_open, grib_open_wa, grib_open_r
C     LIBRARY:
C       W3LIB    - gbyte,fi632,fi633,w3fi63,w3tagb,w3tage 
c       BACIO    - baopen,baopenwa,baopenr,baclose,baread
C
C   EXIT STATES:
C     COND =   0 - SUCCESSFUL RUN
C
C REMARKS: 
c     Error messages from W3LIB routines will be printed but
c     will not halt execution
C
C ATTRIBUTES:
C   LANGUAGE: Fortran 90
C   MACHINE:  IBM SP
C
C$$$
c
c
c     *** 9/29/99: Due to cray-3 emergency, this program is being
c         implemented on Cray-5 and is being modified to be more
c         efficient.  It doesn't worry about what order the 
c         members are in, it just copies them over.  It still 
c         changes the height level values for the 500 mb height
c         and for mslp for GrADS purposes.  It will leave the 
c         precip fields as they are.
c
c     *** 3/17/00 IBM version
c
c     lugb         logical unit of the unblocked grib data file
c     lugi         logical unit of the unblocked grib index file
c
c     kres         1 - input file contains only high res control.
c                      This lets the program know that you're reading
c                      a "USD" file.
c                  2 - input file contains low res control and
c                      perturbations.  This lets the program know 
c                      you're reading a "USE" file, which has 1 LRC
c                      record for each parm, plus 50 perturbations
c                      for each parm.
c                 (Important to know since high res control
c                  does NOT have a PDS extension)
c
c     memberct    Keeps track of how many members have been read in
c                 for each parameter.  In this way, we can modify the
c                 height level for each successive member (in our 
c                 kludgy system) to be 1,2,3,....,50,51.  And only
c                 index this as "2" since we are only doing this 
c                 kludgy method to 2 variables, z500 and mslp.
c
c
c
      parameter(lugi=21,lugb=11,jf=512*256,nlat=181,nlon=360)
      parameter(numec=52)
      character*1 contflag
      character*1 gott200pds,gott500pds,gott700pds,gott850pds
      character*1 gott2mpds,gott2maxpds,gott2minpds,gottd2mpds
      character*1 gotz200pds,gotz500pds,gotz700pds,gotz850pds
      character*1 gotz1000pds
      character*1 gotrh500pds,gotrh700pds,gotrh850pds
      character*1 gotmslppds,gotpsfcpds,gotprcppds,gottcdcpds
      character*1 gotu200,gotv200
      character*1 gotu500,gotv500
      character*1 gotu700,gotv700
      character*1 gotu850,gotv850
      character*1 gotu10m,gotv10m
      character*8 newvar
      integer   jpds(200),jgds(200),jens(200)
      integer   kpds(200),kgds(200),kens(200)
c for overflow test
      real      rjpds(204),rjgds(204),rjens(204)
      equivalence (jpds(1),rjpds(1))
      equivalence (jgds(1),rjgds(1))
      equivalence (jens(1),rjens(1))
      real      rkpds(204),rkgds(204),rkens(204)
      equivalence (kpds(1),rkpds(1))
      equivalence (kgds(1),rkgds(1))
      equivalence (kens(1),rkens(1))
      integer   kholdt200pds(200)
      integer   kholdt500pds(200)
      integer   kholdt700pds(200)
      integer   kholdt850pds(200)
      integer   kholdt2mpds(200)
      integer   kholdt2maxpds(200)
      integer   kholdt2minpds(200)
      integer   kholdtd2mpds(200)
      integer   kholdz200pds(200)
      integer   kholdz500pds(200)
      integer   kholdz700pds(200)
      integer   kholdz850pds(200)
      integer   kholdz1000pds(200)
      integer   kholdrh500pds(200)
      integer   kholdrh700pds(200)
      integer   kholdrh850pds(200)
      integer   kholdmslppds(200)
      integer   kholdpsfcpds(200)
      integer   kholdprcppds(200)
      integer   kholdtcdcpds(200)
      integer   memberct(2)
      integer   t200ct,t500ct,t700ct,t850ct
      integer   t2mct,t2maxct,t2minct,td2mct
      integer   z200ct,z500ct,z700ct,z850ct,z1000ct
      integer   rh500ct,rh700ct,rh850ct
      integer   mslpct,psfcct,prcpct,tcdcct
      logical   lb(jf)
      real      f(jf)
      real      t200vals(numec,nlat*nlon)
      real      t200mean(nlat*nlon),t200spr(nlat*nlon)
      real      t500vals(numec,nlat*nlon)
      real      t500mean(nlat*nlon),t500spr(nlat*nlon)
      real      t700vals(numec,nlat*nlon)
      real      t700mean(nlat*nlon),t700spr(nlat*nlon)
      real      t850vals(numec,nlat*nlon)
      real      t850mean(nlat*nlon),t850spr(nlat*nlon)
      real      t2mvals(numec,nlat*nlon)
      real      t2mmean(nlat*nlon),t2mspr(nlat*nlon)
      real      t2maxvals(numec,nlat*nlon)
      real      t2maxmean(nlat*nlon),t2maxspr(nlat*nlon)
      real      t2minvals(numec,nlat*nlon)
      real      t2minmean(nlat*nlon),t2minspr(nlat*nlon)
      real      td2mvals(numec,nlat*nlon)
      real      td2mmean(nlat*nlon),td2mspr(nlat*nlon)
      real      z200vals(numec,nlat*nlon)
      real      z200mean(nlat*nlon),z200spr(nlat*nlon)
      real      z500vals(numec,nlat*nlon)
      real      z500mean(nlat*nlon),z500spr(nlat*nlon)
      real      z700vals(numec,nlat*nlon)
      real      z700mean(nlat*nlon),z700spr(nlat*nlon)
      real      z850vals(numec,nlat*nlon)
      real      z850mean(nlat*nlon),z850spr(nlat*nlon)
      real      z1000vals(numec,nlat*nlon)
      real      z1000mean(nlat*nlon),z1000spr(nlat*nlon)
      real      rh500vals(numec,nlat*nlon)
      real      rh500mean(nlat*nlon),rh500spr(nlat*nlon)
      real      rh700vals(numec,nlat*nlon)
      real      rh700mean(nlat*nlon),rh700spr(nlat*nlon)
      real      rh850vals(numec,nlat*nlon)
      real      rh850mean(nlat*nlon),rh850spr(nlat*nlon)
      real      mslpvals(numec,nlat*nlon)
      real      mslpmean(nlat*nlon),mslpspr(nlat*nlon)
      real      psfcvals(numec,nlat*nlon)
      real      psfcmean(nlat*nlon),psfcspr(nlat*nlon)
      real      prcpvals(numec,nlat*nlon)
      real      prcpmean(nlat*nlon),prcpspr(nlat*nlon)
      real      tcdcvals(numec,nlat*nlon)
      real      tcdcmean(nlat*nlon),tcdcspr(nlat*nlon)
      namelist/namin/kres,kmaxmem
c
      call w3tagb('ECMWFENS',2001,0017,0088,'NP20')
c
      read (5,namin,end=1000)
 1000 continue
c
      print *,' '
      print *,'------------------------------------------------------'
      print *,'at beginning of ecmwfens.f, kres= ',kres
     &       ,' kmaxmem= ',kmaxmem

      t200vals = 0.0
      t200mean = 0.0
      t200spr =  0.0
      t500vals = 0.0
      t500mean = 0.0
      t500spr =  0.0
      t700vals = 0.0
      t700mean = 0.0
      t700spr =  0.0
      t850vals = 0.0
      t850mean = 0.0
      t850spr =  0.0
      t2mvals = 0.0
      t2mmean = 0.0
      t2mspr =  0.0
      t2maxvals = 0.0
      t2maxmean = 0.0
      t2maxspr =  0.0
      t2minvals = 0.0
      t2minmean = 0.0
      t2minspr =  0.0
      td2mvals = 0.0
      td2mmean = 0.0
      td2mspr =  0.0

      z200vals = 0.0
      z200mean = 0.0
      z200spr =  0.0
      z500vals = 0.0
      z500mean = 0.0
      z500spr =  0.0
      z700vals = 0.0
      z700mean = 0.0
      z700spr =  0.0
      z850vals = 0.0
      z850mean = 0.0
      z850spr =  0.0
      z1000vals = 0.0
      z1000mean = 0.0
      z1000spr =  0.0

      rh500vals = 0.0
      rh500mean = 0.0
      rh500spr =  0.0
      rh700vals = 0.0
      rh700mean = 0.0
      rh700spr =  0.0
      rh850vals = 0.0
      rh850mean = 0.0
      rh850spr =  0.0

      mslpvals = 0.0
      mslpmean = 0.0
      mslpspr =  0.0
      psfcvals = 0.0
      psfcmean = 0.0
      psfcspr =  0.0
      prcpvals = 0.0
      prcpmean = 0.0
      prcpspr =  0.0
      tcdcvals = 0.0
      tcdcmean = 0.0
      tcdcspr =  0.0
c
      gott200pds = 'n'
      gott500pds = 'n'
      gott700pds = 'n'
      gott850pds = 'n'
      gott2mpds = 'n'
      gott2maxpds = 'n'
      gott2minpds = 'n'
      gottd2mpds = 'n'

      gotz200pds = 'n'
      gotz500pds = 'n'
      gotz700pds = 'n'
      gotz850pds = 'n'
      gotz1000pds = 'n'

      gotrh500pds = 'n'
      gotrh700pds = 'n'
      gotrh850pds = 'n'

      gotmslppds = 'n'
      gotpsfcpds = 'n'
      gotprcppds = 'n'
      gottcdcpds = 'n'
c
      t200ct = 0
      t500ct = 0
      t700ct = 0
      t850ct = 0
      t2mct = 0
      t2maxct = 0
      t2minct = 0
      td2mct = 0

      z200ct = 0
      z500ct = 0
      z700ct = 0
      z850ct = 0
      z1000ct = 0

      rh500ct = 0
      rh700ct = 0
      rh850ct = 0

      mslpct = 0
      psfcct = 0
      prcpct = 0
      tcdcct = 0
 
c     maxloop = number of perturbations + the LRC record.  Remember, 
c     the HRC record is in a file by itself, and is handled by the 
c     case of kres=1.

      maxloop = kmaxmem + 1
      jpds = -1
      jgds = -1
      jens = -1
      jpds(23) = 0
      kgds = 0
      memberct = 0

      kpdsread = 0

c      jpds(23) = 0
      j = 0
      iret = 0

      print *,' '
      do while (iret.eq.0)
 
	kpdsnull = -kpdsread
	kpds = kpdsnull
	kens = kpdsnull

c       Use my modified version of getgbens in this program to 
c       read the recs.  This version of getgbens reads different
c       bytes from the ECMWF PDS extension than are read from the 
c       NCEP PDS extension. *** NOTE: THE VERSION OF GETGBENS 
c       THAT IS CALLED HAS BEEN MODIFIED FROM THE W3LIB VERSION.
c  Modified getgbens has been renamed getgbece

        call getgbece(lugb,lugi,jf,j,jpds,jgds,jens,
     &                          kf,k,kpds,kgds,kens,lb,f,iret,
     &                          ktype,kfnum,ktot)
c check for kpds written out of bounds
        if (kpdsread.lt.10) then
	  print *,' '
	  print *,'check kpds before processing'
	  write(*,71) (kpds(mm),mm=1,5) 
	  write(*,72) (kpds(mm),mm=6,10) 
	  write(*,73) (kpds(mm),mm=11,15) 
	  write(*,74) (kpds(mm),mm=16,20) 
	  write(*,75) (kpds(mm),mm=21,25) 
	  write(*,76) (kgds(mm),mm=1,5) 
	  write(*,77) (kgds(mm),mm=6,10) 
	  write(*,78) (kgds(mm),mm=11,15) 
	  write(*,79) (kgds(mm),mm=16,20) 
	  write(*,80) (kgds(mm),mm=21,22) 
	  write(*,81) f(1),f(kf/4),f(kf/2)
     &               ,f(3*kf/4),f(kf)
	  call srange(kf,lb,f)
c for overflow test
	  do ichk=26,200
	    if ( jpds(ichk) .ne. -1 ) then
	      write (*,'(''kpdsread, ichk, jpds, jpds, rjpds ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,jpds(ichk),jpds(ichk),rjpds(ichk)
	    endif
	  enddo
	  do ichk=23,200
	    if ( jgds(ichk) .ne. -1 ) then
	      write (*,'(''kpdsread, ichk, jgds, jgds, rjgds ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,jgds(ichk),jgds(ichk),rjgds(ichk)
	    endif
	  enddo
	  do ichk=6,200
	    if ( jens(ichk) .ne. -1 ) then
	      write (*,'(''kpdsread, ichk, jens, jens, rjens ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,jens(ichk),jens(ichk),rjens(ichk)
	    endif
	  enddo
	  do ichk=26,200
	    if ( kpds(ichk) .ne. kpdsnull ) then
	      write (*,'(''kpdsread, ichk, kpds, kpds, rkpds ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,kpds(ichk),kpds(ichk),rkpds(ichk)
	    endif
	  enddo
	  do ichk=23,200
	    if ( kgds(ichk) .ne. 0 ) then
	      write (*,'(''kpdsread, ichk, kgds, kgds, rkgds ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,kgds(ichk),kgds(ichk),rkgds(ichk)
	    endif
	  enddo
	  do ichk=6,200
	    if ( kens(ichk) .ne. kpdsnull ) then
	      write (*,'(''kpdsread, ichk, kens, kens, rkens ='',
     &                i3,i4,i23,z17,1pe32.23))')
     &               kpdsread,ichk,kens(ichk),kens(ichk),rkens(ichk)
	    endif
	  enddo
	endif
	kpdsread=kpdsread+1
c
        j=k
c       print *,' '
        if (iret.eq.0) then
	  print *,'immediately after call to getgb, j=',j
     &          ,' k=',k,' kpds(5)=',kpds(5)
     &          ,' kpds(14)=',kpds(14),' kfnum=',kfnum
     &          ,' iret=',iret
	  if ((kfnum.le.2).or.(kfnum.ge.49)) then
	    if ((kpds(14).le.24).or.(kpds(14).ge.228)) then
c             print *,' '
              call srange(kf,lb,f)
	      call grange(kf,lb,f,dmin,dmax)
	      print '(4i5,4i3,2x,a1,i3,3i5,2x,i7,2g12.4)'
     &              ,k,(kpds(i),i=5,11),'f',kpds(14),ktype,kfnum
     &              ,ktot,kf,dmin,dmax
	    endif
	  endif
        else
          print *,'!!! getgb IRET= ',iret,'   j= ',j
     &           ,' .... Continuing to next loop iteration ....'
          goto 600
        endif
 
        call adjpds (kpds,contflag,lugout,memberct)

        if (contflag.eq.'n') goto 600

      call grib_open_wa (lugout,ireto)
      if (ireto.gt.0) then
        print *,'ireto,lu from grib_open_wa in ecmwfens = ',ireto,lugout
      endif
 
        call adjext (kens,ktype,kfnum,kres)
 
c	if ((kfnum.le.2).or.(kfnum.ge.49)) then
c	  if ((kpds(14).le.24).or.(kpds(14).ge.228)) then
c           print *,' '
c	    write(*,71) (kpds(mm),mm=1,5) 
c	    write(*,72) (kpds(mm),mm=6,10) 
c	    write(*,73) (kpds(mm),mm=11,15) 
c	    write(*,74) (kpds(mm),mm=16,20) 
c	    write(*,75) (kpds(mm),mm=21,25) 
c	    write(*,76) (kgds(mm),mm=1,5) 
c	    write(*,77) (kgds(mm),mm=6,10) 
c	    write(*,78) (kgds(mm),mm=11,15) 
c	    write(*,79) (kgds(mm),mm=16,20) 
c	    write(*,80) (kgds(mm),mm=21,22) 
c	    write(*,81) f(1),f(kf/4),f(kf/2)
c    &                 ,f(3*kf/4),f(kf)
c	    call srange(kf,lb,f)
c	  endif
c	endif

        kpds(23)=2

        newvar = 'none'

        if (kpds(5) .eq. 61) then
          if (gotprcppds .eq. 'n') then
            gotprcppds = 'y'
	    newvar = 'prcp    '
            do i = 1,25
              kholdprcppds(i) = kpds(i)
            enddo
          endif
          prcpct = prcpct + 1
          do ip = 1,kf
            f(ip) = f(ip) * 1000.0
            prcpvals(prcpct,ip) = prcpvals(prcpct,ip) + f(ip)
          enddo
        else if (kpds(5) .eq. 2) then
          if (gotmslppds .eq. 'n') then
            gotmslppds = 'y'
	    newvar = 'mslp    '
            do i = 1,25
              kholdmslppds(i) = kpds(i)
            enddo 
          endif
	    call srange(kf,lb,f)
          mslpct = mslpct + 1
          do ip = 1,kf
            mslpvals(mslpct,ip) = mslpvals(mslpct,ip) + f(ip)
          enddo
        else if (kpds(5) .eq. 11) then
         if (kpds(7) .eq. 850) then
          if (gott850pds .eq. 'n') then
            gott850pds = 'y'
	    newvar = 't850    '
            do i = 1,25
              kholdt850pds(i) = kpds(i)
            enddo
          endif
          t850ct = t850ct + 1
          do ip = 1,kf
            t850vals(t850ct,ip) = t850vals(t850ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 700) then
          if (gott700pds .eq. 'n') then
            gott700pds = 'y'
	    newvar = 't700    '
            do i = 1,25
              kholdt700pds(i) = kpds(i)
            enddo
          endif
          t700ct = t700ct + 1
          do ip = 1,kf
            t700vals(t700ct,ip) = t700vals(t700ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 500) then
          if (gott500pds .eq. 'n') then
            gott500pds = 'y'
	    newvar = 't500    '
            do i = 1,25
              kholdt500pds(i) = kpds(i)
            enddo
          endif
          t500ct = t500ct + 1
          do ip = 1,kf
            t500vals(t500ct,ip) = t500vals(t500ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 200) then
          if (gott200pds .eq. 'n') then
            gott200pds = 'y'
	    newvar = 't200    '
            do i = 1,25
              kholdt200pds(i) = kpds(i)
            enddo
          endif
          t200ct = t200ct + 1
          do ip = 1,kf
            t200vals(t200ct,ip) = t200vals(t200ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 2) then
          if (gott2mpds .eq. 'n') then
            gott2mpds = 'y'
	    newvar = 't2m     '
            do i = 1,25
              kholdt2mpds(i) = kpds(i)
            enddo
          endif
          t2mct = t2mct + 1
          do ip = 1,kf
            t2mvals(t2mct,ip) = t2mvals(t2mct,ip) + f(ip)
          enddo
	 endif 
c new batch 01/04
        else if (kpds(5) .eq. 15) then
         if (kpds(7) .eq. 2) then
          if (gott2maxpds .eq. 'n') then
            gott2maxpds = 'y'
	    newvar = 't2max   '
            do i = 1,25
              kholdt2maxpds(i) = kpds(i)
            enddo
          endif
          t2maxct = t2maxct + 1
          do ip = 1,kf
            t2maxvals(t2maxct,ip) = t2maxvals(t2maxct,ip) + f(ip)
          enddo
	 endif 
        else if (kpds(5) .eq. 16) then
         if (kpds(7) .eq. 2) then
          if (gott2minpds .eq. 'n') then
            gott2minpds = 'y'
	    newvar = 't2min   '
            do i = 1,25
              kholdt2minpds(i) = kpds(i)
            enddo
          endif
          t2minct = t2minct + 1
          do ip = 1,kf
            t2minvals(t2minct,ip) = t2minvals(t2minct,ip) + f(ip)
          enddo
	 endif 
        else if (kpds(5) .eq. 17) then
         if (kpds(7) .eq. 2) then
          if (gottd2mpds .eq. 'n') then
            gottd2mpds = 'y'
	    newvar = 'td2m    '
            do i = 1,25
              kholdtd2mpds(i) = kpds(i)
            enddo
          endif
          td2mct = td2mct + 1
          do ip = 1,kf
            td2mvals(td2mct,ip) = td2mvals(td2mct,ip) + f(ip)
          enddo
	 endif 
        else if (kpds(5) .eq. 1) then
         if (kpds(7) .eq. 0) then
          if (gotpsfcpds .eq. 'n') then
            gotpsfcpds = 'y'
	    newvar = 'psfc    '
            do i = 1,25
              kholdpsfcpds(i) = kpds(i)
            enddo
          endif
          psfcct = psfcct + 1
          do ip = 1,kf
cJ.Peng---2011-05-17------------NCO change Surface Pressure----
c           f(ip) = exp(f(ip))

            psfcvals(psfcct,ip) = psfcvals(psfcct,ip) + f(ip)
          enddo
	 endif 
        else if (kpds(5) .eq. 71) then
         if (kpds(7) .eq. 0) then
          if (gottcdcpds .eq. 'n') then
            gottcdcpds = 'y'
	    newvar = 'tcdc    '
            do i = 1,25
              kholdtcdcpds(i) = kpds(i)
            enddo
          endif
          tcdcct = tcdcct + 1
          do ip = 1,kf
	    f(ip) = f(ip) * 100.0
            tcdcvals(tcdcct,ip) = tcdcvals(tcdcct,ip) + f(ip)
          enddo
	 endif 
        else if (kpds(5) .eq. 7) then
         if (kpds(7) .eq. 1000) then
          if (gotz1000pds .eq. 'n') then
            gotz1000pds = 'y'
	    newvar = 'z1000   '
            do i = 1,25
              kholdz1000pds(i) = kpds(i)
            enddo 
          endif
          z1000ct = z1000ct + 1
          do ip = 1,kf
            z1000vals(z1000ct,ip) = z1000vals(z1000ct,ip) + f(ip)
          enddo
         else if (kpds(7).eq.850) then
          if (gotz850pds .eq. 'n') then
            gotz850pds = 'y'
	    newvar = 'z850    '
            do i = 1,25
              kholdz850pds(i) = kpds(i)
            enddo 
          endif
          z850ct = z850ct + 1
          do ip = 1,kf
            z850vals(z850ct,ip) = z850vals(z850ct,ip) + f(ip)
          enddo
         else if (kpds(7).eq.700) then
          if (gotz700pds .eq. 'n') then
            gotz700pds = 'y'
	    newvar = 'z700    '
            do i = 1,25
              kholdz700pds(i) = kpds(i)
            enddo 
          endif
          z700ct = z700ct + 1
          do ip = 1,kf
            z700vals(z700ct,ip) = z700vals(z700ct,ip) + f(ip)
          enddo
         else if (kpds(7).eq.500) then
          if (gotz500pds .eq. 'n') then
            gotz500pds = 'y'
	    newvar = 'z500    '
            do i = 1,25
              kholdz500pds(i) = kpds(i)
            enddo 
          endif
          z500ct = z500ct + 1
          do ip = 1,kf
            z500vals(z500ct,ip) = z500vals(z500ct,ip) + f(ip)
          enddo
         else if (kpds(7).eq.200) then
          if (gotz200pds .eq. 'n') then
            gotz200pds = 'y'
	    newvar = 'z200    '
            do i = 1,25
              kholdz200pds(i) = kpds(i)
            enddo 
          endif
          z200ct = z200ct + 1
          do ip = 1,kf
            z200vals(z200ct,ip) = z200vals(z200ct,ip) + f(ip)
          enddo
         endif
        else if (kpds(5) .eq. 52) then
         if (kpds(7) .eq. 850) then
          if (gotrh850pds .eq. 'n') then
            gotrh850pds = 'y'
	    newvar = 'rh850   '
            do i = 1,25
              kholdrh850pds(i) = kpds(i)
            enddo
          endif
          rh850ct = rh850ct + 1
          do ip = 1,kf
            rh850vals(rh850ct,ip) = rh850vals(rh850ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 700) then
          if (gotrh700pds .eq. 'n') then
            gotrh700pds = 'y'
	    newvar = 'rh700   '
            do i = 1,25
              kholdrh700pds(i) = kpds(i)
            enddo
          endif
          rh700ct = rh700ct + 1
          do ip = 1,kf
            rh700vals(rh700ct,ip) = rh700vals(rh700ct,ip) + f(ip)
          enddo
         else if (kpds(7) .eq. 500) then
          if (gotrh500pds .eq. 'n') then
            gotrh500pds = 'y'
	    newvar = 'rh500   '
            do i = 1,25
              kholdrh500pds(i) = kpds(i)
            enddo
          endif
          rh500ct = rh500ct + 1
          do ip = 1,kf
            rh500vals(rh500ct,ip) = rh500vals(rh500ct,ip) + f(ip)
          enddo
	 endif
	else if (kpds(5) .eq. 33) then
         if (kpds(7) .eq. 200) then
          if (gotu200 .eq. 'n') then
            gotu200 = 'y'
            newvar = 'u200'
          endif
         else if (kpds(7) .eq. 500) then
          if (gotu500 .eq. 'n') then
            gotu500 = 'y'
            newvar = 'u500'
          endif
         else if (kpds(7) .eq. 700) then
          if (gotu700 .eq. 'n') then
            gotu700 = 'y'
            newvar = 'u700'
          endif
         else if (kpds(7) .eq. 850) then
          if (gotu850 .eq. 'n') then
            gotu850 = 'y'
            newvar = 'u850'
          endif
         else if (kpds(7) .eq. 10) then
          if (gotu10m .eq. 'n') then
            gotu10m = 'y'
            newvar = 'u10m'
          endif
         endif
	else if (kpds(5) .eq. 34) then
         if (kpds(7) .eq. 200) then
          if (gotv200 .eq. 'n') then
            gotv200 = 'y'
            newvar = 'v200'
          endif
         else if (kpds(7) .eq. 500) then
          if (gotv500 .eq. 'n') then
            gotv500 = 'y'
            newvar = 'v500'
          endif
         else if (kpds(7) .eq. 700) then
          if (gotv700 .eq. 'n') then
            gotv700 = 'y'
            newvar = 'v700'
          endif
         else if (kpds(7) .eq. 850) then
          if (gotv850 .eq. 'n') then
            gotv850 = 'y'
            newvar = 'v850'
          endif
         else if (kpds(7) .eq. 10) then
          if (gotv10m .eq. 'n') then
            gotv10m = 'y'
            newvar = 'v10m'
          endif
         endif
        endif

        if ( newvar .ne. 'none') then
          print *,'new variable ',newvar
          call srange(kf,lb,f)
	  call grange(kf,lb,f,dmin,dmax)
	  print '(4i5,4i3,2x,a1,i3,3i5,2x,i7,2g12.4)'
     &              ,k,(kpds(i),i=5,11),'f',kpds(14),ktype,kfnum
     &              ,ktot,kf,dmin,dmax
	  write(*,71) (kpds(mm),mm=1,5) 
	  write(*,72) (kpds(mm),mm=6,10) 
	  write(*,73) (kpds(mm),mm=11,15) 
	  write(*,74) (kpds(mm),mm=16,20) 
	  write(*,75) (kpds(mm),mm=21,25) 
	  write(*,76) (kgds(mm),mm=1,5) 
	  write(*,77) (kgds(mm),mm=6,10) 
	  write(*,78) (kgds(mm),mm=11,15) 
	  write(*,79) (kgds(mm),mm=16,20) 
	  write(*,80) (kgds(mm),mm=21,22) 
	  write(*,81) f(1),f(kf/4),f(kf/2)
     &                 ,f(3*kf/4),f(kf)
        endif

        call output (lugout,kf,kpds,kgds,lb,f,kens)

	call grib_close (lugout,ireto)
	if (ireto.gt.0) then
	  print *,'ireto,lu from grib_close in ecmwfens = ',ireto,lugout
	endif
      

        if ( newvar .ne. 'none') then
	  print *,' '
        endif
 
 600    continue

      enddo
      call grib_close (lugb,ireto)
      if (ireto.gt.0) then
        print *,'ireto,lu from grib_close in ecmwfens = ',ireto,lugb
      endif
      call grib_close (lugi,ireto)
      if (ireto.gt.0) then
        print *,'ireto,lu from grib_close in ecmwfens = ',ireto,lugi
      endif

      if (gott200pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t200ct,t200vals,t200mean,t200spr) 
      call output_stats ('t200',151,nlat*nlon,kholdt200pds,kgds
     &                  ,lb,t200mean,t200spr)
      else
	print *,'no statistics for t200'
      endif
      if (gott500pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t500ct,t500vals,t500mean,t500spr) 
      call output_stats ('t500',152,nlat*nlon,kholdt500pds,kgds
     &                  ,lb,t500mean,t500spr)
      else
	print *,'no statistics for t500'
      endif
      if (gott700pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t700ct,t700vals,t700mean,t700spr) 
      call output_stats ('t700',153,nlat*nlon,kholdt700pds,kgds
     &                  ,lb,t700mean,t700spr)
      else
	print *,'no statistics for t700'
      endif
      if (gott850pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t850ct,t850vals,t850mean,t850spr) 
      call output_stats ('t850',154,nlat*nlon,kholdt850pds,kgds
     &                  ,lb,t850mean,t850spr)
      else
	print *,'no statistics for t850'
      endif
      if (gott2mpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t2mct,t2mvals,t2mmean,t2mspr) 
      call output_stats ('t2m ',155,nlat*nlon,kholdt2mpds,kgds
     &                  ,lb,t2mmean,t2mspr)
      else
	print *,'no statistics for t2m'
      endif
      if (gott2maxpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t2maxct,t2maxvals,t2maxmean,t2maxspr) 
      call output_stats ('t2mx',156,nlat*nlon,kholdt2maxpds,kgds
     &                  ,lb,t2maxmean,t2maxspr)
      else
	print *,'no statistics for t2max'
      endif
      if (gott2minpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,t2minct,t2minvals,t2minmean,t2minspr) 
      call output_stats ('t2mn',157,nlat*nlon,kholdt2minpds,kgds
     &                  ,lb,t2minmean,t2minspr)
      else
	print *,'no statistics for t2min'
      endif
      if (gottd2mpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,td2mct,td2mvals,td2mmean,td2mspr) 
      call output_stats ('td2m',158,nlat*nlon,kholdtd2mpds,kgds
     &                  ,lb,td2mmean,td2mspr)
      else
	print *,'no statistics for td2m'
      endif

      if (gotz200pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,z200ct,z200vals,z200mean,z200spr) 
      call output_stats ('z200',161,nlat*nlon,kholdz200pds,kgds
     &                  ,lb,z200mean,z200spr)
      else
	print *,'no statistics for z200'
      endif
      if (gotz500pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,z500ct,z500vals,z500mean,z500spr) 
      call output_stats ('z500',162,nlat*nlon,kholdz500pds,kgds
     &                  ,lb,z500mean,z500spr)
      else
	print *,'no statistics for z500'
      endif
      if (gotz700pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,z700ct,z700vals,z700mean,z700spr) 
      call output_stats ('z700',163,nlat*nlon,kholdz700pds,kgds
     &                  ,lb,z700mean,z700spr)
      else
	print *,'no statistics for z700'
      endif
      if (gotz850pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,z850ct,z850vals,z850mean,z850spr) 
      call output_stats ('z850',164,nlat*nlon,kholdz850pds,kgds
     &                  ,lb,z850mean,z850spr)
      else
	print *,'no statistics for z850'
      endif
      if (gotz1000pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,z1000ct,z1000vals,z1000mean,z1000spr) 
      call output_stats ('z1k ',165,nlat*nlon,kholdz1000pds,kgds
     &                  ,lb,z1000mean,z1000spr)
      else
	print *,'no statistics for z1000'
      endif

      if (gotrh500pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,rh500ct,rh500vals,rh500mean,rh500spr) 
      call output_stats ('r500',171,nlat*nlon,kholdrh500pds,kgds
     &                  ,lb,rh500mean,rh500spr)
      else
	print *,'no statistics for rh500'
      endif
      if (gotrh700pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,rh700ct,rh700vals,rh700mean,rh700spr) 
      call output_stats ('r700',172,nlat*nlon,kholdrh700pds,kgds
     &                  ,lb,rh700mean,rh700spr)
      else
	print *,'no statistics for rh700'
      endif
      if (gotrh850pds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,rh850ct,rh850vals,rh850mean,rh850spr) 
      call output_stats ('r850',173,nlat*nlon,kholdrh850pds,kgds
     &                  ,lb,rh850mean,rh850spr)
      else
	print *,'no statistics for rh850'
      endif

      if (gotmslppds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,mslpct,mslpvals,mslpmean,mslpspr) 
      call output_stats ('mslp',181,nlat*nlon,kholdmslppds,kgds
     &                  ,lb,mslpmean,mslpspr)
      else
	print *,'no statistics for mslp'
      endif
      if (gotpsfcpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,psfcct,psfcvals,psfcmean,psfcspr) 
      call output_stats ('psfc',182,nlat*nlon,kholdpsfcpds,kgds
     &                  ,lb,psfcmean,psfcspr)
      else
	print *,'no statistics for psfc'
      endif
      if (gotprcppds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,prcpct,prcpvals,prcpmean,prcpspr) 
      call output_stats ('prcp',183,nlat*nlon,kholdprcppds,kgds
     &                  ,lb,prcpmean,prcpspr)
      else
	print *,'no statistics for prcp'
      endif
      if (gottcdcpds .eq. 'y') then
      call create_stats (numec,nlat,nlon
     &                  ,tcdcct,tcdcvals,tcdcmean,tcdcspr) 
      call output_stats ('tcdc',184,nlat*nlon,kholdtcdcpds,kgds
     &                  ,lb,tcdcmean,tcdcspr)
      else
	print *,'no statistics for tcdc'
      endif
 
 71   format('p1=  ',i7,' p2=  ',i7,' p3=  ',i7,' p4=  ',i7,' p5=  ',i7)
 72   format('p6=  ',i7,' p7=  ',i7,' p8=  ',i7,' p9=  ',i7,' p10= ',i7)
 73   format('p11= ',i7,' p12= ',i7,' p13= ',i7,' p14= ',i7,' p15= ',i7)
 74   format('p16= ',i7,' p17= ',i7,' p18= ',i7,' p19= ',i7,' p20= ',i7)
 75   format('p21= ',i7,' p22= ',i7,' p23= ',i7,' p24= ',i7,' p25= ',i7)
 76   format('g1=  ',i7,' g2=  ',i7,' g3=  ',i7,' g4=  ',i7,' g5=  ',i7)
 77   format('g6=  ',i7,' g7=  ',i7,' g8=  ',i7,' g9=  ',i7,' g10= ',i7)
 78   format('g11= ',i7,' g12= ',i7,' g13= ',i7,' g14= ',i7,' g15= ',i7)
 79   format('g16= ',i7,' g17= ',i7,' g18= ',i7,' g19= ',i7,' g20= ',i7)
 80   format('g21= ',i7,' g22= ',i7)
 81   format('f(1)= ',g12.4,' f(kf/4)= ',g12.4,' f(kf/2)= ',g12.4
     &      ,' f(3*kf/4)= ',g12.4,' f(kf)= ',g12.4)
c
 700  continue
      call w3tage('ECMWFENS')
      stop
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine create_stats (numec,nlat,nlon,nct,vals,vmean,vspr)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    create_stats
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2004-01-26
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C   04-01-26  WOBUS       rearranged to process one variable
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$
c
      real      vals(numec,nlat*nlon)
      real      vmean(nlat*nlon)
      real      vspr(nlat*nlon)
      integer   nct
c
      npts = nlon * nlat
      vmean = 0.0

c     -----------------------------------------------------
c        MEAN & SPREAD
c     -----------------------------------------------------
 
      if (nct .gt. 0) then

c       sum up all values from all members at all points

        do imem = 1,nct
          do n = 1,npts
            vmean(n) = vmean(n) + vals(imem,n)
          enddo
        enddo

c       calculate mean

        do n = 1,npts
          vmean(n) = vmean(n) / float(nct)
        enddo

c       calculate standard deviation

        if (nct .gt. 1) then

	  do n = 1,npts
	    varnce = 0.0
	    do imem = 1,nct
	      xdiff    = vals(imem,n) - vmean(n)
	      xdiffsqr = xdiff * xdiff
	      varnce   = varnce + xdiffsqr
	    enddo
	    vspr(n) = sqrt(varnce/float(nct))
	  enddo
	  print *,' in create_stats imem=',imem,'   nct=',nct

        else

	  do n = 1,npts
	    vspr(n)  = 0.00
	  enddo

	endif

      else

        do n = 1,npts
          vmean(n) = -99.0
	  vspr(n)  = -99.0
        enddo

      endif
          
      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine adjpds (kpds,contflag,lugout,memberct)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    adjpds
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$
c
c     ****************************************************
c     ADJUST GRIB PARAMETER FROM THE ECMWF TABLE VALUES
c     TO NCEP TABLE VALUES AS FOLLOWS:
c
c       Parameter        ECMWF Grib Parm    NCEP Grib Parm
c     -------------      ---------------    --------------
c     u-comp (std lev)        131                33
c     v-comp (std lev)        132                34
c     gp height               156                 7
c     relative humidity       157                52
c     temperature             130                11
c     mslp                    151                 2
c     total precip            228                61
c
c     - new batch 1/04
c     2 meter temp            167 1 0            11 105 2
c     2 meter tmax            201 1 0            15 105 2
c     2 meter tmin            202 1 0            16 105 2
c     2 meter td              168 1 0            17 105 2
cJ.Peng---2011-05-17------------NCO change Surface Pressure----
c     psfc                    152 109 1 (log)     1 1 0
c     psfc                    134   1 0 new       1 1 0

c     total cloud cover       164 1 0 (0-1)      71 200 0 (%)
c
c
c     - Others, which currently (1/97) are in the ECMWF
c       data sets, but are not needed for this output data
c       set (they're needed by the Ocean Modeling Branch
c       and are processed in a different program):
c       (now processed here 1/04)
c
c     u-comp (10m)            165 1 0            33 105 10
c     v-comp (10m)            166 1 0            34 105 10
c
c     -------------------------------------------------
c
c     ALSO, get the  output GRIB file number, which is 
c     based on the parameter number and vertical level.
c
c     contflag is needed because ECMWF sends a couple of 
c     additional records in their package which our Ocean
c     Modeling Branch uses, but which we do not archive,
c     so we don't want to output these to our GRIB files.
c
c     ****************************************************
c
      character*1 contflag
      integer     kpds(25),memberct(2)
c
      contflag='n'
      lugout=0

cJ.Peng---2011-05-17------------NCO change Surface Pressure----
c  152----to ----134
      if (kpds(5).ne.130 .and.
     &    kpds(5).ne.131 .and. kpds(5).ne.132 .and.
     &    kpds(5).ne.151 .and. kpds(5).ne.134 .and.
     &    kpds(5).ne.156 .and. kpds(5).ne.157 .and.
     &    kpds(5).ne.164 .and.
     &    kpds(5).ne.165 .and. kpds(5).ne.166 .and.
     &    kpds(5).ne.167 .and. kpds(5).ne.168 .and.
     &    kpds(5).ne.201 .and. kpds(5).ne.202 .and.
     &    kpds(5).ne.228) then
        goto 900
      endif

c
      if (kpds(5).eq.130) then
        kpds(5) = 11
        if (kpds(7).eq.200) lugout = 51
        if (kpds(7).eq.500) lugout = 52
        if (kpds(7).eq.700) lugout = 53
        if (kpds(7).eq.850) lugout = 54
      else if (kpds(5).eq.131) then
        kpds(5) = 33
        if (kpds(7).eq.200) lugout = 101
        if (kpds(7).eq.500) lugout = 103
        if (kpds(7).eq.700) lugout = 105
        if (kpds(7).eq.850) lugout = 107
      else if (kpds(5).eq.132) then
        kpds(5) = 34
        if (kpds(7).eq.200) lugout = 102
        if (kpds(7).eq.500) lugout = 104
        if (kpds(7).eq.700) lugout = 106
        if (kpds(7).eq.850) lugout = 108
      else if (kpds(5).eq.151) then
        lugout  = 81
        kpds(5) = 2
c       kpds(6) = 100

cJ.Peng---2011-05-17------------NCO change Surface Pressure----
c      else if (kpds(5).eq.152) then
      else if (kpds(5).eq.134) then

        kpds(5) = 1
c        if (kpds(7).eq.1) then
        if (kpds(7).eq.0) then

	  lugout = 82
	  kpds(6) = 1
	  kpds(7) = 0
	end if
      else if (kpds(5).eq.156) then
        kpds(5) = 7
        if (kpds(7).eq.1000) lugout = 65
        if (kpds(7).eq.850) lugout = 64
        if (kpds(7).eq.700) lugout = 63
        if (kpds(7).eq.500) lugout = 62
        if (kpds(7).eq.200) lugout = 61
      else if (kpds(5).eq.157) then
        kpds(5) = 52
        if (kpds(7).eq.500) lugout  = 71
        if (kpds(7).eq.700) lugout  = 72
        if (kpds(7).eq.850) lugout  = 73
      else if (kpds(5).eq.164) then
        kpds(5) = 71
        if (kpds(7).eq.0) then
	  lugout = 84
	  kpds(6) = 200
	  kpds(7) = 0
	end if
      else if (kpds(5).eq.165) then
        kpds(5) = 33
        if (kpds(7).eq.0) then
	  lugout = 109
	  kpds(6) = 105
	  kpds(7) = 10
	end if
      else if (kpds(5).eq.166) then
        kpds(5) = 34
        if (kpds(7).eq.0) then
	  lugout = 110
	  kpds(6) = 105
	  kpds(7) = 10
	end if
      else if (kpds(5).eq.167) then
        kpds(5) = 11
        if (kpds(7).eq.0) then
	  lugout = 55
	  kpds(6) = 105
	  kpds(7) = 2
	end if
      else if (kpds(5).eq.168) then
        kpds(5) = 17
        if (kpds(7).eq.0) then
	  lugout = 58
	  kpds(6) = 105
	  kpds(7) = 2
	end if
      else if (kpds(5).eq.201) then
        kpds(5) = 15
        if (kpds(7).eq.0) then
	  lugout = 56
	  kpds(6) = 105
	  kpds(7) = 2
	end if
      else if (kpds(5).eq.202) then
        kpds(5) = 16
        if (kpds(7).eq.0) then
	  lugout = 57
	  kpds(6) = 105
	  kpds(7) = 2
	end if

c     Now make adjustments for the precip GRIB PDS parms,
c     which ECMWF did not code correctly for accumulations.

      else if (kpds(5).eq.228) then
        kpds(5) = 61
        lugout  = 83
        kpds(13) = 1
        if (kpds(14).eq.0) then
          kpds(14) = 0
          kpds(15) = 0
        else
          kpds(14) = kpds(14) - 12
          kpds(15) = kpds(14) + 12
        endif
        kpds(16) = 4
        kpds(22) = 1
      endif
c
      kpds(19) = 2
c
      if (lugout .ne. 0) then
	contflag='y'
      endif
c
 900  continue
      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine adjext (kens,ktype,kfnum,kres)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    adjext
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$
c
c     This subroutine takes the ECMWF ensemble PDS header
c     extension parameters and creates the corresponding 
c     NCEP header extension.
c
c     INPUT
c     -----
c     ktype       ECMWF flag; 10 = Control, 11 = Perturbed Fcst
c     kfnum       0 = CONTROL FORECAST, 1-nn = Perturbed Fcst, 
c                  odd number is positive pert,
C                  even number is for negative pert.
c     kres        1 - input file contains only high res control
c                 2 - input file contains low res control and
c                     perturbations 
c                 (Important to know since high res control 
c                  does NOT have a PDS extension)
c
c     OUTPUT
c     ------
c     kens        NCEP ensemble PDS extension (Bytes 41-45)
c
c
c
      integer   kens(5)
c
      kens=0
      kens(1)=1
c
      if (kres.eq.1) then
 
c       If kres=1 (this is information that is passed into this program
c       via a namelist), then you know that you are reading a file that
c       contains only HRC records, so give the current record an 
c       NCEP ensemble extension to indicate such.
 
        kens(2) = 1
        kens(3) = 1

      else

c       If kres=2 and the ktype=10, then you know that you're reading
c       a LRC record from one of the "USE" files.  As such, give it an
c       NCEP LRC designation.  If ktype=11, then you're reading one of
c       the perturbation records.

        if (ktype.eq.10) then
          kens(2) = 1
          kens(3) = 2
        else
          if (mod(kfnum,2).gt.0) then
            kens(2) = 3
          else
            kens(2) = 2
          end if
        end if

      end if
c
c     CONSECUTIVELY NUMBERED ECMWF FORECASTS MAKE UP A NEGATIVELY
c     AND POSITIVELY PERTURBED PAIR.  THIS NEXT BIT OF CODE
c     ASSOCIATES AN ID NUMBER TO A MEMBER FROM EACH PAIR.
c
      if (kres.eq.2 .and. ktype.eq.11) then
        kens(3) = (kfnum + 1) / 2
      endif
c
c     SET NMCEXT ARRAY MEMBERS 4 AND 5 EQUAL TO 1 AND 255.
c
 400  continue
c
      kens(4) = 1
      kens(5) = 255
c
      return 
      end    
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine output (lugout,kf,kpds,kgds,ld,data,kens)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    output
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$
c
      integer   kpds(200),kgds(200),kens(200)
      logical   ld(kf)
      real      data(kf)
c
c     ****************************
c      WRITE GRIB FILE
c     ****************************
c
      if ((kens(3).le.1).or.(kens(3).ge.25)) then
	if ((kpds(14).le.24).or.(kpds(14).ge.228)) then
	  print *,'at beginning of output, lugout=',lugout
     &           ,' kpds(5)=',kpds(5)
     &           ,' kens(2)=',kens(2),' kens(3)=',kens(3),' kf=',kf
c         print *,' '
	endif
      endif
      call putgbe (lugout,kf,kpds,kgds,kens,ld,data,iret)
 
      if (iret.eq.0) then
c       print *,' '
	if ((kens(3).le.1).or.(kens(3).ge.25)) then
	  if ((kpds(14).le.24).or.(kpds(14).ge.228)) then
	    print *,'IRET = 0 after call to putgbe'
c	    print *,' '
	  endif
	endif
      else
        print *,' '
        print *,'!!! ERROR: IRET NE 0 AFTER CALL TO PUTGBE !!!'
     &         ,lugout,'=lugout ',iret,'=iret '
        print *,' '
      endif
c
      return 
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
c     subroutine output_stats (cparm,ctype,kf,kpds,kgds,ld,data)
      subroutine output_stats (cparm,lugout,kf,kpds,kgds,ld,datam
     &,datas)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    output_stats
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$
c
      integer   kpds(200),kgds(200),kens(200)
      logical   ld(kf)
      real      datam(kf)
      real      datas(kf)
      character cparm*4,ctype*4

      call grib_open_wa (lugout,ireto)
      if (ireto.gt.0) then
        print *,'ireto,lu from grib_open_wa in output_stats = ',
     ,     ireto,lugout
      endif

      do istat=1,2

	 if (istat .eq. 1) ctype='mean'
	 if (istat .eq. 2) ctype='spr '

	ld = .TRUE.

        iready=1
	if (cparm .eq. 't200') then
	  kpds(5)  = 11
	  kpds(6)  = 100
	  kpds(7)  = 200
	  kpds(22) = 1
	else if (cparm .eq. 't500') then
	  kpds(5)  = 11
	  kpds(6)  = 100
	  kpds(7)  = 500
	  kpds(22) = 1
	else if (cparm .eq. 't700') then
	  kpds(5)  = 11
	  kpds(6)  = 100
	  kpds(7)  = 500
	  kpds(22) = 1
	else if (cparm .eq. 't850') then
	  kpds(5)  = 11
	  kpds(6)  = 100
	  kpds(7)  = 850
	  kpds(22) = 1
	else if (cparm .eq. 't2m') then
	  kpds(5)  = 11
	  kpds(6)  = 105
	  kpds(7)  = 2
	  kpds(22) = 1
	else if (cparm .eq. 't2mx') then
	  kpds(5)  = 15
	  kpds(6)  = 105
	  kpds(7)  = 2
	  kpds(22) = 1
	else if (cparm .eq. 't2mn') then
	  kpds(5)  = 16
	  kpds(6)  = 105
	  kpds(7)  = 2
	  kpds(22) = 1
	else if (cparm .eq. 'td2m') then
	  kpds(5)  = 17
	  kpds(6)  = 105
	  kpds(7)  = 2
	  kpds(22) = 1
	else if (cparm .eq. 'z200') then
	  kpds(5)  = 7
	  kpds(6)  = 100
	  kpds(7)  = 200
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'z500') then
	  kpds(5)  = 7
	  kpds(6)  = 100
	  kpds(7)  = 500
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'z700') then
	  kpds(5)  = 7
	  kpds(6)  = 100
	  kpds(7)  = 700
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'z850') then
	  kpds(5)  = 7
	  kpds(6)  = 850
	  kpds(7)  = 700
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then
	    kpds(22) = 1
	  endif
c new batch 01/04
	else if (cparm .eq. 'z1k ') then
	  kpds(5)  = 7
	  kpds(6)  = 100
	  kpds(7)  = 1000
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'r500') then
	  kpds(5)  = 52
	  kpds(6)  = 100
	  kpds(7)  = 500
	  kpds(22) = 1
	else if (cparm .eq. 'r700') then
	  kpds(5)  = 52
	  kpds(6)  = 100
	  kpds(7)  = 700
	  kpds(22) = 1
	else if (cparm .eq. 'r850') then
	  kpds(5)  = 52
	  kpds(6)  = 100
	  kpds(7)  = 850
	  kpds(22) = 1
	else if (cparm .eq. 'mslp') then
	  kpds(5)  = 2
	  kpds(6)  = 102
	  kpds(7)  = 0
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then 
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'psfc') then
	  kpds(5)  = 1
	  kpds(6)  = 102
	  kpds(7)  = 0
	  if (ctype .eq. 'mean') then
	    kpds(22) = 0
	  else if (ctype .eq. 'spr ') then 
	    kpds(22) = 1
	  endif
	else if (cparm .eq. 'prcp') then
	  kpds(5) = 61
	  kpds(6) = 1
	  kpds(7) = 0

C          THIS NEXT STUFF IS ALREADY DONE IN ADJPDS, 
C          SO COMMENT IT OUT HERE....
C          if (kpds(14).eq.0) then
C            kpds(14) = 0
C            kpds(15) = 0
C          else
C            kpds(14) = kpds(14) - 12
C            kpds(15) = kpds(14) + 12
C          endif

	  kpds(16) = 4
	  kpds(22) = 1
	else if (cparm .eq. 'tcdc') then
	  kpds(5) = 61
	  kpds(6) = 200
	  kpds(7) = 0
	  kpds(22) = 1
	else
	  iready=no
	endif
	kens(1)=1
	kens(2)=5
	kens(3)=0
	kens(4)=0
	kens(5)=255
	if (ctype .eq. 'mean') then
	  kens(4)=1
	else if (ctype .eq. 'spr ') then
	  kens(4)=11
	endif

c       ****************************
c        WRITE GRIB FILE
c       ****************************

        print *,'In output_stats, lugout= ',lugout,' kf= ',kf
        print *,'In output_stats, cparm= ',cparm,' ctype= ',ctype
c       print *,' '

c       if ( kpds(14) .eq. 72 ) then
c         print *,' '
	  write(*,71) (kpds(mm),mm=1,5)
	  write(*,72) (kpds(mm),mm=6,10)
	  write(*,73) (kpds(mm),mm=11,15)
	  write(*,74) (kpds(mm),mm=16,20)
	  write(*,75) (kpds(mm),mm=21,25)
	  write(*,76) (kgds(mm),mm=1,5)
	  write(*,77) (kgds(mm),mm=6,10)
	  write(*,78) (kgds(mm),mm=11,15)
	  write(*,79) (kgds(mm),mm=16,20)
	  write(*,80) (kgds(mm),mm=21,22)
	  if ( ctype .eq. 'mean' ) then
	    write(*,81) datam(1),datam(kf/4),datam(kf/2)
     &                 ,datam(3*kf/4),datam(kf)
	    call srange(kf,ld,datam)
	  endif
	  if ( ctype .eq. 'spr ' ) then
	    write(*,81) datas(1),datas(kf/4),datas(kf/2)
     &                 ,datas(3*kf/4),datas(kf)
	    call srange(kf,ld,datas)
	  endif
c         print *,' '
c       endif

 71     format('p1=  ',i7,' p2=  ',i7,' p3=  ',i7,' p4=  ',i7,' p5=  '
     &        ,i7)
 72     format('p6=  ',i7,' p7=  ',i7,' p8=  ',i7,' p9=  ',i7,' p10= '
     &        ,i7)
 73     format('p11= ',i7,' p12= ',i7,' p13= ',i7,' p14= ',i7,' p15= '
     &        ,i7)
 74     format('p16= ',i7,' p17= ',i7,' p18= ',i7,' p19= ',i7,' p20= '
     &        ,i7)
 75     format('p21= ',i7,' p22= ',i7,' p23= ',i7,' p24= ',i7,' p25= '
     &        ,i7)
 76     format('g1=  ',i7,' g2=  ',i7,' g3=  ',i7,' g4=  ',i7,' g5=  '
     &        ,i7)
 77     format('g6=  ',i7,' g7=  ',i7,' g8=  ',i7,' g9=  ',i7,' g10= '
     &        ,i7)
 78     format('g11= ',i7,' g12= ',i7,' g13= ',i7,' g14= ',i7,' g15= '
     &        ,i7)
 79     format('g16= ',i7,' g17= ',i7,' g18= ',i7,' g19= ',i7,' g20= '
     &        ,i7)
 80     format('g21= ',i7,' g22= ',i7)
 81     format('f(1)= ',g12.4,' f(kf/4)= ',g12.4,' f(kf/2)= ',g12.4
     &      ,' f(3*kf/4)= ',g12.4,' f(kf)= ',g12.4)

	iret=99

        if (iready .eq. 1) then

	  if ( ctype .eq. 'mean' ) then
	    call putgbe (lugout,kf,kpds,kgds,kens,ld,datam,iret)
	  endif
	  if ( ctype .eq. 'spr ' ) then
	    call putgbe (lugout,kf,kpds,kgds,kens,ld,datas,iret)
	  endif
	  if (iret.eq.0) then
c c         print *,' '
	    print *,'IRET = 0 after call to putgbe in sub output_stats'
c c         print *,' '
	  else
	    print *,' '
	    print *,'!!! ERROR: IRET NE 0 AFTER '
     &	           ,'PUTGBE IN OUTPUT_STATS!!!'
     &             ,cparm,'= cparm',ctype,'=ctype '
     &             ,lugout,'=lugout ',iret,'=iret '
	    print *,' '
	  endif
	else
	  print *,'This variable not ready'
     &           ,cparm,'= cparm',ctype,'=ctype '
     &           ,lugout,'=lugout ',iret,'=iret '
	endif

      enddo

      call grib_close (lugout,ireto)
      if (ireto.gt.0) then
        print *,'ireto,lu from grib_close in output_stats = ',
     ,     ireto,lugout
      endif

c
      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
          subroutine srange(nlat,ld,var)
          dimension var(nlat)
          logical ld(nlat)
c produces range, mean, avg dev, std dev, skew
          ptsn=nlat
          sa=0.0
          dmin=1.e40
          dmax=-1.e40
          do j=1,nlat
	    if (ld(j)) then
	      sa=sa+var(j)
	      dmin=min(dmin,var(j))
	      dmax=max(dmax,var(j))
	    endif
          enddo
          avg=sa/ptsn
          sl=0.0
          sv=0.0
          do j=1,nlat
	    if (ld(j)) then
	      sl=sl+abs(var(j)-avg)
	      sv=sv+(var(j)-avg)**2
	    endif
          enddo
          adev=sl/ptsn
          sdev=sqrt(sv/(ptsn-1))
          if (sdev.gt.0.0) then
            ss=0.0
            do j=1,nlat
	      if (ld(j)) then
		devn=(var(j)-avg)/sdev
		ss=ss+devn**3
	      endif
            enddo
            skew=ss/ptsn
          else
            skew=0.0
          endif
c scale for cleaner output
          outmin=1.0e10
          outmax=1.0e-10
          if ( dmin.ne.0.0 ) then
            if (outmin.gt.abs(dmin)) then
                outmin =  abs(dmin)
            endif
            if (outmax.lt.abs(dmin)) then
                outmax =  abs(dmin)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if ( dmax.ne.0.0 ) then
            if (outmin.gt.abs(dmax)) then
                outmin =  abs(dmax)
            endif
            if (outmax.lt.abs(dmax)) then
                outmax =  abs(dmax)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if (  avg.ne.0.0 ) then
            if (outmin.gt.abs(avg)) then
                outmin =  abs(avg)
            endif
            if (outmax.lt.abs(avg)) then
                outmax =  abs(avg)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if ( adev.ne.0.0 ) then
            if (outmin.gt.abs(adev)) then
                outmin =  abs(adev)
            endif
            if (outmax.lt.abs(adev)) then
                outmax =  abs(adev)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if ( sdev.ne.0.0 ) then
            if (outmin.gt.abs(sdev)) then
                outmin =  abs(sdev)
            endif
            if (outmax.lt.abs(sdev)) then
                outmax =  abs(sdev)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if ( skew.ne.0.0 ) then
            if (outmin.gt.abs(skew)) then
                outmin =  abs(skew)
            endif
            if (outmax.lt.abs(skew)) then
                outmax =  abs(skew)
            endif
          else
            if (outmin.gt.1.0) then
                outmin =  1.0
            endif
            if (outmax.lt.1.0) then
                outmax =  1.0
            endif
          endif
          if ( (outmax.lt.9.9e4) .and. (outmin.gt.1.0e-5) ) then
            write(6,'('' '',6f19.13)')    dmin,dmax,avg,adev,sdev,skew
          else
            write(6,'('' '',1p,6e19.10)') dmin,dmax,avg,adev,sdev,skew
          endif
c         print *,dmin,dmax,avg,adev,sdev,skew
          return
          end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine grange(n,ld,d,dmin,dmax)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    GRANGE
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: Calculate the maximum and minimum values in an array
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
c     n        - dimension of the array
c     ld       - logical array (bit map)
c     d        - array
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
c     dmin     - minimum value in array d
c     dmin     - maximum value in array d
C
C ATTRIBUTES:
C   MACHINE:  IBM SP
C
C$$$
      logical ld
      dimension ld(n),d(n)
c
      dmin=1.e40
      dmax=-1.e40
c
      do i=1,n
        if(ld(i)) then
          dmin=min(dmin,d(i))
          dmax=max(dmax,d(i))
        endif
      enddo
c
      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      SUBROUTINE GETGBECE(LUGB,LUGI,JF,J,JPDS,JGDS,JENS,
     &                              KF,K,KPDS,KGDS,KENS,LB,F,IRET,
     &                              ktype,kfnum,ktot)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM: GETGBECE       FINDS AND UNPACKS A GRIB MESSAGE
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: FIND AND UNPACK A GRIB MESSAGE, ECMWF ENSEMBLE VERSION.
C   READ AN ASSOCIATED GRIB INDEX FILE (UNLESS IT ALREADY WAS READ).
C   FIND IN THE INDEX FILE A REFERENCE TO THE GRIB MESSAGE REQUESTED.
C   THE GRIB MESSAGE REQUEST SPECIFIES THE NUMBER OF MESSAGES TO SKIP
C   AND THE UNPACKED PDS AND GDS PARAMETERS.  (A REQUESTED PARAMETER
C   OF -1 MEANS TO ALLOW ANY VALUE OF THIS PARAMETER TO BE FOUND.)
C   IF THE REQUESTED GRIB MESSAGE IS FOUND, THEN IT IS READ FROM THE
C   GRIB FILE AND UNPACKED.  ITS MESSAGE NUMBER IS RETURNED ALONG WITH
C   THE UNPACKED PDS AND GDS PARAMETERS, THE UNPACKED BITMAP (IF ANY),
C   AND THE UNPACKED DATA.  IF THE GRIB MESSAGE IS NOT FOUND, THEN THE
C   RETURN CODE WILL BE NONZERO.
C
C PROGRAM HISTORY LOG:
C   94-04-01  IREDELL
C   97-01-17  MARCHOK - modified version for ECMWF ensemble GRIB ext.
C   01-01-16  WOBUS   - renamed and updated DOCBLOCK
C
C USAGE:    CALL GETGBECE(LUGB,LUGI,JF,J,JPDS,JGDS,JENS,
C    &                              KF,K,KPDS,KGDS,KENS,LB,F,IRET)
C   INPUT ARGUMENTS:
C     LUGB         LOGICAL UNIT OF THE UNBLOCKED GRIB DATA FILE
C     LUGI         LOGICAL UNIT OF THE UNBLOCKED GRIB INDEX FILE
C     JF           INTEGER MAXIMUM NUMBER OF DATA POINTS TO UNPACK
C     J            INTEGER NUMBER OF MESSAGES TO SKIP
C                  (=0 TO SEARCH FROM BEGINNING)
C                  (<0 TO REOPEN INDEX FILE AND SEARCH FROM BEGINNING)
C     JPDS         INTEGER (25) PDS PARAMETERS FOR WHICH TO SEARCH
C                  (=-1 FOR WILDCARD)
C     JGDS         INTEGER (22) GDS PARAMETERS FOR WHICH TO SEARCH
C                  (ONLY SEARCHED IF JPDS(3)=255)
C                  (=-1 FOR WILDCARD)
C     JENS         INTEGER (5) ENSEMBLE PDS PARMS FOR WHICH TO SEARCH
C                  (ONLY SEARCHED IF JPDS(23)=3)
C                  (=-1 FOR WILDCARD)
C   OUTPUT ARGUMENTS:
C     KF           INTEGER NUMBER OF DATA POINTS UNPACKED
C     K            INTEGER MESSAGE NUMBER UNPACKED
C                  (CAN BE SAME AS J IN CALLING PROGRAM
C                  IN ORDER TO FACILITATE MULTIPLE SEARCHES)
C     KPDS         INTEGER (25) UNPACKED PDS PARAMETERS
C     KGDS         INTEGER (22) UNPACKED GDS PARAMETERS
c
c
C     KENS         INTEGER (5) UNPACKED ENSEMBLE PDS PARMS
c
c     ***********  CODE ADDED FOR ECMWF ORIGINAL ENSEMBLE FILES  ****
c
c     ktype        10 = ECMWF control forecast
c                  11 = ECMWF perturbed forecast
c     kfnum        Ensemble Forecast Number;
c                  Control Forecast is number 0,
c                  perturbed forecast are 1-nn, where
c                  positive perturbation is an odd number,
c                  negative perturbation is an even number.
c     ktot         Total number of forecast in ensemble.
c                  This number includes the control forecast.
c
C     LB           LOGICAL (KF) UNPACKED BITMAP IF PRESENT
C     F            REAL (KF) UNPACKED DATA
C     IRET         INTEGER RETURN CODE
C                    0      ALL OK
C                    96     ERROR READING INDEX FILE
C                    97     ERROR READING GRIB FILE
C                    98     NUMBER OF DATA POINTS GREATER THAN JF
C                    99     REQUEST NOT FOUND
C                    OTHER  W3FI63 GRIB UNPACKER RETURN CODE
C
C SUBPROGRAMS CALLED:
C   BAopenr        open for BYTE-ADDRESSABLE READ, read-only
C   BAopen         open for BYTE-ADDRESSABLE READ
C   BAclose        close for BYTE-ADDRESSABLE READ
C   BAREAD         BYTE-ADDRESSABLE READ
C   GBYTEC          UNPACK BYTES
C   FI632          UNPACK PDS
C   FI633          UNPACK GDS
C   PDSEUP         UNPACK PDS EXTENSION
C   W3FI63         UNPACK GRIB
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
c IMPORTANT NOTE: THIS GETGBENS SUBROUTINE HAS BEEN MODIFIED!!!  
C                 IT IS *NOT* THE SAME GETGBENS AS IS FOUND IN  
C                 /NWPROD/W3LIB.  MODIFICATIONS WERE MADE TO IT
C                 TO BE ABLE TO READ THE ECMWF PDS EXTENSION  
c  Modified getgbens has been renamed getgbece
c
C ATTRIBUTES:
C   LANGUAGE: CRAY FORTRAN
C   LANGUAGE: ibm FORTRAN
C
C$$$
      INTEGER JPDS(25),JGDS(22),KPDS(25),KGDS(22)
      PARAMETER(LPDS=23,LGDS=22)
      INTEGER JENS(5),KENS(5)
      LOGICAL LB(JF)
      REAL F(JF)
      PARAMETER(MBUF=8192*128)
      CHARACTER CBUF(MBUF)
      SAVE LUX,NSKP,NLEN,NNUM,CBUF
      DATA LUX/0/
      CHARACTER CHEAD(2)*81
      CHARACTER CPDS(80)*1,CGDS(42)*1
C     INTEGER KPTR(16)
      INTEGER KPTR(20)
      INTEGER IPDSP(LPDS),JPDSP(LPDS),IGDSP(LGDS),JGDSP(LGDS)
      INTEGER IENSP(5),JENSP(5)
      CHARACTER GRIB(200+17*JF/8)*1
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  READ INDEX FILE
      IF(J.LT.0.OR.LUGI.NE.LUX) THEN
        call grib_open_r (lugb,ireto)
        if (ireto.gt.0) then
          print *,'ireto,lu from grib_open_r in getgbece = ',ireto,lugb
        endif
        call grib_open_r (lugi,ireto)
        if (ireto.gt.0) then
          print *,'ireto,lu from grib_open_r in getgbece = ',ireto,lugi
        endif
        print *,' in getgbece:  units b,i: ',lugb,lugi
c       REWIND LUGI
c       READ(LUGI,IOSTAT=IOS) CHEAD
c             CALL BAREAD(LUGB,LSKIP,LGRIB,LREAD,GRIB)
        ios=-1
        nskp=0
        lgrib=81
        CALL BAREAD(LUGI,NSKP,LGRIB,LREAD,CHEAD(1))
         if ( lgrib.eq.lread ) ios=0
c        print *,'ios after chead read = ',ios
         print *,'chead 42-47 = ',CHEAD(1)(42:47)
         print *,'chead 38-43 = ',CHEAD(1)(38:43)
         print *,' nskp, lgrib, lread = ',nskp,lgrib,lread
        nskp=lread
        CALL BAREAD(LUGI,NSKP,LGRIB,LREAD,CHEAD(2))
         print *,' nskp, lgrib, lread = ',nskp,lgrib,lread
        IF(IOS.EQ.0.AND.CHEAD(1)(42:47).EQ.'GB1IX1') THEN
c       IF(IOS.EQ.0.AND.CHEAD(1)(38:43).EQ.'GB1IX1') THEN
          LUX=0
         READ(CHEAD(2),'(8X,3I10,2X,A40)',IOSTAT=IOS) NSKP,NLEN,NNUM
           print *,'nlen= ',nlen,' ios= ',ios,' nskp= ',nskp,' nnum= '
     &           ,nnum
          IF(IOS.EQ.0) THEN
            NBUF=NNUM*NLEN
            IF(NBUF.GT.MBUF) THEN
              PRINT *,'GETGB: INCREASE BUFFER FROM ',MBUF,' TO ',NBUF
              NNUM=MBUF/NLEN
              NBUF=NNUM*NLEN
            ENDIF
            CALL BAREAD(LUGI,NSKP,NBUF,LBUF,CBUF)
            IF(LBUF.EQ.NBUF) THEN
c              print *,'************** lux being set equal to lugi'
              LUX=LUGI
              J=MAX(J,0)
            ENDIF
          ENDIF
        ENDIF
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  SEARCH FOR REQUEST
      KENS=0
      LGRIB=0
      KJ=J
      K=J
      KF=0
      IF(J.GE.0.AND.LUGI.EQ.LUX) THEN
        LPDSP=0
        DO I=1,LPDS
          IF(JPDS(I).NE.-1) THEN
            LPDSP=LPDSP+1
            IPDSP(LPDSP)=I
            JPDSP(LPDSP)=JPDS(I)
          ENDIF
        ENDDO
        LGDSP=0
        IF(JPDS(3).EQ.255) THEN
          DO I=1,LGDS
            IF(JGDS(I).NE.-1) THEN
              LGDSP=LGDSP+1
              IGDSP(LGDSP)=I
              JGDSP(LGDSP)=JGDS(I)
            ENDIF
          ENDDO
        ENDIF
        LENSP=0
        IF(JPDS(23).EQ.3 .or. jpds(23).eq.0.or.jpds(23).eq.-1) THEN
          DO I=1,5
            IF(JENS(I).NE.-1) THEN
              LENSP=LENSP+1
              IENSP(LENSP)=I
              JENSP(LENSP)=JENS(I)
            ENDIF
          ENDDO
        else
          print *,'!!! jpds(23) != 0 or 3, jpds(23)= ',jpds(23)
        ENDIF
        IRET=99
        DOWHILE(LGRIB.EQ.0.AND.KJ.LT.NNUM)
          KJ=KJ+1
          LT=0
          IF(LPDSP.GT.0) THEN
            CPDS=CBUF((KJ-1)*NLEN+26:(KJ-1)*NLEN+53)
            KPTR=0
            CALL GBYTEC(CBUF,KPTR(3),(KJ-1)*NLEN*8+25*8,3*8)
            CALL FI632(CPDS,KPTR,KPDS,IRET)
c            print *, 'after fi632, iret=',iret
            DO I=1,LPDSP
              IP=IPDSP(I)
              LT=LT+ABS(JPDS(IP)-KPDS(IP))
            ENDDO
          ENDIF
          IF(LT.EQ.0.AND.LGDSP.GT.0) THEN
            CGDS=CBUF((KJ-1)*NLEN+54:(KJ-1)*NLEN+95)
            KPTR=0
            CALL FI633(CGDS,KPTR,KGDS,IRET)
c            print *, 'after fi633, iret=',iret
            DO I=1,LGDSP
              IP=IGDSP(I)
              LT=LT+ABS(JGDS(IP)-KGDS(IP))
            ENDDO
          ENDIF
c          print *, 'lt=',lt,'lensp=',lensp
          IF(LT.EQ.0.AND.LENSP.GT.0) THEN
            CPDS(41:80)=CBUF((KJ-1)*NLEN+113:(KJ-1)*NLEN+152)
c           CALL PDSEUP(KENS,KPROB,XPROB,KCLUST,KMEMBR,45,CPDS)
            CALL ecmext(ktype,kfnum,ktot,45,CPDS)
            DO I=1,LENSP
              IP=IENSP(I)
              LT=LT+ABS(JENS(IP)-KENS(IP))
            ENDDO
          ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  READ AND UNPACK GRIB DATA
          IF(LT.EQ.0) THEN
            CALL GBYTEC(CBUF,LSKIP,(KJ-1)*NLEN*8,4*8)
            CALL GBYTEC(CBUF,LGRIB,(KJ-1)*NLEN*8+20*8,4*8)
            CGDS=CBUF((KJ-1)*NLEN+54:(KJ-1)*NLEN+95)
            KPTR=0
            CALL FI633(CGDS,KPTR,KGDS,IRET)
c           print *, 'after FI633, iret=',iret
            IF(KPDS(23).EQ.3 .or. kpds(23).eq.0.or.kpds(23).eq.-1) THEN
              CPDS(41:80)=CBUF((KJ-1)*NLEN+113:(KJ-1)*NLEN+152)
c              CALL PDSEUP(KENS,KPROB,XPROB,KCLUST,KMEMBR,45,CPDS)
              CALL ecmext(ktype,kfnum,ktot,45,CPDS)
            else
              print *,'!!! kpds(23) != 0 or 3, kpds(23)= ',kpds(23)
            ENDIF
            IF(LGRIB.LE.200+17*JF/8.AND.KGDS(2)*KGDS(3).LE.JF) THEN
              CALL BAREAD(LUGB,LSKIP,LGRIB,LREAD,GRIB)
              IF(LREAD.EQ.LGRIB) THEN
                CALL W3FI63(GRIB,KPDS,KGDS,LB,F,KPTR,IRET)
c               print *, 'after W3FI63, iret=',iret
                IF(IRET.EQ.0) THEN
                  K=KJ
                  KF=KPTR(10)
                ENDIF
              ELSE
                IRET=97
              ENDIF
            ELSE
              IRET=98
            ENDIF
          ENDIF
        ENDDO
      ELSE
        IRET=96
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      RETURN
      END
c
C----------------------------------------------------------------------c
C----------------------------------------------------------------------c
c
      SUBROUTINE ecmext(ktype,kfnum,ktot,ILAST,MSGA)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    ecmext.f    UNPACKS GRIB PDS EXTENSION 41- FOR ENSEMBLE
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: unpacks GRIB pds extension starting on byte 41 for ECMWF
c           ensemble files.  NOTE that this extension format is 
c           completely different from NCEP's extension format, and
c           this subroutine will not work if you try to read NCEP 
c           ensemble files.  This subroutine will unpack bytes 
c           41-52 of the pds header extension.
C
C PROGRAM HISTORY LOG:
c   97-01-17  Tim Marchok (Most of the code, however, is taken from 
c                          the pdseup.f subroutine, originally written
c                          by Mark Iredell and Zoltan Toth).
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
c   
C
C USAGE:    call ecmext(ktype,kfnum,ktot,ILAST,MSGA)
C   INPUT ARGUMENT LIST:
C     ILAST    - LAST BYTE TO BE UNPACKED (IF GREATER/EQUAL TO FIRST BYT
C                IN ANY OF FOUR SECTIONS BELOW, WHOLE SECTION IS PACKED.
C     MSGA     - FULL PDS SECTION, INCLUDING NEW ENSEMBLE EXTENSION
C
C   OUTPUT ARGUMENT LIST:      
c
c     *********  ECMWF PDS EXTENSION BYTE LIST  ****************
c
c     ludn       Byte 41 (Local Use Definition Number; should = 1)
c     kclass     Byte 42 (1=Operations; 2=Research)
c     ktype      Byte 43 (10=Control Fcst; 11=Perturbed Forecast)
c     kstream    Bytes 44-45 (1035=Ensemble Forecasts)
c     kver       Bytes 46-49 (Version Number/Experiment Identifier;
c                             4 ascii characters, right justified)
c     kfnum      Byte 50 (Ensemble Forecast Number;
c                         Control Forecast is number 0,
c                         perturbed forecast are 1-nn, where
c                         positive perturbation is an odd number,
c                         negative perturbation is an even number.
c     ktot       Byte 51 (Total number of forecasts in ensemble.
c                         This number includeds the control forecast).
c     -----      Byte 52 (Reserved, should be set to 0).
c
C
C REMARKS: USE PDSENS.F FOR PACKING PDS ENSEMBLE EXTENSION.
C
C ATTRIBUTES:
C   LANGUAGE: CF77 FORTRAN
C   MACHINE:  CRAY, WORKSTATIONS
C
C$$$
C
      INTEGER KENS(5),KPROB(2),KCLUST(16),KMEMBR(80)
      integer ludn,kclass,ktype,kstream,kver,kfnum,ktot
      DIMENSION XPROB(2)
      CHARACTER*1 MSGA(100)
      character*1 cver(4)
c
C     CHECKING TOTAL NUMBER OF BYTES IN PDS (IBYTES)
c      print *,' '
      CALL GBYTEC(MSGA, IBYTES, 0,24)
c      PRINT *,'IBYTES (length of pds) = ',IBYTES
      IF (ILAST.GT.IBYTES) THEN
C       ILAST=IBYTES
        PRINT *,'ERROR - THERE ARE ONLY ',IBYTES, ' BYTES IN THE PDS.'
        GO TO 333
      ENDIF
      IF (ILAST.LT.41) THEN
        PRINT *,'WARNING - SUBROUTINE FOR UNPACKING BYTES 41 AND ABOVE'
        GO TO 333
      ENDIF
C     UNPACKING FIRST SECTION (GENERAL INFORMATION)
c
      CALL GBYTEC(MSGA,ludn,40*8,8)
c      print *,'ludn= ',ludn
      CALL GBYTEC(MSGA,kclass,41*8,8)
c      print *,'kclass= ',kclass
      CALL GBYTEC(MSGA,ktype,42*8,8)
c      print *,'ktype= ',ktype
      CALL GBYTEC(MSGA,kstream,43*8,16)
c      print *,'kstream= ',kstream
c      CALL GBYTEC(MSGA,kver,45*8,32)
      do ii=1,4
        cver(ii) = msga(ii+45)
      enddo
c      print '(17a,3x,4a1)','Version Number = ',cver
      CALL GBYTEC(MSGA,kfnum,49*8,8)
c      print *,'kfnum= ',kfnum
      CALL GBYTEC(MSGA,ktot,50*8,8)
c      print *,'ktot= ',ktot
      CALL GBYTEC(MSGA,junk,51*8,8)
c      print *,'Byte 52= ',junk
c
c    &             ,' str=',kstream,' ver=',kver,' mem=',kfnum
c      print '(7(a6,i6))','  lu=',ludn,' cls=',kclass,' typ=',ktype
c     &             ,' str=',kstream,' mem=',kfnum
c     &             ,' tot=',ktot,' b52=',junk
      goto 333
C
 333  CONTINUE
      RETURN
      END
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine grib_close (lug,iret)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    grib_close
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$

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
C     lug      The Fortran unit number for the GRIB file
C     OUTPUT:
C     iret     The return code from this subroutine

      character unitname*11
      character fname*80

      unitname(1:11) = "XLFUNIT_   "
      if (lug.lt.100) then
	write(unitname(9:10),'(I2)') lug
      else
	write(unitname(9:11),'(I3)') lug
      endif
      call getenv(unitname,fname)
c     print *,' '
c     print *,' in grib_close:  unit: ',lug
c     print *,' in grib_close:  fname: ',fname
      ioret=0
      call baclose (lug,fname,ioret)

c     print *,' ' 
c     print *,'baclose: ioret= ',ioret

      iret=0
      if (ioret /= 0) then
        print *,' '
        print *,'!!! ERROR in grib_close closing grib file'
        print *,'!!! baclose return code = ioret = ',ioret
        iret = 93
        return
      endif

      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine grib_open (lug,iret)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    grib_open
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$

C     ABSTRACT: This subroutine must be called before any attempt is
C     made to access the GRIB file.  The GRIB file
C     is opened with a call to baopen.  This call to baopen was not
C     needed in the cray version of this program (the files could be
C     opened with a simple Cray assign statement), but the GRIB I/O
C     utilities on the SP do require calls to this subroutine (it has
C     something to do with the GRIB I/O being done in C on the SP, and
C     the C I/O package needs an explicit open statement).
C
C     INPUT:
C     lug      The Fortran unit number for the GRIB file
C     OUTPUT:
C     iret     The return code from this subroutine

      character unitname*11
      character fname*80

c     unitname(1:8) = "XLFUNIT_"
      unitname(1:11) = "XLFUNIT_   "
      if (lug.lt.100) then
	write(unitname(9:10),'(I2)') lug
      else
	write(unitname(9:11),'(I3)') lug
      endif
c     write(unitname(9:10),'(I2)') lug
      call getenv(unitname,fname)
c     print *,' '
c     print *,' in grib_open:  unit: ',lug
c     print *,' in grib_open:  fname: ',fname
      ioret=0
      call baopen (lug,fname,ioret)

c     print *,' ' 
c     print *,'baopen: ioret= ',ioret

      iret=0
      if (ioret /= 0) then
        print *,' '
        print *,'!!! ERROR in grib_open opening grib file'
        print *,'!!! baopen return code = ioret = ',ioret
        iret = 93
        return
      endif

      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine grib_open_wa (lug,iret)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    grib_open_wa
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: START ABSTRACT HERE AND INDENT TO COLUMN 5 ON THE
C   FOLLOWING LINES.  PLEASE PROVIDE A BRIEF DESCRIPTION OF
C   WHAT THE SUBPROGRAM DOES.
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     INARG1   - GENERIC DESCRIPTION, INCLUDING CONTENT, UNITS,
C     INARG2   - TYPE.  EXPLAIN FUNCTION IF CONTROL VARIABLE.
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     WRKARG   - GENERIC DESCRIPTION, ETC., AS ABOVE.
C     OUTARG1  - EXPLAIN COMPLETELY IF ERROR RETURN
C     ERRFLAG  - EVEN IF MANY LINES ARE NEEDED
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C
C   OUTPUT FILES:  (DELETE IF NO OUTPUT FILES IN SUBPROGRAM)
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$

C     ABSTRACT: This subroutine must be called before any attempt is
C     made to write to from the output GRIB files.  The GRIB file
C     is opened with a call to baopenwa.  This call to baopenwa was not
C     needed in the cray version of this program (the files could be
C     opened with a simple Cray assign statement), but the GRIB-writing
C     utilities on the SP do require calls to this subroutine (it has
C     something to do with the GRIB I/O being done in C on the SP, and
C     the C I/O package needs an explicit open statement).
C
C     INPUT:
C     lug      The Fortran unit number for the GRIB file
C     OUTPUT:
C     iret     The return code from this subroutine

c     character unitname*10
      character unitname*11
      character fname*80

c     unitname(1:8) = "XLFUNIT_"
      unitname(1:11) = "XLFUNIT_   "
      if (lug.lt.100) then
	write(unitname(9:10),'(I2)') lug
      else
	write(unitname(9:11),'(I3)') lug
      endif
c     write(unitname(9:10),'(I2)') lug
      call getenv(unitname,fname)
c     print *,' '
c     print *,' in grib_open_wa:  unit: ',lug
c     print *,' in grib_open_wa:  fname: ',fname
      ioret=0
      call baopenwa (lug,fname,ioret)

c     print *,' ' 
c     print *,'baopenwa: ioret= ',ioret

      iret=0
      if (ioret /= 0) then
        print *,' '
        print *,'!!! ERROR in grib_open_wa opening grib file'
        print *,'!!! baopenwa return code = ioret = ',ioret
        iret = 93
        return
      endif

      return
      end
c
c----------------------------------------------------------------------c
c----------------------------------------------------------------------c
c
      subroutine grib_open_r (lug,iret)
c$$$  SUBPROGRAM DOCUMENTATION BLOCK
C                .      .    .                                       .
C SUBPROGRAM:    grib_open_r
C   PRGMMR: WOBUS            ORG: NP20        DATE: 2001-01-16
C
C ABSTRACT: This subroutine must be called before any attempt is
C   made to read from the input GRIB files.  The GRIB and index files
C   are opened with a call to baopenr.  This call to baopenr was not
C   needed in the cray version of this program (the files could be
C   opened with a simple Cray assign statement), but the GRIB-reading
C   utilities on the SP do require calls to this subroutine (it has
C   something to do with the GRIB I/O being done in C on the SP, and
C   the C I/O package needs an explicit open statement).
C
C PROGRAM HISTORY LOG:
C   97-01-17  MARCHOK     original program
C   01-01-16  WOBUS       added DOCBLOCK
C
C USAGE:    CALL PROGRAM-NAME(INARG1, INARG2, WRKARG, OUTARG1, ... )
C   INPUT ARGUMENT LIST:
C     lug      The Fortran unit number for the GRIB file
C
C   OUTPUT ARGUMENT LIST:      (INCLUDING WORK ARRAYS)
C     iret     The return code from this subroutine
C
C   INPUT FILES:   (DELETE IF NO INPUT FILES IN SUBPROGRAM)
C     lug      The Fortran unit number for the GRIB file
C
C REMARKS: LIST CAVEATS, OTHER HELPFUL HINTS OR INFORMATION
C
C ATTRIBUTES:
C   LANGUAGE: INDICATE EXTENSIONS, COMPILER OPTIONS
C   MACHINE:  IBM SP
C
C$$$

C
C     INPUT:
C     OUTPUT:

c     character unitname*10
      character unitname*11
      character fname*80

c     unitname(1:8) = "XLFUNIT_"
      unitname(1:11) = "XLFUNIT_   "
      if (lug.lt.100) then
	write(unitname(9:10),'(I2)') lug
      else
	write(unitname(9:11),'(I3)') lug
      endif
c     write(unitname(9:10),'(I2)') lug
      call getenv(unitname,fname)
c     print *,' '
c     print *,' in grib_open_r:  unit: ',lug
c     print *,' in grib_open_r:  fname: ',fname
      ioret=0
      call baopenr (lug,fname,ioret)

c     print *,' ' 
c     print *,'baopenr: ioret= ',ioret

      iret=0
      if (ioret /= 0) then
        print *,' '
        print *,'!!! ERROR in sub grib_open_r opening grib file'
        print *,'!!! baopenr return code = ioret = ',ioret
        iret = 93
        return
      endif

      return
      end
