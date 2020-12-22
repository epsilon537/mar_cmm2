OPTION EXPLICIT
OPTION DEFAULT NONE
OPTION BASE 0

CONST VERSION$ = "0.4"
CONST MAX_CHUNK_SIZE% = 128
CONST MAX_NUM_CMDLINE_ARGS% = 20

'ratio vs. speed constant
'the larger this constant, the better the compression
CONST MAXCOMPARES% = 75

'unused entry flag
CONST NIL% = &HFFFF

'bits per symbol- normally 8 for general purpose compression
CONST CHARBITS% = 8

'minimum match length & maximum match length
CONST THRESHOLD% = 2
CONST MATCHBITS% = 4
CONST MAXMATCH% = (1<<MATCHBITS%)+THRESHOLD%-1

'sliding dictionary size and hash table's size
'some combinations of HASHBITS and THRESHOLD values will not work
'correctly because of the way this program hashes strings
CONST DICTBITS% = 13
CONST HASHBITS% = 10
CONST DICTSIZE% = 1<<DICTBITS%
CONST HASHSIZE% = 1<<HASHBITS%

'# bits to shift after each XOR hash
'this constant must be high enough so that only THRESHOLD + 1
'characters are in the hash accumulator at one time
CONST SHIFTBITS% = (HASHBITS%+THRESHOLD%)\(THRESHOLD%+1)

'sector size constants
CONST SECTORBIT% = 10
CONST SECTORLEN% = 1<<SECTORBIT%
CONST HASHFLAG1% = &H8000
CONST HASHFLAG2% = &H7FFF

DIM dirToArchive$
DIM recursionLevel% = 0
DIM errCode% = 0
DIM cmdLine$
DIM archiveName$
DIM startDir$ = CWD$
DIM cmdLineArgs$(MAX_NUM_CMDLINE_ARGS%)
DIM nArgs%

'dictionary plus MAXMATCH extra chars for string comparisions
DIM dict%((DICTSIZE%+MAXMATCH%+7)\8)
LONGSTRING RESIZE dict%(), (DICTSIZE%+MAXMATCH%-1)

'hashtable & link list tables
DIM hash%(HASHSIZE%)
DIM nextlink%(DICTSIZE%)
DIM lastlink%(DICTSIZE%)

'misc. global variables
DIM matchlength%, matchpos%, bitbuf%, bitsin%
DIM masks%(16) = (0,1,3,7,15,31,63,127,255,511,1023,2047,4095,8191, 16383, 32767, 65535)

'A flag indicating whether to prompt before overwriting, or to just go ahead.
DIM overwriteAll% = 0

PRINT "CMM2 MAR archiver V"+VERSION$+" by Epsilon"

parseCmdLine(MM.CMDLINE$, cmdLineArgs$(), nArgs%)

IF nArgs%<> 2 THEN
  usage
  GOTO endProg
ENDIF

DIM action$ = UCASE$(cmdLineArgs$(0))
IF (action$ <> "C") AND (action$ <> "X") AND (action$ <> "CZ") AND (action$ <> "XZ") THEN
  usage
  GOTO endProg
ENDIF

IF (action$="C") OR (action$="CZ") THEN
  dirToArchive$ = cmdLineArgs$(1)

  MAR_archive(dirToArchive$)
  
  IF action$ = "CZ" THEN
    LZ1_Encode(dirToArchive$+".mar", dirToArchive$+".mz1")
    
    PRINT "Deleting intermediate MAR: "+dirToArchive$+".mar"
    KILL dirToArchive$+".mar"
  ENDIF
ELSE
  DIM inFilename$ = cmdLineArgs$(1)
  DIM outFilename$
  DIM delIntermediateMar% = 0
     
  IF DIR$(inFilename$, FILE) = "" THEN
    usage
    GOTO endProg
  ENDIF

  IF action$="XZ" THEN
    outFilename$ = inFilename$+".mar"
    PRINT "LZ1 decoding "+inFilename$+" to "+outFilename$
    LZ1_Decode(inFilename$, outFilename$)
    inFilename$ = outFilename$
    delIntermediateMar% = 1
  ENDIF

  MAR_extract(inFilename$)

  IF delIntermediateMar% THEN
    PRINT "Deleting intermediate MAR: "+inFilename$
    KILL inFilename$
  ENDIF
ENDIF

PRINT "Done."

endProg:
IF errCode% <> 0 THEN
  PRINT "errCode=" errCode%
ENDIF

ON ERROR SKIP 1
CLOSE #1

ON ERROR SKIP 1
CLOSE #2

ON ERROR SKIP 1
CLOSE #3

SUB MAR_archive(dirToArchive$)
  IF DIR$(dirToArchive$, DIR) = "" THEN
    usage
    GOTO endProg
  ENDIF

  PRINT "Archiving "+dirToArchive$+" to "+dirToArchive$+".mar"
  OPEN dirToArchive$+".mar" FOR OUTPUT AS #2
  
  archiveDir(dirToArchive$)
  
  PRINT #2, "ENDARCHIVE:"
  CLOSE #2
END SUB

SUB MAR_extract(inFilename$)
  PRINT "Extracting archive "+inFilename$
    
  OPEN inFilename$ FOR INPUT AS #1
  
  readFromArchive
    
  CHDIR startDir$
  IF errCode% <> 0 THEN
    GOTO endProg
  ENDIF
  
  CLOSE #1
END SUB

'This function checks if given directory name already exists or not
FUNCTION dirExists%(dirName$)
  dirExists% = (DIR$(dirName$, DIR) <> "")
END FUNCTION

'This function checks if given file name already exists or not
FUNCTION fileExists%(fileName$)
  fileExists% = (DIR$(fileName$, FILE) <> "")
END FUNCTION

'This function starts an iteration over all sub directories in the current directory.
FUNCTION listDirs$()
  'It can be so easy...
  listDirs$ = DIR$("*", DIR)
END FUNCTION

'This function starts an iteration over all files in the current directory.
FUNCTION listFiles$()
  listFiles$ = DIR$("*.*", FILE)
END FUNCTION

'Returns next directory in the iteration.
FUNCTION nextDir$()
  nextDir$ = DIR$()
END FUNCTION

'Returns next file in the iteration.
FUNCTION nextFile$()
  nextFile$ = DIR$()
END FUNCTION

'This subroutine extracts the contents of one file from the archive.
SUB extractFile(fileToProcess$)
  LOCAL fileToProcess_l$ = fileToProcess$
  LOCAL line$

  PRINT SPACE$(recursionLevel%*2) "Processing file " fileToProcess_l$

  'Refuse to overwrite existing files/dirs.
  IF (NOT overwriteAll%) AND (fileExists%(fileToProcess_l$) OR dirExists%(fileToProcess_l$)) THEN
    PRINT "File or directory already exists: " CWD$+"/"+fileToProcess_l$
    LOCAL yesNoAll$
    INPUT "Overwrite? (Y)es/(N)o/(A)ll"; yesNoAll$
    SELECT CASE UCASE$(yesNoAll$)
      CASE "A"
        overwriteAll%=1
      CASE "Y"
      CASE ELSE
        PRINT "Aborting..."
        errCode% = 1
        EXIT SUB
    END SELECT
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
      errCode%=2
      EXIT SUB
    ENDIF
  LOOP

  CLOSE #2
END SUB

'This subroutine creates a new directory relative to CWD, then navigates into the new directory.
SUB extractDir(dirToProcess$)
  recursionLevel% = recursionLevel% + 1

  LOCAL dirToProcess_l$ = dirToProcess$

  PRINT SPACE$(recursionLevel%*2) "mkdir " dirToProcess_l$

  ON ERROR SKIP 1
  MKDIR dirToProcess_l$
  CHDIR dirToProcess_l$
  recursionLevel% = recursionLevel% - 1
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
          errCode%=4
          EXIT SUB
        ENDIF

        extractDir entryName$
        IF errCode% <> 0 THEN
          EXIT SUB
        ENDIF

      CASE FILE_PREFIX$
        'Extra -1 for space between prefix and actually file name string
        entryName$ = RIGHT$(line$, LEN(line$)-LEN(FILE_PREFIX$)-1) 
        IF entryName$ = "" THEN
          PRINT "Invalid archive. Aborting..."
          errCode=5
          EXIT SUB
        ENDIF

        extractFile entryName$
        IF errCode% <> 0 THEN
          EXIT SUB
        ENDIF

      CASE ENDDIR_PREFIX$:
        extractEndDir

      CASE ENDARCHIVE_PREFIX$:
        PRINT "End of archive reached."
        EXIT SUB

      CASE ELSE
        PRINT "Invalid archive. Aborting..."
        errCode%=6
        EXIT SUB

      END SELECT
  LOOP
END SUB

'The counterpart of the previous subroutine. Just move up one directory level.
SUB extractEndDir
  CHDIR ".."
END SUB

'This subroutine processes the contents of given file to add to the archive.
SUB archiveFile(fileToProcess$)
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
SUB archiveDir(dirToProcess$)
  recursionLevel% = recursionLevel% + 1

  LOCAL dirToProcess_l$ = dirToProcess$

  PRINT SPACE$(recursionLevel%*2) "Processing dir " dirToProcess_l$

  PRINT #2, "DIR: " dirToProcess_l$

  CHDIR dirToProcess_l$

  'Process the files
  LOCAL fileToProcess$ = listFiles$()

  DO WHILE fileToProcess$ <> ""
    archiveFile fileToProcess$
    fileToProcess$ = nextFile$()
    IF errCode% <> 0 THEN
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
    IF errCode% <> 0 THEN
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
      IF errCode% <> 0 THEN
        GOTO EndOfProg
      ENDIF
      listIdx% = listIdx% + 1
    LOOP  

    'Now we recurse. For some reason this doesn't work with a while loop, 
    'but with a for loop it works just fine.
    FOR listIdx%=0 TO numSubDirs%-1
      archiveDir subDirList$(listIdx%)
    NEXT listIdx%
  ENDIF

  PRINT #2, "ENDDIR: " dirToProcess_l$
  CHDIR ".."
  recursionLevel% = recursionLevel% - 1
END SUB

SUB parseCmdLine(cmdLine$, cmdLineArgs$(), nArgs%)
  LOCAL curPos%=1, startPos%
  LOCAL inWhiteSpace%=1
  LOCAL curArg%=0
  
  DO WHILE (curPos%<=LEN(cmdLine$)) AND (curArg%<MAX_NUM_CMDLINE_ARGS%)
    IF inWhiteSpace% THEN
      IF MID$(cmdLine$, curPos%, 1) <> " " THEN
        startPos% = curPos%
        inWhiteSpace% = 0
      ENDIF
    ELSE
      IF MID$(cmdLine$, curPos%, 1) = " " THEN
        cmdLineArgs$(curArg%) = MID$(cmdLine$, startPos%, curPos%-startPos%)
        INC curArg%
        inWhiteSpace% = 1
      ENDIF
    ENDIF
    INC curPos%
  LOOP
  
  IF (inWhiteSpace%=0) AND (curArg% < MAX_NUM_CMDLINE_ARGS%) THEN
    cmdLineArgs$(curArg%) = MID$(cmdLine$, startPos%)
    INC curArg%
  ENDIF
  
  nArgs% = curArg%
END SUB

SUB usage
  PRINT "*mar c <dir> : archive directory <dir> into file <dir>.mar"
  PRINT "*mar cz <dir> : archive and lz1 compress directory <dir> into file <dir>.mz1"
  PRINT "*mar x <archive>.mar : extract <archive>.mar archive"
  PRINT "*mar xz <archive>.mz1 : extract <archive>.mz1 compressed archive"
END SUB

'Simple Hashing LZ77 Sliding Dictionary Compression Program    
'By Rich Geldreich, Jr. October, 1993                          
'Originally compiled with QuickC v2.5 in the small model.      
'This program uses more efficient code to delete strings from  
'the sliding dictionary compared to PROG1.C, at the expense of 
'greater memory requirements. See the HashData and DeleteData  
'subroutines.                                                 
'
'Ported to CMM2/MMBasic by Epsilon.

'--> CSUBs
'void dictMove(long long *top, long long *fromp, long long *maskp, long long *nump, char *dict)
'{
'  long long i = *top;
'  long long j = *fromp;
'  long long mask = *maskp;
'  long long k = *nump;
'
'  dict += sizeof(long long);
'
'  do
'  {
'    dict[i++] = dict[j++];
'    j &= mask;
'  }
'  while (--k);
'
'  *top = i;
'  *fromp = j;
'}
CSUB dictMove INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
  00000000
  4FF0E92D F8D3B083 F8D0B000 F8DD9000 685BC030 0507F109 0707F10C A004F8D0 
  44659301 E9D1445F 444F3400 8E00E9D2 44631C5E F1447A1A EA080400 F8050306 
  42BD2F01 0404EA0E EB19D1F2 9D01020B 0505EB4A 2500E9C0 3400E9C1 E8BDB003 
  BF008FF0 
End CSUB

'/* finds match for string at position dictpos     */
'/* this search code finds the longest AND closest */
'/* match for the string at dictpos                */
'void FindMatch(long long *matchlengthp, long long *matchposp, char *dict, long long *nextlink, long long *dictposp)
'{
'  long long i, j, k, matchlength;
'  long long dictpos = *dictposp;
'  long long matchpos = *matchposp;
'  char l;
'
'  dict += sizeof(long long);
'
'  i = dictpos; matchlength = THRESHOLD; k = MAXCOMPARES;
'  l = dict[dictpos + matchlength];
'
'  do
'  {
'    if ((i = nextlink[i]) == NIL) break;   /* get next string in list */
'
'    if (dict[i + matchlength] == l)        /* possible larger match? */
'    {
'      for (j = 0; j < MAXMATCH; j++)          /* compare strings */
'        if (dict[dictpos + j] != dict[i + j]) break;
'
'      if (j > matchlength)  /* found larger match? */
'      {
'        matchlength = j;
'        matchpos = i;
'        if (matchlength == MAXMATCH) break;  /* exit if largest possible match */
'        l = dict[dictpos + matchlength];
'      }
'    }
'  }
'  while (--k);  /* keep on trying until we run out of chances */
'
'  *matchlengthp = matchlength;
'  *matchposp = matchpos;
'}
CSUB FindMatch INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
  00000000
  4FF0E92D 468BB089 F1026809 9C120A08 91042700 0802F04F 1004F8DB 91059006 
  B01CF8CD 920346D3 4500E9D4 0104EB0A 469A1DE0 9002F891 464A9000 0900F04F 
  3701E002 D03D2F4B 04C4EB0A F64F2100 E9D470FF 428D4500 4284BF08 EB0BD032 
  44430304 4293781B 9B03D1EB 98001DE6 441E2100 0C00EB03 F81C2000 F816EF01 
  45733F01 3001D112 0100F141 BF082900 D1F22811 0F11F1B8 0300F179 F8DDDAD1 
  E9CDB01C E9CD0100 E00F4504 EB794580 DAC60301 46723701 46894680 E9CD2F4B 
  D1C14504 B01CF8DD 8900E9CD 46199B06 2300E9DD 2300E9C1 F8CB9B04 9B053000 
  3004F8CB E8BDB009 BF008FF0 
End CSUB

'/* hash data just entered into dictionary */
'/* XOR hashing is used here, but practically any hash function will work */
'void HashData(long long *dictposp, long long *bytestodop, long long *nextlink, long long *lastlink, long long *hash, char* dict)
'{
'  long long i, j, k;
'  long long dictpos = *dictposp;
'  long long bytestodo = *bytestodop;
'  
'  dict += sizeof(long long);
'
'  if (bytestodo <= THRESHOLD)   /* not enough bytes in sector for match? */
'    for (i = 0; i < bytestodo; i++)
'      nextlink[dictpos + i] = lastlink[dictpos + i] = NIL;
'  else
'  {
'    /* matches can't cross sector boundries */
'    for (i = bytestodo - THRESHOLD; i < bytestodo; i++)
'      nextlink[dictpos + i] = lastlink[dictpos + i] = NIL;
'
'    j = (((long long)dict[dictpos]) << SHIFTBITS) ^ dict[dictpos + 1];
'
'    k = dictpos + bytestodo - THRESHOLD;  /* calculate end of sector */
'
'    for (i = dictpos; i < k; i++)
'    {
'      lastlink[i] = (j = (((j << SHIFTBITS) & (HASHSIZE - 1)) ^ dict[i + THRESHOLD])) | HASHFLAG1;
'      if ((nextlink[i] = hash[j]) != NIL) lastlink[nextlink[i]] = i;
'      hash[j] = i;
'    }
'  }
'}
CSUB HashData INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER
  00000000
  4FF0E92D B0874698 3400E9D1 5600E9D0 46182B03 B040F8DD 3402E9CD 0300F174 
  5600E9CD 2801DA17 0300F174 4603DB10 01C5EB08 02C5EB02 76FFF64F 2700442B 
  08C3EB08 6702E8E1 E8E24588 D1F96702 E8BDB007 E9DD8FF0 E9DD9A02 99114500 
  0C02F1B9 F1199803 F10133FF EB140608 99010909 F64F44A4 441C7EFF 0A00EB41 
  0102F1B9 0300F04F 07CCEB08 05CCEB02 F8C79104 EB08E000 607B0CC4 04C4EB02 
  0100E9DD E300E9C5 EB064607 F14A0500 F8CC31FF F8CCE000 91053004 E300E9C4 
  786C5DF6 0104E9DD 1406EA84 5600E9DD EB764285 DABB0101 F1059900 46765C00 
  F101461F 99110E09 3CFFF10C 448E1DCD EB0244A9 EB0805CC E9DD0CCC 01240100 
  2F01F81E F3C42300 40540409 2300E9CD 0AC4EB0B 4200F444 F84C9B01 F8CC2F08 
  E9DA3004 42BB2300 2302E9E5 42B2BF08 02C2EB08 E9C2BF18 E9CA0100 30010100 
  0100F141 D1DA45CE E8BDB007 BF008FF0 
End CSUB
'<-- CSUBs

SUB LZ1_Encode(inFilename$, outFilename$)
  PRINT "Compressing "+inFilename$+" to "+outFilename$

  OPEN inFilename$ FOR INPUT AS #1  
  OPEN outFilename$ FOR OUTPUT AS #2
  
  compress
  
  CLOSE #1
  CLOSE #2
  
  PRINT
END SUB

SUB LZ1_Decode(inFilename$, outFilename$)
  OPEN inFilename$ FOR INPUT AS #1
  OPEN outFilename$ FOR OUTPUT AS #2

  decompress()
  
  CLOSE #1
  CLOSE #2
  
  PRINT
END SUB

'writes multiple bit codes to the output stream
SUB SendBits(bits%, numbits%)
  bitbuf% = bitbuf% OR (bits% << bitsin%)
  INC bitsin%, numbits%
  
  IF bitsin% > 16 THEN ' special case when # bits in buffer exceeds 16
    PRINT #2, CHR$(bitbuf% AND &HFF);
    bitbuf% = bits% >> (8-(bitsin%-numbits%))
    INC bitsin%, -8
  ENDIF
  
  DO WHILE bitsin%>= 8
    PRINT #2, CHR$(bitbuf% AND &HFF);
    bitbuf% = bitbuf%>>8
    INC bitsin%, -8
  LOOP
END SUB

' reads multiple bit codes from the input stream
FUNCTION ReadBits%(numbits%)
  LOCAL i% = bitbuf% >> (8-bitsin%)
  
  DO WHILE numbits% > bitsin%
    bitbuf% = ASC(INPUT$(1,#1))    
    i% =i% OR (bitbuf% << bitsin%)
    INC bitsin%, 8
  LOOP
  
  INC bitsin%, -numbits%
  
  ReadBits% = i% AND masks%(numbits%)
END FUNCTION

' sends a match to the output stream
SUB SendMatch(matchlen%, matchdistance%)
  SendBits 1, 1
  SendBits matchlen% - (THRESHOLD% + 1), MATCHBITS%
  SendBits matchdistance%, DICTBITS%
END SUB

' sends one character (or literal) to the output stream
SUB SendChar(character%)
  SendBits 0, 1
  SendBits character%, CHARBITS%
END SUB

' initializes the search structures needed for compression
SUB InitEncode
  LOCAL i%
  
  FOR i%=0 TO (HASHSIZE%-1)
    hash%(i%) = NIL%
  NEXT i%
  
  nextlink%(DICTSIZE%) = NIL%
END SUB

' loads dictionary with characters from the input stream
FUNCTION LoadDict%(dictpos%)
  LOCAL i%, j%
  i% = readNbytes%(dict%(), dictpos%, SECTORLEN%)
  
  ' since the dictionary is a ring buffer, copy the characters at
  '   the very start of the dictionary to the end
  IF dictpos%=0 THEN
    dictMove(j%+DICTSIZE%, j%, INV 0, (MAXMATCH%-1), dict%(0))          
  ENDIF
  
  LoadDict%=i%
END FUNCTION

'deletes data from the dictionary search structures 
'this is only done when the number of bytes to be   
'compressed exceeds the dictionary's size           
SUB DeleteData(dictpos%)
  LOCAL i%, j%, k%
  
  ' delete all references to the sector being deleted
  k% = dictpos% + SECTORLEN%
  
  i%=dictpos%
  DO WHILE i% < k%
    j% = lastlink%(i%)
    IF (j% AND HASHFLAG1) <> 0 THEN
      IF (j% <> NIL%) THEN
        hash%(j% AND HASHFLAG2%) = NIL%
      ENDIF
    ELSE
      nextlink%(j%) = NIL%
    ENDIF
    
    INC i%
  LOOP
END SUB

' finds dictionary matches for characters in current sector
SUB DictSearch(dictpos%, bytestodo%)
  LOCAL i%, j%
  
  i%=dictpos%:j%=bytestodo%
  
  DO WHILE j%<>0 'loop while there are still characters left to be compressed
    FindMatch(matchlength%, matchpos%, dict%(0), nextlink%(0), i%)

    IF matchlength% > j% THEN 'clamp matchlength
      matchlength% = j%
    ENDIF
    
    IF matchlength% > THRESHOLD% THEN ' valid match?
      SendMatch(matchlength%, (i%-matchpos%) AND (DICTSIZE%-1))
      INC i%, matchlength%
      INC j%, -matchlength%
    ELSE
      SendChar(LGETBYTE(dict%(), i%))
      INC i%
      INC j%, -1
    ENDIF
  LOOP
END SUB

' main encoder
SUB compress
  LOCAL dictpos%, deleteflag%, sectorlen%
  LOCAL bytescompressed%
  LOCAL inSizeStr$ = STR$(LOF(#1))  
  
  InitEncode
  
  dictpos% = 0
  deleteflag% = 0
  bytescompressed% = 0
  
  DO
    ' delete old data from dictionary
    IF deleteflag% THEN
      DeleteData(dictpos%)
    ENDIF

    'TIMER = 0    
    ' grab more data to compress
    sectorlen% = LoadDict%(dictpos%)
    IF sectorlen%=0 THEN
      EXIT DO
    ENDIF
    'PRINT "L"+STR$(TIMER)

    'TIMER = 0      
    ' hash the data   
    HashData(dictpos%, sectorlen%, nextlink%(0), lastlink%(0), hash%(0), dict%(0))
    'PRINT "H"+STR$(TIMER)

    'TIMER = 0    
    ' find dictionary matches
    DictSearch(dictpos%, sectorlen%)
    'PRINT "D"+STR$(TIMER)
    
    INC bytescompressed%, sectorlen%
    
    PRINT @(0) STR$(bytescompressed%)+"/"+inSizeStr$;
    
    INC dictpos%, SECTORLEN%
    
    ' wrap back to beginning of dictionary when its full
    IF dictpos% = DICTSIZE% THEN
      dictpos% = 0
      deleteflag% = 1 ' ok to delete now
    ENDIF
  LOOP
  
  'Send EOF flag
  SendMatch(MAXMATCH% + 1, 0)
  
  'Flush bit buffer
  IF bitsin% THEN
    SendBits(0, 8-bitsin%)
  ENDIF
END SUB

' main decoder
SUB decompress
  LOCAL i%, j%, k%, inbitCounter%=0
  LOCAL numBytes%
  LOCAL inSizeStr$ = STR$(LOF(#1))  
  i%=0
  
  DO
    INC inbitCounter%
    IF ReadBits%(1) = 0 THEN ' character or match? 
      INC inbitCounter%, 8
      LONGSTRING SETBYTE dict%(), i%, ReadBits%(CHARBITS)
      INC i%
      
      IF i% = DICTSIZE% THEN
        writeNbytes(dict%(), DICTSIZE%)
        i% = 0
      ENDIF
    ELSE
      INC inbitCounter%, MATCHBITS%
      ' get match length from input stream
      k% = (THRESHOLD%+1) + ReadBits%(MATCHBITS%)
      IF k% = (MAXMATCH%+1) THEN ' Check for EOF flag
        writeNbytes(dict%(), i%)
        EXIT DO
      ENDIF
      
      INC inbitCounter%, DICTBITS%
      ' get match position from input stream
      j% = (i% - ReadBits%(DICTBITS%)) AND (DICTSIZE%-1)
      
      IF i%+k% >= DICTSIZE% THEN
        DO
          numBytes% = MIN(DICTSIZE%-i%, k%)          
          dictMove(i%, j%, (DICTSIZE% - 1), numBytes%, dict%(0))
          INC k%, -numBytes%
          IF i% = DICTSIZE% THEN
            writeNbytes(dict%(), DICTSIZE%)
            i% = 0
            PRINT @(0) STR$(inbitCounter%\8)+"/"+inSizeStr$;
          ENDIF
        LOOP UNTIL k%=0
      ELSE
        dictMove(i%, j%, (DICTSIZE% - 1), k%, dict%(0))
      ENDIF
    ENDIF
  LOOP
  PRINT @(0) inSizeStr$+"/"+inSizeStr$
END SUB

SUB writeNbytes(buf%(), nBytes%)
  STATIC tmp%((DICTSIZE%+MAXMATCH%+7)\8)
  LONGSTRING RESIZE tmp%(), nBytes%-1
  LONGSTRING LEFT tmp%(), buf%(), nBytes%
  LONGSTRING PRINT #2, tmp%();
END SUB

SUB writeOneByte(byte%)
  PRINT #2, CHR$(byte%);
END SUB

FUNCTION readNbytes%(buf%(), bufpos%, nBytes%)
  LOCAL bytesRead%=0
  LOCAL inStr$
  
  DO WHILE (bytesRead% < nBytes%) AND (NOT EOF(#1))
    inStr$ = INPUT$(MIN(255, nBytes% - bytesRead%), #1)
    LONGSTRING REPLACE buf%(), inStr$, bufpos%+bytesRead%+1
    INC bytesRead%, LEN(inStr$)
  LOOP
  
  readNbytes% = bytesRead%
END FUNCTION


             