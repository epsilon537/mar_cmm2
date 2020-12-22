Color Maximite 2 Archiving Tool by Epsilon
------------------------------------------
Current Version: 0.4

ChangeLog
---------
0.4:
- Combined mac.bas and max.bas into a single program, mar.bas.
- Added option to create and extract LZ1 compressed archives.
- Created an equivalent Python version, mar.py, intended for running on a host machine (Windows, MacOSX, Linux).
- DOS MMBasic version of mac.bas is no longer supported. Please use Python version instead.

0.3:
- Fix bug on DOS causing script to error out if current working directory contains spaces.
- On DOS delete temporary files ntsh.temp.
- max.bas now prompts before overwrite (instead of aborting).
- Some cosmetic fixes.

0.2:
- Fix command line processing on DOS.
- Fix bug on DOS where sometimes 'directory not found' would be reported even though directory is present.

0.1:
- Initial version.

Description
-----------
On CMM2, mar.bas allows you to roll up and optionally compress a directory tree into a single file archive, and vice versa.
mar.py is an equivalent Python implementation intended for running on Windows, MacOSX or Linux. This allows you to create your archive on a host machine,
transfer it over to CMM2 and unpack it there, and vice versa.

Usage
-----
On CMM2:
  *mar c <dir> : archive directory <dir> into file <dir>.mar
  *mar cz <dir> : archive and lz1 compress directory <dir> into file <dir>.mz1
  *mar x <archive>.mar : extract <archive>.mar archive
  *mar xz <archive>.mz1 : extract <archive>.mz1 compressed archive

On Windows/MacOSX/Linux:
  python mar c <dir> : archive directory <dir> into file <dir>.mar
  python mar cz <dir> : archive and lz1 compress directory <dir> into file <dir>.mz1
  python mar x <archive>.mar : extract <archive>.mar archive
  python mar xz <archive>.mz1 : extract <archive>.mz1 compressed archive

Required CMM2 firmware version
------------------------------
V5.06.00

Required Python version
-----------------------
3.x

GitHub
------
https://github.com/epsilon537/mar_cmm2
