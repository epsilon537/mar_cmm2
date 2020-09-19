OPTION EXPLICIT
OPTION DEFAULT NONE
OPTION BASE 0

CONST MAX_CHUNK_SIZE% = 128
CONST VERSION$ = "0.2"
PRINT "Extract Maximite Archive " VERSION$ " by Epsilon"

'DOS specific constants and variables'
IF MM.DEVICE$ = "DOS" THEN
  CONST MAX_NUM_DIRS%=100
  CONST MAX_NUM_FILES%=400

  DIM refFile$ = CWD$ + "\ntsh.temp"
  DIM dirList$(MAX_NUM_DIRS%)
  DIM fileList$(MAX_NUM_FILES%)
  DIM dirListIdx%, fileListIdx%

  PRINT "Please ignore the File Not Found messages below."
ENDIF 'DOS specific constants and variables

DIM archiveName$, cmdLine$
DIM recursionLevel% = 0
DIM errno% = 0

'Allow to pass in archive to extract as command line argument
IF MM.DEVICE$ = "DOS" THEN
  'If no arguments are passed in, the INSTR below will return 0.
  IF INSTR(MM.CMDLINE$, " ") = 0 THEN
    cmdLine$ =""
  ELSE
    cmdLine$ = RIGHT$(MM.CMDLINE$, LEN(MM.CMDLINE$) - INSTR(MM.CMDLINE$, " "))
  ENDIF
ELSE
  cmdLine$ = MM.CMDLINE$
ENDIF

'Allow to pass in archive as command line argument
IF (cmdLine$ = "") THEN
  INPUT "Archive to extract:"; archiveName$
ELSE
  archiveName$ = cmdLine$
ENDIF

IF fileExists%(archiveName$) = 0 THEN
  PRINT "Archive not found. Aborting..."
  GOTO EndOfPrg
ENDIF

OPEN archiveName$ FOR INPUT AS #1
readFromArchive
IF errno% <> 0 THEN
  GOTO EndOfPrg
ENDIF

IF MM.DEVICE$ = "DOS" THEN
  PRINT "Please ignore the File Not Found messages above."
ENDIF

PRINT "Done."

EndOfPrg:
IF errno% <> 0 THEN
  PRINT "errno=" errno%
ENDIF

ON ERROR SKIP 1
CLOSE #1

ON ERROR SKIP 1
CLOSE #2

ON ERROR SKIP 1
CLOSE #3

'DOS requires a QUIT or we get stuck on the BASIC prompt.
IF MM.DEVICE$ = "DOS" THEN
  QUIT
ENDIF

'This function checks if given directory name already exists or not
FUNCTION dirExists%(dirName$)
  IF MM.DEVICE$ = "DOS" THEN
    'DOS MMBasic does not have a DIR$ function :-(
    ON ERROR SKIP 1
    SYSTEM "IF exist " + CHR$(34) + dirName$ + CHR$(34) +  " (echo 1 > " + refFile$ + ") ELSE (echo 0 > " + refFile$ + ")"
    OPEN refFile$ FOR INPUT AS #3
    LOCAL res$
    res$ = INPUT$(1, #3)
    CLOSE #3
    dirExists% = (res$ = "1")
  ELSE
    dirExists% = (DIR$(dirName$, DIR) <> "")
  ENDIF
END FUNCTION

'This function checks if given file name already exists or not
FUNCTION fileExists%(fileName$)
  IF MM.DEVICE$ = "DOS" THEN
    'DOS MMBasic does not have a DIR$ function :-(
    ON ERROR SKIP 1
    SYSTEM "DIR /a:-d /b " + CHR$(34) + fileName$ + CHR$(34) + "> " + refFile$ 
    OPEN refFile$ FOR INPUT AS #3
    LOCAL line$
    LINE INPUT #3, line$
    CLOSE #3
    fileExists% = (line$ <> "")
  ELSE
    fileExists% = (DIR$(fileName$, FILE) <> "")
  ENDIF
END FUNCTION

'This function starts an iteration over all sub directories in the current directory.
FUNCTION listDirs$()
  IF MM.DEVICE$ = "DOS" THEN
    'DOS MMBasic does not have a DIR$ function :-(
    ON ERROR SKIP 1 'Needed to absorb "failures" such as File Not Found.
    SYSTEM "DIR /a:d /b > " + refFile$
    OPEN refFile$ FOR INPUT AS #3
    dirListIdx%=0
    LOCAL line$
    DO WHILE NOT EOF(#3)
      LINE INPUT #3, line$
      dirList$(dirListIdx%) = line$
      dirListIdx% = dirListIdx% + 1
    LOOP
    'Fill remainder of dirList with empty.
    DO WHILE dirListIdx% <= MAX_NUM_DIRS%
      dirList$(dirListIdx%) = ""
      dirListIdx% = dirListIdx% + 1
    LOOP
    CLOSE #3

    'Reset index into array
    dirListIdx% = 0
    'Return first item
    listDirs$ = nextDir$()
  ELSE
    'It can be so easy...
    listDirs$ = DIR$("*", DIR)
  ENDIF 
END FUNCTION

'This function starts an iteration over all files in the current directory.
FUNCTION listFiles$()
  IF MM.DEVICE$ = "DOS" THEN
    ON ERROR SKIP 1 'Needed to absorb "failures" such as File Not Found.
    SYSTEM "DIR /a:-d /b > " + refFile$
    OPEN refFile$ FOR INPUT AS #3
    fileListIdx%=0
    LOCAL line$
    DO WHILE NOT EOF(#3)
      LINE INPUT #3, line$
      fileList$(fileListIdx%) = line$
      fileListIdx% = fileListIdx% + 1
    LOOP
    'Fill remainder of fileList with empty.
    DO WHILE fileListIdx% <= MAX_NUM_FILES%
      fileList$(fileListIdx%) = ""
      fileListIdx% = fileListIdx% + 1
    LOOP
    CLOSE #3

    'Reset index into array
    fileListIdx% = 0
    'Return first item
    listFiles$ = nextFile$()
  ELSE
    'It can be so easy...
    listFiles$ = DIR$("*.*", FILE)
  ENDIF
END FUNCTION

'Returns next directory in the iteration.
FUNCTION nextDir$()
  IF MM.DEVICE$ = "DOS" THEN
    LOCAL exitLoop% = 0
    LOCAL line$
    DO WHILE exitLoop% = 0
      line$ = dirList$(dirListIdx%)
      SELECT CASE line$
        CASE "." 'Filter out current directory entry.
          dirListIdx% = dirListIdx% + 1
        CASE ".." 'Filter out up directory entry'
          dirListIdx% = dirListIdx% + 1
        CASE "" 'Exit when we reach an empty string.
          exitLoop% = 1
        CASE ELSE 'Exit when we reach a regular entry, but also advance the index.
          exitLoop% = 1
          dirListIdx% = dirListIdx% + 1
      END SELECT  
    LOOP

    IF dirListIdx% >= MAX_NUM_DIRS% THEN
      PRINT "Max. num. dirs exceeded. Aborting..."
      errno% = 1
      EXIT FUNCTION
    ENDIF

    nextDir$ = line$
  ELSE
    nextDir$ = DIR$()
  ENDIF
END FUNCTION

'Returns next file in the iteration.
FUNCTION nextFile$()
  IF MM.DEVICE$ = "DOS" THEN
    LOCAL exitLoop% = 0
    LOCAL line$
    DO WHILE exitLoop% = 0
      line$ = fileList$(fileListIdx%)
      SELECT CASE line$
        CASE "" 'Exit when we reach an empty string.
          exitLoop% = 1
        CASE ELSE 'Exit when we reach a regular entry, but also advance the index.
          exitLoop% = 1
          fileListIdx% = fileListIdx% + 1
      END SELECT  
    LOOP

    IF fileListIdx% >= MAX_NUM_FILES% THEN
      PRINT "Max. num. files exceeded. Aborting..."
      errno% = 1
      EXIT FUNCTION
    ENDIF

    nextFile$ = line$
  ELSE
    nextFile$ = DIR$()
  ENDIF
END FUNCTION

'This subroutine extracts the contents of one file from the archive.
SUB processFile(fileToProcess$)
  LOCAL fileToProcess_l$ = fileToProcess$
  LOCAL line$

  PRINT SPACE$(recursionLevel%*2) "Processing file " fileToProcess_l$

  'Refuse to overwrite existing files/dirs.
  IF (fileExists%(fileToProcess_l$) <> 0) OR (dirExists%(fileToProcess_l$) <> 0) THEN
    PRINT "File or directory already exists: " fileToProcess_l$
    PRINT "Aborting..."
    errno% = 1
    EXIT SUB
  ENDIF

  OPEN fileToProcess_l$ FOR OUTPUT AS #2
  
  LINE INPUT #1, line$

  LOCAL fileLen% = VAL(line$)
  LOCAL chunkLen% = 0, inFileLoc% = 0
  LOCAL chunk$

  'Extract contents, chunk by chunk.
  DO WHILE inFileLoc% < fileLen%
    chunkLen% = MIN(fileLen%-inFileLoc%, MAX_CHUNK_SIZE%)  
    inFileLoc% = inFileLoc% + chunkLen%
    chunk$ = INPUT$(chunkLen%, #1)
    PRINT #2, chunk$; 'Write to file by printing, without newlines at the end.

    IF EOF(#1) THEN
      PRINT "Invalid archive. Aborting..."
      errno%=2
      EXIT SUB
    ENDIF
  LOOP

  CLOSE #2
END SUB

'This subroutine creates a new directory relative to CWD, then navigates into the new directory.
SUB processDir(dirToProcess$)
  recursionLevel% = recursionLevel% + 1

  LOCAL dirToProcess_l$ = dirToProcess$

  PRINT SPACE$(recursionLevel%*2) "mkdir " dirToProcess_l$

  'Refuse to overwrite existing entries.
  IF (fileExists%(dirToProcess_l$) <> 0) OR (dirExists%(dirToProcess_l$) <> 0) THEN
    PRINT "File or directory already exists: " dirToProcess_l$
    PRINT "Aborting"...
    errno% = 3
    EXIT SUB
  ENDIF

  MKDIR dirToProcess_l$
  CHDIR dirToProcess_l$
  recursionLevel% = recursionLevel% - 1
END SUB

'The counterpart of the previous subroutine. Just move up one directory level.
SUB processEndDir
  CHDIR ".."
END SUB

'This is the heart of the archive extraction routine. The routine iterates loops over the full contents of the archive.
SUB readFromArchive
  CONST DIR_PREFIX$ = "DIR:"
  CONST FILE_PREFIX$ = "FILE:"
  CONST ENDDIR_PREFIX$ = "ENDDIR:"
  CONST ENDARCHIVE_PREFIX$ = "ENDARCHIVE:"

  LOCAL line$, entryName$

  DO WHILE NOT EOF(#1)
    LINE INPUT #1, line$

    SELECT CASE LEFT$(line$, INSTR(line$, ":")) 
      CASE DIR_PREFIX$
        'Extra -1 for space between prefix and actually dir name string
        entryName$ = RIGHT$(line$, LEN(line$)-LEN(DIR_PREFIX$)-1) 
        IF entryName$ = "" THEN
          PRINT "Invalid archive. Aborting..."
          errno%=4
          EXIT SUB
        ENDIF

        processDir entryName$
        IF errno% <> 0 THEN
          EXIT SUB
        ENDIF

      CASE FILE_PREFIX$
        'Extra -1 for space between prefix and actually file name string
        entryName$ = RIGHT$(line$, LEN(line$)-LEN(FILE_PREFIX$)-1) 
        IF entryName$ = "" THEN
          PRINT "Invalid archive. Aborting..."
          errno=5
          EXIT SUB
        ENDIF

        processFile entryName$
        IF errno% <> 0 THEN
          EXIT SUB
        ENDIF

      CASE ENDDIR_PREFIX$:
        processEndDir

      CASE ENDARCHIVE_PREFIX$:
        PRINT "End of archive reached."
        EXIT SUB

      CASE ELSE
        PRINT "Invalid archive. Aborting..."
        errno%=6
        EXIT SUB

      END SELECT
  LOOP
END SUB
