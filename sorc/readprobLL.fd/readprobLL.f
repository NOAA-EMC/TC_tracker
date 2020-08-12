ccc  read out TC probability ccccccccccccccccccccccccccc
cc  nt=1-29, 28*6=168hrs (7days)
cc  nx=1-241, Lon=105E-345E
cc  ny=1-40, Lat=1N-40N
cc  Jiayi.Peng  04/07/2016
c------------------------------------------------------
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
        end type atcfunix_card
      end module define_atcfunix_rec

      module define_atcf_pro_rec
        type atcf_pro_card    ! Define a new type for an atcfunix card
          sequence
          character*2   pro_basin       ! Hurricane Center Acronym
          character*2   pro_storm_num   ! Storm number (03, etc)
          character*10  pro_ymdh        ! Fcst start date (yyyymmddhh)
          character*2   pro_technum     ! Always equal to 03 for models
          character*4   pro_model       ! Name of forecast model
          integer       pro_fcsthr      ! Fcst hour (i3.3)
          integer       pro_lat         ! Storm Lat (*10), always >0
          character*1   pro_latns       ! 'N' or 'S'
          integer       pro_lon         ! Storm Lon (*10), always >0
          character*1   pro_lonew       ! 'E' or 'W'
          integer       pro_prob        ! genesis probability (%)
        end type atcf_pro_card
      end module define_atcf_pro_rec

      program readprob
      USE define_atcfunix_rec
      USE define_atcf_pro_rec

      type (atcfunix_card) inprec
      type (atcf_pro_card) stm

      parameter (nx=241, ny=40, nt=29)
      real xprob(nx,ny), xmax(nt), xlat(nt), xlon(nt)
      character*44 infile, outfile
      character*34 infile2

      call read_nlists (infile,outfile,infile2)

      open (52,file=infile,
     &      form='unformatted', access='direct',recl=nx*ny*4)
      irec1=1

      do k=1,nt
        xmax(k)=0.0
        xlat(k)=999.0
        xlon(k)=999.0
      enddo

      do k=1,nt
        read(52,rec=irec1,err=101) ((xprob(i,j),i=1,nx),j=1,ny)
	irec1=irec1+1

	do i=1,nx
	do j=1,ny
          if(xprob(i,j).gt.xmax(k)) then
	    xmax(k)=xprob(i,j)
            xlon(k)=105.0+(i-1)*1.0
            xlat(k)=40.0-(j-1)*1.0
          endif
        enddo
	enddo

      enddo
101   continue
      close(52)

      open(53,file=outfile)
      open(54,file=infile2)

c      xmean=0.0
c      do k=1,9
c	xmean=xmean+xmax(k)
c      enddo
c      xmean=xmean/9.0
c      write(53,103) xmean*100
c103   format(1x,f5.1,'% 48h-probability forecast')
c      do k=1,nt
c       write(53,102) (k-1)*6,xmax(k)*100,xlat(k),xlon(k)
c      enddo
c102   format(1x,i5,1x,f5.1,1x,f5.1,1x,f5.1)
      readloop: do while (.true.)
        read (54,85,end=870) inprec
          stm%pro_basin=inprec%atx_basin
          stm%pro_storm_num=inprec%atx_storm_num
          stm%pro_ymdh=inprec%atx_ymdh
          stm%pro_technum=inprec%atx_technum
          stm%pro_model=inprec%atx_model
          stm%pro_fcsthr=inprec%atx_fcsthr
          stm%pro_lat=inprec%atx_lat
          stm%pro_latns=inprec%atx_latns
          stm%pro_lon=inprec%atx_lon
          stm%pro_lonew=inprec%atx_lonew

          ihr=stm%pro_fcsthr
          k=ihr/6+1
          stm%pro_prob=xmax(k)*100

          write (53,81) stm%pro_basin, stm%pro_storm_num,
     & stm%pro_ymdh, stm%pro_technum, stm%pro_model,
     & stm%pro_fcsthr, stm%pro_lat, stm%pro_latns,
     $ stm%pro_lon, stm%pro_lonew, stm%pro_prob
      enddo readloop

 85   format (a2,2x,a2,2x,a10,2x,a2,2x,a4,2x,i3
     &       ,2x,i3,a1,2x,i4,a1)

 81   format (a2,', ',a2,', ',a10,', ',a2,', ',a4,
     &       ', ',i3.3,', ',i3,a1,', ',i4,a1,', '
     &       ,i3)

 870  continue
          
      close(54)
      close(53)

      stop
      end

c-----------------------------------------------------------------------
      subroutine read_nlists (infile,outfile,infile2)

c     ABSTRACT: This subroutine simply reads in the namelists that are
c     created in the shell script.
c   infile aemn.trkprob.AL95.65nm.2011062718.indiv.ieee
c   outfile aemn.trkprob.AL95.65nm.2011062718.indiv.data
c   infile2 trak.aemn.atcfunix.2016040500.HC01

      character*44 infile, outfile, kymdh0, kymdh1
      character*34 infile2, kymdh2
      namelist/datain0/kymdh0
      namelist/datain1/kymdh1
      namelist/datain2/kymdh2

      read (5,NML=datain0,END=55)
55    continue
      read (5,NML=datain1,END=66)
66    continue
      read (5,NML=datain2,END=77)
77    continue

      infile=kymdh0
      outfile=kymdh1
      infile2=kymdh2

      return
      end
