c---------------------------------------------------------------------
      program tcvital_to_gen
cJ.Peng----2012-05-03-------------------------------------------------
c ABSTRACT: This subroutine  outputs a tcvital record from a genesis
c           TC vital file
c     input: genesis.vitals.gfs.gfso.2012
c     output: gen_tc.vitals.gfs.gfso.2012 
c---------------------------------------------------------------------

      character gen_name*30, gen_lat*4, gen_lon*5, gen_end*1
      integer junk(11), ist, ymd, hhmm

      character h_center*4,h_name*9,h_end*1 

      h_center='NCEP'
      h_name='unnamedTC'
      h_end='G'

      ist=0
      readloop: do while (.true.)
        ist=ist+1
        read (41,85,end=870) gen_name, ymd, hhmm, gen_lat
     &      ,gen_lon, (junk(i),i=1,11), gen_end 

        write (42,81) h_center, ist, h_name, ymd, hhmm
     &      ,gen_lat, gen_lon, (junk(i),i=1,11), h_end

      enddo readloop


 85   format (a30,1x,i8,1x,i4,1x,a4,1x,a5,1x,i3,1x,i3,3(1x,i4),
     &       1x,i2,1x,i3,4(1x,i4),1x,a1)


 81   format (a4,1x,i2.2,'K',1x,a9,1x,i8.8,1x,i4.4,1x,a4,1x,a5,1x
     &       ,i3,1x,i3,3(1x,i4),1x,i2,1x,i3,1x,4(i4,1x),a1)


 870  continue

      stop
      end

