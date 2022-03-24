ccc  output lead-time in minutes  ccccccccccccccccccccccccccc
      program leadtime
      parameter (nt=81)
      integer time(nt)
      integer maxhrs,dthrs
      namelist/timein/maxhrs,dthrs

      read (5,NML=timein,END=201)
  201 continue
      print *,' '
      print *,'*---------------------------------------------*'
      print *,' '
      print *,' +++ Top of LEADTIME +++ '
      print *,' '
      print *,'After LEADTIME namelist read, input forecast max-hours= '
     &       ,maxhrs
      print *,'       input forecast hour interval= ',dthrs

c      open (10,file="tracker_leadtime")

      IDT=dthrs*60
      nhrs=maxhrs/dthrs

      do k=1,nhrs+1
        time(k)= (k-1)*IDT
        write(10,102) k, time(k)
      enddo

c      close(10)

102   format(2x,i2,1x,i5)
      stop
      end

