; ==============================================================
;  HANGMAN GAME - x86 Assembly (MASM + Irvine32)
;  EL-2003 COAL Lab Project - Fall 2026
;
;  Muhammad Hassaan Raza   25K-0611  (Group Leader)
;  Muaviyah Bin Arsalan    25K-0905
;  Hashir Ahmed            25K-0753
; ==============================================================

INCLUDE Irvine32.inc

MAX_WORDS    = 100
WORD_SIZE    = 16
MIN_WORD     = 3
MAX_LIVES    = 6
FILE_BUF     = 4096
HIST_READ    = 2000
RECENT_LINES = 5
BAR_LEN      = 20
MENU_COUNT   = 5
STATUS_ROW   = 22

HX = 9
HY = 6

ID_YES_VAL       = 6
MY_GENERIC_WRITE = 40000000h
MY_SHARE_READ    = 1
MY_OPEN_ALWAYS   = 4
MY_ATTR_NORMAL   = 80h
MY_FILE_END      = 2

NORMAL_COLOR = lightGray + (black * 16)

FANCY_UI = 1
IF FANCY_UI
  BOX_TL = 0C9h
  BOX_TR = 0BBh
  BOX_BL = 0C8h
  BOX_BR = 0BCh
  BOX_H  = 0CDh
  BOX_V  = 0BAh
  HEART_CH = 03h
  BLOCK_CH = 0DBh
  SHADE_CH = 0B0h
ELSE
  BOX_TL = '+'
  BOX_TR = '+'
  BOX_BL = '+'
  BOX_BR = '+'
  BOX_H  = '-'
  BOX_V  = '|'
  HEART_CH = 'O'
  BLOCK_CH = '#'
  SHADE_CH = '.'
ENDIF

NL EQU <0Dh, 0Ah>

mPrint MACRO text:REQ
    LOCAL txt
    .data
    txt BYTE text, 0
    .code
    push edx
    mov  edx, OFFSET txt
    call WriteString
    pop  edx
ENDM

mPrintAt MACRO col:REQ, row:REQ, text:REQ
    LOCAL txt
    .data
    txt BYTE text, 0
    .code
    push edx
    mov  dl, col
    mov  dh, row
    call Gotoxy
    mov  edx, OFFSET txt
    call WriteString
    pop  edx
ENDM

mColor MACRO clr:REQ
    push eax
    mov  eax, clr
    call SetTextColor
    pop  eax
ENDM

DrawBox    PROTO, bLeft:DWORD, bTop:DWORD, bWid:DWORD, bHgt:DWORD
CheckGuess PROTO, letter:DWORD
AppendText PROTO, pFile:PTR BYTE, pText:PTR BYTE, nLen:DWORD
DrawBar    PROTO, bVal:DWORD, bTot:DWORD, bClr:DWORD

.data
wordsFile   BYTE "words.txt", 0
statsFile   BYTE "stats.dat", 0
histFile    BYTE "history.txt", 0
fileHandle  DWORD ?
fileBuffer  BYTE FILE_BUF DUP(0)
histBuffer  BYTE HIST_READ + 1 DUP(0)
lineBuf     BYTE 128 DUP(0)
msgBuf      BYTE 256 DUP(0)
inputBuf    BYTE 41 DUP(0)

defaultWords BYTE "COMPUTER", NL, "ASSEMBLY", NL, "REGISTER", NL
             BYTE "PROCEDURE", NL, "KEYBOARD", NL, "MEMORY", NL
             BYTE "PROCESSOR", NL, "COMPILER", NL, "VARIABLE", NL
             BYTE "POINTER", NL, "INTERRUPT", NL, "STACK", NL
             BYTE "BINARY", NL, "HARDWARE", NL, "SOFTWARE", NL
             BYTE "MONITOR", NL, "NETWORK", NL, "ALGORITHM", NL
             BYTE "DEBUGGER", NL, "FUNCTION", NL, "SEGMENT", NL
             BYTE "OPERAND", NL, "MACRO", NL, "INSTRUCTION", NL
             BYTE "HEXADECIMAL", NL, "ACCUMULATOR", NL, "MICROCHIP", NL
             BYTE "DATABASE", NL, "INTERNET", NL, "LIBRARY", NL
             BYTE 0

wordTable   BYTE MAX_WORDS * WORD_SIZE DUP(0)
wordCount   DWORD 0
lastIndex   DWORD -1

secretWord  BYTE WORD_SIZE DUP(0)
maskWord    BYTE WORD_SIZE DUP(0)
wordLen     DWORD 0
lives       DWORD MAX_LIVES
guessed     BYTE 26 DUP(0)
wrongList   BYTE 8 DUP(0)
wrongCount  DWORD 0
roundScore  DWORD 0
roundResult DWORD 0
revealMode  DWORD 0
sessionScore DWORD 0
statusPtr   DWORD OFFSET msgStart
statusColor DWORD yellow

statsBlock  LABEL BYTE
gPlayed     DWORD 0
gWins       DWORD 0
gLosses     DWORD 0
gTotal      DWORD 0
gHigh       DWORD 0
gCurStreak  DWORD 0
gBestStreak DWORD 0
STATS_SIZE = ($ - statsBlock)

menuSel     DWORD 0
menu1       BYTE "  [1]  Play Game             ", 0
menu2       BYTE "  [2]  Dashboard             ", 0
menu3       BYTE "  [3]  Add a New Word        ", 0
menu4       BYTE "  [4]  How to Play           ", 0
menu5       BYTE "  [5]  Exit                  ", 0
menuTable   DWORD menu1, menu2, menu3, menu4, menu5

ban1 BYTE " _   _    _    _   _  ____ __  __    _    _   _ ", 0
ban2 BYTE "| | | |  / \  | \ | |/ ___|  \/  |  / \  | \ | |", 0
ban3 BYTE "| |_| | / _ \ |  \| | |  _| |\/| | / _ \ |  \| |", 0
ban4 BYTE "|  _  |/ ___ \| |\  | |_| | |  | |/ ___ \| |\  |", 0
ban5 BYTE "|_| |_/_/   \_\_| \_|\____|_|  |_/_/   \_\_| \_|", 0
bannerTable DWORD ban1, ban2, ban3, ban4, ban5

msgStart      BYTE "A new word has been chosen. Start guessing!", 0
msgGood       BYTE "Good guess! That letter is in the word.", 0
msgBad        BYTE "Wrong guess - you lost a life.", 0
msgInvalid    BYTE "Please type a letter from A to Z.", 0
msgAlready    BYTE "You already tried that letter - pick another one.", 0
msgWinStatus  BYTE "*** YOU WIN! *** You guessed the word.", 0
msgLoseStatus BYTE "*** GAME OVER *** The hangman is complete.", 0
blankLine     BYTE 74 DUP(' '), 0

capWin    BYTE "Hangman - You Win!", 0
capLose   BYTE "Hangman - Game Over", 0
capQuit   BYTE "Hangman", 0
capReset  BYTE "Reset Statistics", 0
askQuit   BYTE "Leave this round?", NL, "It will not be counted in your statistics.", 0
askReset  BYTE "Delete all saved statistics and game history?", 0
rWin1     BYTE "Congratulations - you guessed it!", 0
rLose1    BYTE "Out of lives - better luck next time.", 0
rWordWas  BYTE NL, NL, "The word was:  ", 0
rRound    BYTE NL, "Round score:   ", 0
rSession  BYTE NL, "Session score: ", 0
rAgain    BYTE NL, NL, "Play another round?", 0

hGame     BYTE "Game #", 0
hWin      BYTE "  WIN    ", 0
hLoss     BYTE "  LOSS   ", 0
hScore    BYTE "Score: ", 0
hLives    BYTE "   Lives left: ", 0

.code
main PROC
    call Randomize
    call LoadWords
    call LoadStats
MainMenu:
    call MenuScreen
    cmp  al, '1'
    je   OptPlay
    cmp  al, '2'
    je   OptDash
    cmp  al, '3'
    je   OptAdd
    cmp  al, '4'
    je   OptHelp
    jmp  OptExit
OptPlay:
    call PlayGame
    jmp  MainMenu
OptDash:
    call Dashboard
    jmp  MainMenu
OptAdd:
    call AddWordScreen
    jmp  MainMenu
OptHelp:
    call HelpScreen
    jmp  MainMenu
OptExit:
    call SaveStats
    call GoodbyeScreen
    exit
main ENDP

MenuScreen PROC USES ebx ecx edx esi
    mColor NORMAL_COLOR
    call Clrscr

    mColor yellow
    mov  esi, OFFSET bannerTable
    mov  ecx, LENGTHOF bannerTable
    mov  bl, 1
MS_Banner:
    mov  dh, bl
    mov  dl, 16
    call Gotoxy
    mov  edx, [esi]
    call WriteString
    add  esi, TYPE bannerTable
    inc  bl
    loop MS_Banner

    mColor lightCyan
    mPrintAt 20, 7, "x86 Assembly Edition  -  MASM + Irvine32"
    mColor lightBlue
    INVOKE DrawBox, 23, 9, 35, 9
    mColor gray
    mPrintAt 18, 19, "UP / DOWN arrows + ENTER to choose   or press 1 to 5"
    mColor lightGray
    mPrintAt 18, 21, "Words loaded: "
    mov  eax, wordCount
    call WriteDec
    mPrintAt 42, 21, "Best round score: "
    mov  eax, gHigh
    call WriteDec
    mColor gray
    mPrintAt 13, 23, "Hassaan 25K-0611  |  Muaviyah 25K-0905  |  Hashir 25K-0754"

MS_Redraw:
    call DrawMenuItems
MS_Key:
    call ReadChar
    cmp  al, 0Dh
    je   MS_Enter
    cmp  al, 1Bh
    je   MS_Esc
    cmp  al, 0
    je   MS_Ext
    cmp  al, 0E0h
    je   MS_Ext
    cmp  al, 'w'
    je   MS_Up
    cmp  al, 's'
    je   MS_Down
    cmp  al, '1'
    jb   MS_Key
    cmp  al, '5'
    ja   MS_Key
    ret
MS_Ext:
    cmp  ah, 48h
    je   MS_Up
    cmp  ah, 50h
    je   MS_Down
    jmp  MS_Key
MS_Up:
    cmp  menuSel, 0
    jne  MS_UpDec
    mov  menuSel, MENU_COUNT
MS_UpDec:
    dec  menuSel
    jmp  MS_Redraw
MS_Down:
    inc  menuSel
    cmp  menuSel, MENU_COUNT
    jb   MS_Redraw
    mov  menuSel, 0
    jmp  MS_Redraw
MS_Enter:
    mov  eax, menuSel
    add  al, '1'
    ret
MS_Esc:
    mov  al, '5'
    ret
MenuScreen ENDP

DrawMenuItems PROC USES eax ebx edx
    mov  ebx, 0
DMI_Loop:
    mov  eax, ebx
    add  eax, 11
    mov  dh, al
    mov  dl, 26
    call Gotoxy
    cmp  ebx, menuSel
    jne  DMI_Plain
    mov  eax, black + (lightCyan * 16)
    jmp  DMI_Set
DMI_Plain:
    mov  eax, white + (black * 16)
DMI_Set:
    call SetTextColor
    mov  edx, menuTable[ebx * TYPE menuTable]
    call WriteString
    inc  ebx
    cmp  ebx, MENU_COUNT
    jb   DMI_Loop
    mColor NORMAL_COLOR
    ret
DrawMenuItems ENDP

DrawBox PROC USES eax ecx edx, bLeft:DWORD, bTop:DWORD, bWid:DWORD, bHgt:DWORD
    LOCAL rightCol:BYTE
    mov  eax, bLeft
    add  eax, bWid
    dec  eax
    mov  rightCol, al
    mov  dl, BYTE PTR bLeft
    mov  dh, BYTE PTR bTop
    call Gotoxy
    mov  al, BOX_TL
    call WriteChar
    mov  ecx, bWid
    sub  ecx, 2
    mov  al, BOX_H
DB_Top:
    call WriteChar
    loop DB_Top
    mov  al, BOX_TR
    call WriteChar
    mov  ecx, bHgt
    sub  ecx, 2
    mov  dh, BYTE PTR bTop
    mov  al, BOX_V
DB_Side:
    inc  dh
    mov  dl, BYTE PTR bLeft
    call Gotoxy
    call WriteChar
    mov  dl, rightCol
    call Gotoxy
    call WriteChar
    loop DB_Side
    inc  dh
    mov  dl, BYTE PTR bLeft
    call Gotoxy
    mov  al, BOX_BL
    call WriteChar
    mov  ecx, bWid
    sub  ecx, 2
    mov  al, BOX_H
DB_Bottom:
    call WriteChar
    loop DB_Bottom
    mov  al, BOX_BR
    call WriteChar
    ret
DrawBox ENDP

PlayGame PROC USES ebx edx
PG_NewRound:
    call PickWord
    call InitRound
    call DrawGameFrame
PG_Loop:
    call UpdateGame
    call ReadGuess
    cmp  eax, 0
    je   PG_Abandon
    INVOKE CheckGuess, eax
    call IsWordComplete
    cmp  eax, 1
    je   PG_Won
    cmp  lives, 0
    je   PG_Lost
    jmp  PG_Loop
PG_Won:
    mov  roundResult, 1
    call RecordWin
    jmp  PG_Over
PG_Lost:
    mov  roundResult, 0
    mov  revealMode, 1
    call RecordLoss
PG_Over:
    call UpdateGame
    call ShowResult
    cmp  eax, ID_YES_VAL
    je   PG_NewRound
    ret
PG_Abandon:
    mov  ebx, OFFSET capQuit
    mov  edx, OFFSET askQuit
    call MsgBoxAsk
    cmp  eax, ID_YES_VAL
    jne  PG_Loop
    ret
PlayGame ENDP

PickWord PROC USES eax ecx edx esi edi
PW_Again:
    mov  eax, wordCount
    call RandomRange
    cmp  wordCount, 1
    jbe  PW_Ok
    cmp  eax, lastIndex
    je   PW_Again
PW_Ok:
    mov  lastIndex, eax
    shl  eax, 4
    lea  esi, wordTable[eax]
    mov  edi, OFFSET secretWord
    mov  ecx, WORD_SIZE
    cld
    rep  movsb
    mov  edx, OFFSET secretWord
    call StrLength
    mov  wordLen, eax
    ret
PickWord ENDP

InitRound PROC USES eax ecx edi
    mov  lives, MAX_LIVES
    mov  wrongCount, 0
    mov  roundScore, 0
    mov  revealMode, 0
    cld
    mov  al, 0
    mov  edi, OFFSET guessed
    mov  ecx, LENGTHOF guessed
    rep  stosb
    mov  edi, OFFSET wrongList
    mov  ecx, LENGTHOF wrongList
    rep  stosb
    mov  edi, OFFSET maskWord
    mov  ecx, wordLen
    mov  al, '_'
    rep  stosb
    mov  BYTE PTR [edi], 0
    mov  statusPtr, OFFSET msgStart
    mov  statusColor, yellow
    ret
InitRound ENDP

ReadGuess PROC USES ebx edx
RG_Key:
    call ReadChar
    cmp  al, 1Bh
    je   RG_Esc
    cmp  al, 'a'
    jb   RG_Upper
    cmp  al, 'z'
    ja   RG_Bad
    and  al, 11011111b
    jmp  RG_Letter
RG_Upper:
    cmp  al, 'A'
    jb   RG_Bad
    cmp  al, 'Z'
    ja   RG_Bad
RG_Letter:
    movzx ebx, al
    sub  ebx, 'A'
    cmp  guessed[ebx], 0
    jne  RG_Repeat
    movzx eax, al
    ret
RG_Bad:
    mov  edx, OFFSET msgInvalid
    mov  eax, yellow
    call ShowStatus
    jmp  RG_Key
RG_Repeat:
    mov  edx, OFFSET msgAlready
    mov  eax, yellow
    call ShowStatus
    jmp  RG_Key
RG_Esc:
    mov  eax, 0
    ret
ReadGuess ENDP

CheckGuess PROC USES ebx ecx edx esi edi, letter:DWORD
    mov  eax, letter
    movzx ebx, al
    sub  ebx, 'A'
    cld
    mov  edi, OFFSET secretWord
    mov  ecx, wordLen
    repne scasb
    jne  CG_Miss
    mov  guessed[ebx], 1
    mov  esi, 0
    mov  ecx, wordLen
CG_Reveal:
    cmp  secretWord[esi], al
    jne  CG_Next
    mov  maskWord[esi], al
    add  roundScore, 10
CG_Next:
    inc  esi
    loop CG_Reveal
    mov  statusPtr, OFFSET msgGood
    mov  statusColor, lightGreen
    ret
CG_Miss:
    mov  guessed[ebx], 2
    dec  lives
    mov  edx, wrongCount
    mov  wrongList[edx], al
    inc  wrongCount
    mov  statusPtr, OFFSET msgBad
    mov  statusColor, lightRed
    ret
CheckGuess ENDP

IsWordComplete PROC USES ecx edi
    cld
    mov  edi, OFFSET maskWord
    mov  ecx, wordLen
    mov  al, '_'
    repne scasb
    je   IWC_No
    mov  eax, 1
    ret
IWC_No:
    mov  eax, 0
    ret
IsWordComplete ENDP

RecordWin PROC USES eax ebx edx
    mov  eax, lives
    mov  ebx, 20
    mul  ebx
    add  eax, 50
    add  roundScore, eax
    inc  gPlayed
    inc  gWins
    inc  gCurStreak
    mov  eax, gCurStreak
    cmp  eax, gBestStreak
    jbe  RW_Keep
    mov  gBestStreak, eax
RW_Keep:
    call AddRoundScore
    mov  statusPtr, OFFSET msgWinStatus
    mov  statusColor, lightGreen
    call SaveStats
    call LogHistory
    ret
RecordWin ENDP

RecordLoss PROC
    inc  gPlayed
    inc  gLosses
    mov  gCurStreak, 0
    call AddRoundScore
    mov  statusPtr, OFFSET msgLoseStatus
    mov  statusColor, lightRed
    call SaveStats
    call LogHistory
    ret
RecordLoss ENDP

AddRoundScore PROC USES eax
    mov  eax, roundScore
    add  gTotal, eax
    add  sessionScore, eax
    cmp  eax, gHigh
    jbe  ARS_Done
    mov  gHigh, eax
ARS_Done:
    ret
AddRoundScore ENDP

ShowResult PROC USES ebx ecx edx esi edi
    cld
    mov  edi, OFFSET msgBuf
    mov  esi, OFFSET rWin1
    cmp  roundResult, 1
    je   SR_Head
    mov  esi, OFFSET rLose1
SR_Head:
    call CopyStr
    mov  esi, OFFSET rWordWas
    call CopyStr
    mov  esi, OFFSET secretWord
    call CopyStr
    mov  esi, OFFSET rRound
    call CopyStr
    mov  eax, roundScore
    call NumToStr
    mov  esi, OFFSET rSession
    call CopyStr
    mov  eax, sessionScore
    call NumToStr
    mov  esi, OFFSET rAgain
    call CopyStr
    mov  BYTE PTR [edi], 0

    mov  ebx, OFFSET capWin
    cmp  roundResult, 1
    je   SR_Show
    mov  ebx, OFFSET capLose
SR_Show:
    mov  edx, OFFSET msgBuf
    call MsgBoxAsk
    ret
ShowResult ENDP

DrawGameFrame PROC USES eax
    mColor NORMAL_COLOR
    call Clrscr
    mColor lightBlue
    INVOKE DrawBox, 1, 0, 78, 3
    INVOKE DrawBox, 1, 4, 27, 11
    INVOKE DrawBox, 29, 4, 50, 11
    INVOKE DrawBox, 1, 16, 78, 5
    mColor yellow
    mPrintAt 4, 1, "H A N G M A N"
    mColor lightGray
    mPrintAt 30, 1, "Game #"
    mov  eax, gPlayed
    inc  eax
    call WriteDec
    mPrintAt 52, 1, "Session score: "
    mov  eax, sessionScore
    call WriteDec
    mColor lightCyan
    mPrintAt 3, 4, " GALLOWS "
    mPrintAt 31, 4, " SECRET WORD "
    mPrintAt 3, 16, " KEYBOARD "
    mColor gray
    mPrintAt 4, 23, "Type a letter (A-Z) to guess     ESC = back to menu"
    call DrawGallows
    mColor NORMAL_COLOR
    ret
DrawGameFrame ENDP

DrawGallows PROC
    mColor brown
    mPrintAt HX, HY,   "  +-----+"
    mPrintAt HX, HY+1, "  |     |"
    mPrintAt HX, HY+2, "        |"
    mPrintAt HX, HY+3, "        |"
    mPrintAt HX, HY+4, "        |"
    mPrintAt HX, HY+5, "        |"
    mPrintAt HX, HY+6, "==========="
    mColor NORMAL_COLOR
    ret
DrawGallows ENDP

UpdateGame PROC USES eax edx
    call DrawHangman
    call DrawWordPanel
    call DrawKeyboard
    mov  edx, statusPtr
    mov  eax, statusColor
    call ShowStatus
    ret
UpdateGame ENDP

DrawHangman PROC USES eax ebx edx
    mov  ebx, MAX_LIVES
    sub  ebx, lives
    mColor lightRed
    cmp  ebx, 1
    jb   DH_Done
    mov  dl, HX+2
    mov  dh, HY+2
    call Gotoxy
    mov  al, 'O'
    call WriteChar
    cmp  ebx, 2
    jb   DH_Done
    mov  dl, HX+2
    mov  dh, HY+3
    call Gotoxy
    mov  al, '|'
    call WriteChar
    cmp  ebx, 3
    jb   DH_Done
    mov  dl, HX+1
    mov  dh, HY+3
    call Gotoxy
    mov  al, '/'
    call WriteChar
    cmp  ebx, 4
    jb   DH_Done
    mov  dl, HX+3
    mov  dh, HY+3
    call Gotoxy
    mov  al, 5Ch
    call WriteChar
    cmp  ebx, 5
    jb   DH_Done
    mov  dl, HX+1
    mov  dh, HY+4
    call Gotoxy
    mov  al, '/'
    call WriteChar
    cmp  ebx, 6
    jb   DH_Done
    mov  dl, HX+3
    mov  dh, HY+4
    call Gotoxy
    mov  al, 5Ch
    call WriteChar
DH_Done:
    mColor lightGray
    mPrintAt 5, 13, "Mistakes: "
    mov  eax, ebx
    call WriteDec
    mPrint " / 6"
    mColor NORMAL_COLOR
    ret
DrawHangman ENDP

DrawWordPanel PROC USES eax ebx ecx edx esi
    mov  dh, 7
    mov  dl, 33
    call Gotoxy
    mov  esi, 0
    mov  ecx, wordLen
WP_Letter:
    mov  al, maskWord[esi]
    cmp  al, '_'
    je   WP_Hidden
    mColor lightGreen
    jmp  WP_Out
WP_Hidden:
    cmp  revealMode, 1
    jne  WP_Under
    mColor lightRed
    mov  al, secretWord[esi]
    jmp  WP_Out
WP_Under:
    mColor white
WP_Out:
    call WriteChar
    mov  al, ' '
    call WriteChar
    inc  esi
    loop WP_Letter

    mColor lightGray
    mPrintAt 33, 9, "Letters : "
    mov  eax, wordLen
    call WriteDec
    mPrintAt 33, 10, "Lives   : "
    mov  ebx, 0
WP_Heart:
    cmp  ebx, lives
    jae  WP_Lost
    mColor lightRed
    mov  al, HEART_CH
    jmp  WP_HOut
WP_Lost:
    mColor gray
    mov  al, '-'
WP_HOut:
    call WriteChar
    mov  al, ' '
    call WriteChar
    inc  ebx
    cmp  ebx, MAX_LIVES
    jb   WP_Heart

    mColor lightGray
    mPrintAt 33, 11, "Score   : "
    mov  eax, roundScore
    call WriteDec
    mPrintAt 33, 12, "Wrong   : "
    mColor lightRed
    mov  ecx, wrongCount
    jecxz WP_Done
    mov  esi, 0
WP_Wrong:
    mov  al, wrongList[esi]
    call WriteChar
    mov  al, ' '
    call WriteChar
    inc  esi
    loop WP_Wrong
WP_Done:
    mColor NORMAL_COLOR
    ret
DrawWordPanel ENDP

DrawKeyboard PROC USES eax ebx ecx edx
    mov  ebx, 0
KB_Loop:
    mov  eax, ebx
    mov  ecx, 13
    xor  edx, edx
    div  ecx
    shl  eax, 1
    add  eax, 17
    lea  ecx, [edx + edx*4]
    add  ecx, 10
    mov  dh, al
    mov  dl, cl
    call Gotoxy
    movzx eax, guessed[ebx]
    cmp  eax, 1
    je   KB_Good
    cmp  eax, 2
    je   KB_Bad
    mov  eax, black + (lightGray * 16)
    jmp  KB_Set
KB_Good:
    mov  eax, white + (green * 16)
    jmp  KB_Set
KB_Bad:
    mov  eax, white + (red * 16)
KB_Set:
    call SetTextColor
    mov  al, ' '
    call WriteChar
    mov  al, bl
    add  al, 'A'
    call WriteChar
    mov  al, ' '
    call WriteChar
    inc  ebx
    cmp  ebx, 26
    jb   KB_Loop
    mColor NORMAL_COLOR
    ret
DrawKeyboard ENDP

ShowStatus PROC USES eax edx
    push edx
    push eax
    mov  eax, NORMAL_COLOR
    call SetTextColor
    mov  dh, STATUS_ROW
    mov  dl, 2
    call Gotoxy
    mov  edx, OFFSET blankLine
    call WriteString
    mov  dh, STATUS_ROW
    mov  dl, 4
    call Gotoxy
    pop  eax
    call SetTextColor
    pop  edx
    call WriteString
    mov  eax, NORMAL_COLOR
    call SetTextColor
    ret
ShowStatus ENDP

Dashboard PROC USES eax ebx ecx edx esi
DSH_Start:
    mColor NORMAL_COLOR
    call Clrscr
    mColor lightBlue
    INVOKE DrawBox, 1, 0, 78, 3
    INVOKE DrawBox, 1, 4, 37, 12
    INVOKE DrawBox, 40, 4, 39, 12
    INVOKE DrawBox, 1, 17, 78, 7
    mColor yellow
    mPrintAt 4, 1, "PLAYER DASHBOARD"
    mColor gray
    mPrintAt 42, 1, "saved in stats.dat and history.txt"
    mColor lightCyan
    mPrintAt 3, 4, " STATISTICS "
    mPrintAt 42, 4, " PERFORMANCE "
    mPrintAt 3, 17, " RECENT GAMES "

    mColor white
    mPrintAt 4, 6, "Games played   : "
    mov  eax, gPlayed
    call WriteDec
    mPrintAt 4, 7, "Wins           : "
    mov  eax, gWins
    call WriteDec
    mPrintAt 4, 8, "Losses         : "
    mov  eax, gLosses
    call WriteDec
    mPrintAt 4, 9, "Win rate       : "
    call CalcWinRate
    call WriteDec
    mov  al, 25h
    call WriteChar
    mPrintAt 4, 10, "Total score    : "
    mov  eax, gTotal
    call WriteDec
    mPrintAt 4, 11, "Best round     : "
    mov  eax, gHigh
    call WriteDec
    mPrintAt 4, 12, "Average / game : "
    mov  eax, 0
    cmp  gPlayed, 0
    je   DSH_Avg
    mov  eax, gTotal
    xor  edx, edx
    div  gPlayed
DSH_Avg:
    call WriteDec
    mPrintAt 4, 13, "Current streak : "
    mov  eax, gCurStreak
    call WriteDec
    mPrintAt 4, 14, "Best streak    : "
    mov  eax, gBestStreak
    call WriteDec

    mColor white
    mPrintAt 43, 6, "Wins   "
    INVOKE DrawBar, gWins, gPlayed, lightGreen
    mPrint " "
    mov  eax, gWins
    call WriteDec
    mPrintAt 43, 8, "Losses "
    INVOKE DrawBar, gLosses, gPlayed, lightRed
    mPrint " "
    mov  eax, gLosses
    call WriteDec
    mPrintAt 43, 10, "Rate   "
    call CalcWinRate
    INVOKE DrawBar, eax, 100, yellow
    mPrint " "
    call CalcWinRate
    call WriteDec
    mov  al, 25h
    call WriteChar
    mColor lightGray
    mPrintAt 43, 12, "Words in list : "
    mov  eax, wordCount
    call WriteDec
    mPrintAt 43, 13, "Session score : "
    mov  eax, sessionScore
    call WriteDec

    call ShowRecentHistory

    mColor gray
    mPrintAt 4, 24, "R = reset statistics          any other key = back to menu"
    mColor NORMAL_COLOR

    call ReadChar
    cmp  al, 'r'
    je   DSH_Reset
    cmp  al, 'R'
    je   DSH_Reset
    ret
DSH_Reset:
    mov  ebx, OFFSET capReset
    mov  edx, OFFSET askReset
    call MsgBoxAsk
    cmp  eax, ID_YES_VAL
    jne  DSH_Start
    call ClearStats
    call SaveStats
    mov  edx, OFFSET histFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   DSH_Start
    call CloseFile
    jmp  DSH_Start
Dashboard ENDP

CalcWinRate PROC USES ebx edx
    mov  eax, 0
    cmp  gPlayed, 0
    je   CW_Done
    mov  eax, gWins
    mov  ebx, 100
    mul  ebx
    div  gPlayed
CW_Done:
    ret
CalcWinRate ENDP

DrawBar PROC USES eax ebx ecx edx, bVal:DWORD, bTot:DWORD, bClr:DWORD
    mov  eax, 0
    cmp  bTot, 0
    je   DBR_Have
    mov  eax, bVal
    mov  ebx, BAR_LEN
    mul  ebx
    div  bTot
DBR_Have:
    mov  ebx, eax
    mov  eax, bClr
    call SetTextColor
    mov  ecx, ebx
    jecxz DBR_Rest
    mov  al, BLOCK_CH
DBR_Fill:
    call WriteChar
    loop DBR_Fill
DBR_Rest:
    mov  eax, gray
    call SetTextColor
    mov  ecx, BAR_LEN
    sub  ecx, ebx
    jecxz DBR_Done
    mov  al, SHADE_CH
DBR_Empty:
    call WriteChar
    loop DBR_Empty
DBR_Done:
    mColor NORMAL_COLOR
    ret
DrawBar ENDP

ShowRecentHistory PROC USES eax ebx ecx edx esi
    LOCAL hFile:DWORD
    mov  edx, OFFSET histFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   RH_None
    mov  hFile, eax
    INVOKE SetFilePointer, hFile, -HIST_READ, 0, MY_FILE_END
    mov  eax, hFile
    mov  edx, OFFSET histBuffer
    mov  ecx, HIST_READ
    call ReadFromFile
    jc   RH_CloseNone
    mov  ebx, eax
    mov  histBuffer[ebx], 0
    mov  eax, hFile
    call CloseFile
    mov  ecx, ebx
RH_Trim:
    cmp  ecx, 0
    je   RH_None
    mov  al, histBuffer[ecx-1]
    cmp  al, 0Ah
    je   RH_TrimOne
    cmp  al, 0Dh
    je   RH_TrimOne
    jmp  RH_Trimmed
RH_TrimOne:
    dec  ecx
    jmp  RH_Trim
RH_Trimmed:
    mov  histBuffer[ecx], 0
    mov  edx, 0
RH_Back:
    cmp  ecx, 0
    je   RH_Print
    cmp  histBuffer[ecx-1], 0Ah
    jne  RH_Prev
    inc  edx
    cmp  edx, RECENT_LINES
    je   RH_Print
RH_Prev:
    dec  ecx
    jmp  RH_Back
RH_Print:
    lea  esi, histBuffer[ecx]
    mColor lightGray
    mov  dh, 18
    mov  dl, 4
    call PrintLinesAt
    mColor NORMAL_COLOR
    ret
RH_CloseNone:
    mov  eax, hFile
    call CloseFile
RH_None:
    mColor gray
    mPrintAt 4, 19, "No games recorded yet - play a round first."
    mColor NORMAL_COLOR
    ret
ShowRecentHistory ENDP

PrintLinesAt PROC USES eax ebx edx esi
    mov  bl, dl
    call Gotoxy
PL_Loop:
    lodsb
    cmp  al, 0
    je   PL_Done
    cmp  al, 0Dh
    je   PL_Loop
    cmp  al, 0Ah
    jne  PL_Char
    inc  dh
    mov  dl, bl
    call Gotoxy
    jmp  PL_Loop
PL_Char:
    call WriteChar
    jmp  PL_Loop
PL_Done:
    ret
PrintLinesAt ENDP

AddWordScreen PROC USES eax ebx ecx edx esi edi
    mColor NORMAL_COLOR
    call Clrscr
    mColor lightBlue
    INVOKE DrawBox, 1, 0, 78, 3
    INVOKE DrawBox, 10, 6, 60, 9
    mColor yellow
    mPrintAt 4, 1, "ADD A NEW WORD"
    mColor lightGray
    mPrintAt 13, 8, "Words must be 3 to 15 letters (A to Z only)."
    mPrintAt 13, 9, "The word is saved permanently in words.txt"
    mPrintAt 13, 11, "New word: "
    mColor white
    mov  edx, OFFSET inputBuf
    mov  ecx, SIZEOF inputBuf - 1
    call ReadString
    cmp  eax, MIN_WORD
    jb   AW_BadLen
    cmp  eax, WORD_SIZE - 1
    ja   AW_BadLen

    mov  ecx, eax
    mov  esi, OFFSET inputBuf
AW_Check:
    mov  al, [esi]
    cmp  al, 'a'
    jb   AW_Upper
    cmp  al, 'z'
    ja   AW_BadChar
    sub  al, 32
    mov  [esi], al
    jmp  AW_Next
AW_Upper:
    cmp  al, 'A'
    jb   AW_BadChar
    cmp  al, 'Z'
    ja   AW_BadChar
AW_Next:
    inc  esi
    loop AW_Check

    cmp  wordCount, MAX_WORDS
    jae  AW_Full

    mov  ebx, 0
AW_Dup:
    cmp  ebx, wordCount
    jae  AW_Add
    mov  esi, ebx
    shl  esi, 4
    add  esi, OFFSET wordTable
    INVOKE Str_compare, ADDR inputBuf, esi
    je   AW_Exists
    inc  ebx
    jmp  AW_Dup

AW_Add:
    mov  esi, OFFSET inputBuf
    call ParseWordBuffer
    cld
    mov  edi, OFFSET lineBuf
    mov  BYTE PTR [edi], 0Dh
    mov  BYTE PTR [edi+1], 0Ah
    add  edi, 2
    mov  esi, OFFSET inputBuf
    call CopyStr
    mov  BYTE PTR [edi], 0Dh
    mov  BYTE PTR [edi+1], 0Ah
    add  edi, 2
    mov  ecx, edi
    sub  ecx, OFFSET lineBuf
    INVOKE AppendText, ADDR wordsFile, ADDR lineBuf, ecx
    mColor lightGreen
    mPrintAt 13, 13, "Saved. Words in list now: "
    mov  eax, wordCount
    call WriteDec
    jmp  AW_Wait
AW_BadLen:
    mColor lightRed
    mPrintAt 13, 13, "Rejected - the word must be 3 to 15 letters long."
    jmp  AW_Wait
AW_BadChar:
    mColor lightRed
    mPrintAt 13, 13, "Rejected - use the letters A to Z only."
    jmp  AW_Wait
AW_Full:
    mColor lightRed
    mPrintAt 13, 13, "Rejected - the word list is full (100 words)."
    jmp  AW_Wait
AW_Exists:
    mColor lightRed
    mPrintAt 13, 13, "That word is already in the list."
AW_Wait:
    mColor NORMAL_COLOR
    mov  dh, 18
    mov  dl, 13
    call Gotoxy
    call WaitMsg
    ret
AddWordScreen ENDP

HelpScreen PROC USES edx
    mColor NORMAL_COLOR
    call Clrscr
    mColor lightBlue
    INVOKE DrawBox, 1, 0, 78, 3
    INVOKE DrawBox, 1, 4, 78, 18
    mColor yellow
    mPrintAt 4, 1, "HOW TO PLAY"
    mColor lightCyan
    mPrintAt 4, 6, "THE GAME"
    mColor lightGray
    mPrintAt 6, 7,  "1. A secret word is picked at random from words.txt."
    mPrintAt 6, 8,  "2. Type one letter at a time - correct letters turn green."
    mPrintAt 6, 9,  "3. Each wrong letter costs a life and adds a part to the hangman."
    mPrintAt 6, 10, "4. Reveal the whole word before you lose all 6 lives."
    mColor lightCyan
    mPrintAt 4, 12, "SCORING"
    mColor lightGray
    mPrintAt 6, 13, "+10 for every letter revealed in the word"
    mPrintAt 6, 14, "+50 bonus for a win  plus  +20 for every life left"
    mColor lightCyan
    mPrintAt 4, 16, "FILES  (kept in the same folder as the program)"
    mColor lightGray
    mPrintAt 6, 17, "words.txt    the word list - edit in Notepad (one word per line)"
    mPrintAt 6, 18, "stats.dat    saved statistics shown on the Dashboard"
    mPrintAt 6, 19, "history.txt  a log line for every finished game"
    mColor NORMAL_COLOR
    mov  dh, 23
    mov  dl, 2
    call Gotoxy
    call WaitMsg
    ret
HelpScreen ENDP

GoodbyeScreen PROC USES edx
    mColor NORMAL_COLOR
    call Clrscr
    mColor lightBlue
    INVOKE DrawBox, 19, 8, 42, 7
    mColor yellow
    mPrintAt 27, 10, "Thanks for playing HANGMAN"
    mColor lightGray
    mPrintAt 24, 12, "Your statistics have been saved."
    mColor NORMAL_COLOR
    mov  dh, 17
    mov  dl, 19
    call Gotoxy
    call WaitMsg
    ret
GoodbyeScreen ENDP

LoadWords PROC USES eax ebx ecx edx esi
    mov  wordCount, 0
    mov  edx, OFFSET wordsFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   LW_NoFile
    mov  fileHandle, eax
    mov  edx, OFFSET fileBuffer
    mov  ecx, FILE_BUF - 1
    call ReadFromFile
    jc   LW_ReadFail
    mov  ebx, eax
    mov  fileBuffer[ebx], 0
    mov  eax, fileHandle
    call CloseFile
    mov  esi, OFFSET fileBuffer
    call ParseWordBuffer
    cmp  wordCount, 0
    ja   LW_Done
    jmp  LW_BuiltIn
LW_ReadFail:
    mov  eax, fileHandle
    call CloseFile
    jmp  LW_BuiltIn
LW_NoFile:
    mov  edx, OFFSET wordsFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   LW_BuiltIn
    mov  fileHandle, eax
    mov  edx, OFFSET defaultWords
    call StrLength
    mov  ecx, eax
    mov  eax, fileHandle
    call WriteToFile
    mov  eax, fileHandle
    call CloseFile
LW_BuiltIn:
    mov  wordCount, 0
    mov  esi, OFFSET defaultWords
    call ParseWordBuffer
LW_Done:
    ret
LoadWords ENDP

ParseWordBuffer PROC USES eax ebx ecx edx esi
    xor  ecx, ecx
    xor  edx, edx
PWB_Next:
    cmp  wordCount, MAX_WORDS
    jae  PWB_Done
    mov  al, [esi]
    inc  esi
    cmp  al, 'a'
    jb   PWB_Upper
    cmp  al, 'z'
    ja   PWB_Sep
    sub  al, 32
    jmp  PWB_Letter
PWB_Upper:
    cmp  al, 'A'
    jb   PWB_Sep
    cmp  al, 'Z'
    ja   PWB_Sep
PWB_Letter:
    cmp  ecx, WORD_SIZE - 1
    jb   PWB_Store
    mov  edx, 1
    jmp  PWB_Next
PWB_Store:
    mov  ebx, wordCount
    shl  ebx, 4
    add  ebx, ecx
    mov  wordTable[ebx], al
    inc  ecx
    jmp  PWB_Next
PWB_Sep:
    cmp  ecx, MIN_WORD
    jb   PWB_Reset
    cmp  edx, 0
    jne  PWB_Reset
    mov  ebx, wordCount
    shl  ebx, 4
    add  ebx, ecx
    mov  wordTable[ebx], 0
    inc  wordCount
PWB_Reset:
    xor  ecx, ecx
    xor  edx, edx
    cmp  al, 0
    jne  PWB_Next
PWB_Done:
    ret
ParseWordBuffer ENDP

LoadStats PROC USES eax ecx edx
    mov  edx, OFFSET statsFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   LS_Done
    mov  fileHandle, eax
    mov  edx, OFFSET statsBlock
    mov  ecx, STATS_SIZE
    call ReadFromFile
    jc   LS_Bad
    cmp  eax, STATS_SIZE
    jne  LS_Bad
    mov  eax, fileHandle
    call CloseFile
    ret
LS_Bad:
    mov  eax, fileHandle
    call CloseFile
    call ClearStats
LS_Done:
    ret
LoadStats ENDP

SaveStats PROC USES eax ecx edx
    mov  edx, OFFSET statsFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   SS_Done
    mov  fileHandle, eax
    mov  edx, OFFSET statsBlock
    mov  ecx, STATS_SIZE
    call WriteToFile
    mov  eax, fileHandle
    call CloseFile
SS_Done:
    ret
SaveStats ENDP

ClearStats PROC USES eax ecx edi
    cld
    mov  edi, OFFSET statsBlock
    mov  ecx, STATS_SIZE
    mov  al, 0
    rep  stosb
    ret
ClearStats ENDP

LogHistory PROC USES eax ebx ecx esi edi
    cld
    mov  edi, OFFSET lineBuf
    mov  esi, OFFSET hGame
    call CopyStr
    mov  ebx, edi
    mov  eax, gPlayed
    call NumToStr
    mov  ecx, ebx
    add  ecx, 5
    sub  ecx, edi
    cmp  ecx, 0
    jle  LH_NoPad
    mov  al, ' '
    rep  stosb
LH_NoPad:
    mov  esi, OFFSET hWin
    cmp  roundResult, 1
    je   LH_Res
    mov  esi, OFFSET hLoss
LH_Res:
    call CopyStr
    mov  esi, OFFSET secretWord
    call CopyStr
    mov  ecx, WORD_SIZE
    sub  ecx, wordLen
    mov  al, ' '
    rep  stosb
    mov  esi, OFFSET hScore
    call CopyStr
    mov  eax, roundScore
    call NumToStr
    mov  esi, OFFSET hLives
    call CopyStr
    mov  eax, lives
    call NumToStr
    mov  BYTE PTR [edi], 0Dh
    mov  BYTE PTR [edi+1], 0Ah
    add  edi, 2
    mov  ecx, edi
    sub  ecx, OFFSET lineBuf
    INVOKE AppendText, ADDR histFile, ADDR lineBuf, ecx
    ret
LogHistory ENDP

AppendText PROC USES eax ecx edx, pFile:PTR BYTE, pText:PTR BYTE, nLen:DWORD
    LOCAL hFile:DWORD
    INVOKE CreateFile, pFile, MY_GENERIC_WRITE, MY_SHARE_READ, 0, MY_OPEN_ALWAYS, MY_ATTR_NORMAL, 0
    cmp  eax, INVALID_HANDLE_VALUE
    je   AT_Done
    mov  hFile, eax
    INVOKE SetFilePointer, hFile, 0, 0, MY_FILE_END
    mov  eax, hFile
    mov  edx, pText
    mov  ecx, nLen
    call WriteToFile
    mov  eax, hFile
    call CloseFile
AT_Done:
    ret
AppendText ENDP

CopyStr PROC USES eax
CS_Loop:
    lodsb
    cmp  al, 0
    je   CS_Done
    stosb
    jmp  CS_Loop
CS_Done:
    ret
CopyStr ENDP

NumToStr PROC USES eax ebx edx
    mov  ebx, 10
    xor  edx, edx
    div  ebx
    cmp  eax, 0
    je   NTS_Digit
    call NumToStr
NTS_Digit:
    add  dl, '0'
    mov  [edi], dl
    inc  edi
    ret
NumToStr ENDP

END main
