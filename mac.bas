OPTION EXPLICIT
OPTION DEFAULT NONE
OPTION BASE 0

CONST MAX_CHUNK_SIZE% = 128
CONST VERSION$ = "0.3"

'DOS specific constants and variables'
IF MM.DEVICE$ = "DOS" THEN
  CONST MAX_NUM_DIRS%=100
  CONST MAX_NUM_FILES%=400

  DIM refFile$ = CWD$ + "\ntsh.temp"
  DIM refFileQuoted$ = CHR$(34) + refFile$ + CHR$(34)

  DIM dirList$(MAX_NUM_DIRS%)
  DIM fileList$(MAX_NUM_FILES%)
  DIM dirListIdx%, fileListIdx%
ENDIF

DIM dirToArchive$
DIM recursionLevel% = 0
DIM errno% = 0
DIM cmdLine$

PRINT "Create Maximite Archive " VERSION$ " by Epsilon"

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

'Allow to pass in directory to archive as command line argument
IF (cmdLine$ = "") THEN
  INPUT "Directory to archive"; dirToArchive$
ELSE
  dirToArchive$ = cmdLine$
ENDIF

IF dirExists%(dirToArchive$) = 0 THEN
  PRINT "Directory not found. Aborting..."
  GOTO EndOfProg
ENDIF

DIM outFile$ = dirToArchive$+".mar"

OPEN outFile$ FOR OUTPUT AS #2

'This is the actual entry point into the archiving logic.
processDir dirToArchive$

PRINT #2, "ENDARCHIVE:"
CLOSE #2
PRINT "Done."

EndOfProg:
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
  SYSTEM "DEL " + refFileQuoted$
  QUIT
ENDIF

'This function checks if given directory name already exists or not
FUNCTION dirExists%(dirName$)
  IF MM.DEVICE$ = "DOS" THEN
    'DOS MMBasic does not have a DIR$ function :-(
    ON ERROR SKIP 1
    SYSTEM "IF exist " + CHR$(34) + dirName$ + CHR$(34) +  " (echo 1 > " + refFileQuoted$ + ") ELSE (echo 0 > " + refFileQuoted$ + ")"
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
    SYSTEM "DIR /a:-d /b " + CHR$(34) + fileName$ + CHR$(34) + "> " + refFileQuoted$ 
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
    ON ERROR SKIP 1
    SYSTEM "DIR /a:d /b > " + refFileQuoted$
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
    'DOS MMBasic does not have a DIR$ function :-(
    ON ERROR SKIP 1
    SYSTEM "DIR /a:-d /b > " + refFileQuoted$
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
        CASE "."
          dirListIdx% = dirListIdx% + 1
        CASE ".."
          dirListIdx% = dirListIdx% + 1
        CASE ""
          exitLoop% = 1
        CASE ELSE
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
        CASE "."
          fileListIdx% = fileListIdx% + 1
        CASE ".."
          fileListIdx% = fileListIdx% + 1
        CASE ""
          exitLoop% = 1
        CASE ELSE
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

'This subroutine processes the contents of given file to add to the archive.
SUB processFile(fileToProcess$)
  LOCAL filetoProcess_l$ = fileToProcess$

  PRINT SPACE$(recursionLevel%*2) "Processing file " fileToProcess_l$

  'Header
  PRINT #2, "FILE: " fileToProcess_l$
  OPEN fileToProcess_l$ FOR INPUT AS #1

  PRINT #2, LOF(#1)

  LOCAL chunkLen% = 0, inFileLoc% = 0
  LOCAL chunk$
 
  'Contents
  DO WHILE NOT EOF(#1)
    chunkLen% = MIN(LOF(#1)-inFileLoc%, MAX_CHUNK_SIZE%)  
    inFileLoc% = inFileLoc% + chunkLen%
    chunk$ = INPUT$(chunkLen%, #1)
    PRINT #2, chunk$;
  LOOP

  CLOSE #1
END SUB

'This subroutine processes the contents of given directory to add to the archive.
SUB processDir(dirToProcess$)
  recursionLevel% = recursionLevel% + 1

  LOCAL dirToProcess_l$ = dirToProcess$

  PRINT SPACE$(recursionLevel%*2) "Processing dir " dirToProcess_l$

  PRINT #2, "DIR: " dirToProcess_l$

  CHDIR dirToProcess_l$

  'Process the files
  LOCAL fileToProcess$ = listFiles$()

  DO WHILE fileToProcess$ <> ""
    processFile fileToProcess$
    fileToProcess$ = nextFile$()
    IF errno% <> 0 THEN
      GOTO EndOfProg
    ENDIF
  LOOP

  'Process the subdirs  
  LOCAL subDir$ = listDirs$()

  'DIR$/nextDir$ can't handle recursion in this while loop so we have to build a subDir list  
  LOCAL numSubDirs% = 0

  'First calculate how many subdirs there are in this directory
  DO WHILE subDir$ <> ""
    numSubDirs% = numSubDirs% + 1
    subDir$ = nextDir$()
    IF errno% <> 0 THEN
      GOTO EndOfProg
    ENDIF
  LOOP

  IF numSubDirs% >= 1 THEN
    'Note: The size of this array is too big by 1 entry
    LOCAL subDirList$(numSubDirs%)

    subDir$ = listDirs$()
    LOCAL listIdx% = 0

    DO WHILE subDir$ <> ""
      subDirList$(listIdx%) = subDir$
      subDir$ = nextDir$()
      IF errno% <> 0 THEN
        GOTO EndOfProg
      ENDIF
      listIdx% = listIdx% + 1
    LOOP  

    'Now we recurse. For some reason this doesn't work with a while loop, 
    'but with a for loop it works just fine.
    FOR listIdx%=0 TO numSubDirs%-1
      processDir subDirList$(listIdx%)
    NEXT listIdx%
  ENDIF

  PRINT #2, "ENDDIR: " dirToProcess_l$
  CHDIR ".."
  recursionLevel% = recursionLevel% - 1
END SUB
