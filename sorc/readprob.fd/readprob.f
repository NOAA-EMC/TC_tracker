ccc  read out TC probability ccccccccccccccccccccccccccc
      program readprob
      parameter (nx=241, ny=40, nt=29)
      real xprob(nx,ny), xmax(nt)
      character*44 infile, outfile

      call read_nlists (infile,outfile)

      open (52,file=infile,
     &      form='unformatted', access='direct',recl=nx*ny*4)
      irec1=1

      do k=1,nt
        xmax(k)=0.0
      enddo

      do k=1,nt
        read(52,rec=irec1,err=101) ((xprob(i,j),i=1,nx),j=1,ny)
	irec1=irec1+1

	do i=1,nx
	do j=1,ny
          if(xprob(i,j).gt.xmax(k)) then
	    xmax(k)=xprob(i,j)
          endif
        enddo
	enddo
c       write(*,*) 'forecast hour=',(k-1)*6,'xmax(k)=',xmax(k)*100

      enddo
101   continue
      close(52)

c      open(51,file=outfile,
c     &      form='unformatted', access='direct',recl=nt*4)
c      write(51,rec=1) (xmax(k)*100, k=1,nt)
c      close(51)

c      open(53,file='tcgen.dat')
      open(53,file=outfile)

      xmean=0.0
      do k=1,9
	xmean=xmean+xmax(k)
      enddo
      xmean=xmean/9.0
      write(53,103) xmean*100
103   format(1x,f5.1,'% 48h-probability forecast')

      do k=1,nt
c       write(*,*) 'forecast hour=',(k-1)*6,'prob=',xmax(k)*100 
       write(53,102) (k-1)*6,xmax(k)*100
      enddo
      close(53)

102   format(1x,i5,1x,f5.1)
      stop
      end

c-----------------------------------------------------------------------
      subroutine read_nlists (infile,outfile)

c     ABSTRACT: This subroutine simply reads in the namelists that are
c     created in the shell script.
c   infile aemn.trkprob.AL95.65nm.2011062718.indiv.ieee
c   outfile aemn.trkprob.AL95.65nm.2011062718.indiv.data

      character*44 infile, outfile, kymdh0, kymdh1
      namelist/datain0/kymdh0
      namelist/datain1/kymdh1


      read (5,NML=datain0,END=88)
88    continue
      read (5,NML=datain1,END=99)
99    continue

      infile=kymdh0
      outfile=kymdh1

      return
      end
