mac/max Color Maximite 2 Archiving Tool by Epsilon
--------------------------------------------------
Current Version: 0.2

ChangeLog
---------
0.2:
- Fix command line processing on DOS.
- Fix bug on DOS where sometimes 'directory not found' would be reported even though directory is present.

0.1:
- Initial version.

Description
-----------
Mac.bas allows you to roll up a directory tree into a single file archive. 
The created archive has the same name as the given directory, with a .mar extension.

Max.bas allows you to unpack a .mar archive, creating a directory tree with the same name as the given archive, without the .mar extension.

Mac.bas and Max.bas work both on PC and on Color Maximite 2, so you can download a package on your PC (e.g. Mauro's psgmini_cmm2 demo), archive it on PC using mac.bas, transfer it over to your CMM2 using XMODEM, and unpack the archive on your CMM2 using max.bas.

Example 1: Creating a .mar archive on CMM2
------------------------------------------
> list files
A:/
   <DIR>  bak
   <DIR>  psgmini_cmm2
10:47 18-09-2020       7847  mac.bas
09:23 18-09-2020       9216  max.bas
...
3 directories, 13 files
>
> *mac psgmini_cmm2
Create Maximite Archive 0.1 by Epsilon
  Processing dir psgmini_cmm2
  Processing file .gitattributes
  Processing file psgdemo.bas
  Processing file psgmini.inc
  Processing file README.md
    Processing dir ASSETS
    Processing file ALESTE.VGM
    ...
Done.

> list files
A:/
   <DIR>  bak
   <DIR>  psgmini_cmm2
10:47 18-09-2020       7847  mac.bas
09:23 18-09-2020       9216  max.bas
11:08 18-09-2020     878068  psgmini_cmm2.mar
...

Example 2:Extracting a .mar archive on CMM2
-------------------------------------------

> list files
A:/
   <DIR>  bak
10:47 18-09-2020       7847  mac.bas
09:23 18-09-2020       9216  max.bas
11:08 18-09-2020     878068  psgmini_cmm2.mar
...

> *max psgmini_cmm2.mar
Extract Maximite Archive 0.1 by Epsilon
  mkdir psgmini_cmm2
Processing file .gitattributes
Processing file psgdemo.bas
Processing file psgmini.inc
Processing file README.md
  mkdir ASSETS
Processing file ALESTE.VGM
Processing file ALEXKIDD.VGM
Processing file AWESOME.vgm
Processing file BATTLETOADS2.VGM
Processing file BEAST1.vgm
...
End of archive reached.
Done.

> list files
A:/
   <DIR>  bak
   <DIR>  psgmini_cmm2
10:47 18-09-2020       7847  mac.bas
09:23 18-09-2020       9216  max.bas
11:08 18-09-2020     878068  psgmini_cmm2.mar
...

Example 3: Creating a .mar archive on PC
----------------------------------------

c:\cmm2\mar>dir
 Volume in drive C is OS
 Volume Serial Number is 8497-A711

 Directory of c:\cmm2\mar

09/18/2020  12:04 PM    <DIR>          .
09/18/2020  12:04 PM    <DIR>          ..
09/18/2020  10:48 AM             7,845 mac.bas
09/18/2020  12:02 PM             2,365 mac_max.readme
09/17/2020  10:11 PM             9,178 max.bas
09/18/2020  12:04 PM                 0 ntsh.temp
09/18/2020  12:04 PM    <DIR>          psgmini_cmm2
               5 File(s)        897,456 bytes
               3 Dir(s)  101,267,017,728 bytes free

c:\cmm2\mar>..\DOS_MMBasic\MMBasic.exe mac.bas psgmini_cmm2
...
c:\cmm2\mar>dir
 Volume in drive C is OS
 Volume Serial Number is 8497-A711

 Directory of c:\cmm2\mar

09/18/2020  12:04 PM    <DIR>          .
09/18/2020  12:04 PM    <DIR>          ..
09/18/2020  10:48 AM             7,845 mac.bas
09/18/2020  12:02 PM             2,365 mac_max.readme
09/17/2020  10:11 PM             9,178 max.bas
09/18/2020  12:04 PM                 0 ntsh.temp
09/18/2020  12:04 PM    <DIR>          psgmini_cmm2
09/18/2020  12:03 PM           878,068 psgmini_cmm2.mar
               5 File(s)        897,456 bytes
               3 Dir(s)  101,267,017,728 bytes free

Example 4: Extracting a .mar archive on PC
----------------------------------------  

c:\cmm2\mar>dir
 Volume in drive C is OS
 Volume Serial Number is 8497-A711

 Directory of c:\cmm2\mar

09/18/2020  12:04 PM    <DIR>          .
09/18/2020  12:04 PM    <DIR>          ..
09/18/2020  10:48 AM             7,845 mac.bas
09/18/2020  12:02 PM             2,365 mac_max.readme
09/17/2020  10:11 PM             9,178 max.bas
09/18/2020  12:04 PM                 0 ntsh.temp
09/18/2020  12:03 PM           878,068 psgmini_cmm2.mar
               5 File(s)        897,456 bytes
               3 Dir(s)  101,267,017,728 bytes free    

c:\cmm2\mar>..\DOS_MMBasic\MMBasic.exe max.bas psgmini_cmm2.mar

c:\cmm2\mar>dir
 Volume in drive C is OS
 Volume Serial Number is 8497-A711

 Directory of c:\cmm2\mar

09/18/2020  12:04 PM    <DIR>          .
09/18/2020  12:04 PM    <DIR>          ..
09/18/2020  10:48 AM             7,845 mac.bas
09/18/2020  12:02 PM             2,365 mac_max.readme
09/17/2020  10:11 PM             9,178 max.bas
09/18/2020  12:04 PM                 0 ntsh.temp
09/18/2020  12:04 PM    <DIR>          psgmini_cmm2
09/18/2020  12:03 PM           878,068 psgmini_cmm2.mar
               5 File(s)        897,456 bytes
               3 Dir(s)  101,267,017,728 bytes free

