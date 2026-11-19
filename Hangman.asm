; ==============================================================
;  HANGMAN GAME - x86 Assembly (MASM + Irvine32)
;  EL-2003 COAL Lab Project - Fall 2026
;
;  Muhammad Hassaan Raza   25K-0611  (Group Leader)
;  Muaviyah Bin Arsalan    25K-0905
;  Hashir Ahmed            25K-0754
;
;  Files used by the game (same folder as the program):
;     words.txt  - list of words, one per line (created if missing)
;     stats.dat  - saved statistics for the dashboard
; ==============================================================

INCLUDE Irvine32.inc

; ---------------- constants ----------------
MAX_WORDS   = 50            ; max words we can load
WORD_SIZE   = 16            ; each word gets 16 bytes in the word list
MAX_LIVES   = 6
BUFFER_SIZE = 2000          ; size of buffer used to read words.txt
DEFAULT_COLOR      = lightGray + (black * 16)

; ---------------- macros ----------------
; move the cursor to (column, row)
mGoto MACRO col, row
    mov dl, col
    mov dh, row
    call Gotoxy
ENDM

; print a string that is defined in .data
mPrint MACRO msg
    mov edx, OFFSET msg
    call WriteString
ENDM

; change the text colour
mColor MACRO clr
    mov eax, clr
    call SetTextColor
ENDM


.data
; ---------------- file data ----------------
wordsFile   BYTE "words.txt", 0
statsFile   BYTE "stats.dat", 0
fileHandle  DWORD ?
bytesRead   DWORD ?
buffer      BYTE BUFFER_SIZE DUP(0)

; default words (used if words.txt does not exist)
defaultWords BYTE "COMPUTER", 0Dh, 0Ah, "ASSEMBLY", 0Dh, 0Ah, "REGISTER", 0Dh, 0Ah
             BYTE "PROCEDURE", 0Dh, 0Ah, "KEYBOARD", 0Dh, 0Ah, "MEMORY", 0Dh, 0Ah
             BYTE "PROCESSOR", 0Dh, 0Ah, "COMPILER", 0Dh, 0Ah, "VARIABLE", 0Dh, 0Ah
             BYTE "POINTER", 0Dh, 0Ah, "INTERRUPT", 0Dh, 0Ah, "STACK", 0Dh, 0Ah
             BYTE "BINARY", 0Dh, 0Ah, "HARDWARE", 0Dh, 0Ah, "SOFTWARE", 0Dh, 0Ah
             BYTE "MONITOR", 0Dh, 0Ah, "NETWORK", 0Dh, 0Ah, "ALGORITHM", 0Dh, 0Ah
             BYTE "DEBUGGER", 0Dh, 0Ah, "FUNCTION", 0Dh, 0Ah, "SEGMENT", 0Dh, 0Ah
             BYTE "OPERAND", 0Dh, 0Ah, "MACRO", 0Dh, 0Ah, "LIBRARY", 0Dh, 0Ah
             BYTE 0
DEFAULT_LEN = (SIZEOF defaultWords) - 1      ; length without the last 0

; ---------------- word list (2-D array: 50 rows x 16 columns) ----------------
wordList    BYTE MAX_WORDS * WORD_SIZE DUP(0)
wordCount   DWORD 0

; ---------------- game variables ----------------
secret      BYTE WORD_SIZE DUP(0)   ; the hidden word
maskWord    BYTE WORD_SIZE DUP(0)   ; what the player sees, e.g. C_MP_TER
wordLen     DWORD 0
lives       DWORD MAX_LIVES
wrongCount  DWORD 0
score       DWORD 0                 ; score of the current round
guessed     BYTE 26 DUP(0)          ; one byte per letter: 0 = not tried,
                                    ; 1 = correct, 2 = wrong

; ---------------- statistics (saved to stats.dat) ----------------
statsData   LABEL DWORD
gamesPlayed DWORD 0
gamesWon    DWORD 0
gamesLost   DWORD 0
totalScore  DWORD 0
bestScore   DWORD 0
STATS_BYTES = 20                    ; 5 DWORDs = 20 bytes

; ---------------- screen frame ----------------
lineTop     BYTE "+", 76 DUP("-"), "+", 0
lineMid     BYTE "|", 76 DUP(" "), "|", 0

; ---------------- menu text ----------------
title1      BYTE "H  A  N  G  M  A  N", 0
title2      BYTE "x86 Assembly Project  -  COAL Lab", 0
opt1        BYTE "[1]  Play Game", 0
opt2        BYTE "[2]  Dashboard", 0
opt3        BYTE "[3]  How to Play", 0
opt4        BYTE "[4]  Exit", 0
lblLoaded   BYTE "Words loaded: ", 0
askChoice   BYTE "Enter your choice (1-4): ", 0
names       BYTE "Hassaan 25K-0611  |  Muaviyah 25K-0905  |  Hashir 25K-0754", 0

; ---------------- game screen text ----------------
gameTitle   BYTE "H A N G M A N", 0
gal1        BYTE "  +-----+", 0
gal2        BYTE "  |     |", 0
gal3        BYTE "        |", 0
gal4        BYTE "===========", 0
lblWord     BYTE "SECRET WORD", 0
lblLetters  BYTE "Letters    : ", 0
lblLives    BYTE "Lives left : ", 0
lblScore    BYTE "Score      : ", 0
lblWrong    BYTE "Mistakes   : ", 0
outOf6      BYTE " / 6", 0
lblKeys     BYTE "LETTERS USED  (green = correct, red = wrong)", 0
helpLine    BYTE "Type a letter to guess.   Press ESC to go back to the menu.", 0
msgInvalid  BYTE "Please type a letter (A-Z) only.          ", 0
msgRepeat   BYTE "You already tried that letter.            ", 0
msgWin      BYTE "*** YOU WIN! You guessed the word. ***    ", 0
msgLose     BYTE "*** GAME OVER! You ran out of lives. ***  ", 0
msgAgain    BYTE "Play again? (Y/N): ", 0

; ---------------- message boxes ----------------
capWin      BYTE "Hangman - You Win", 0
boxWin      BYTE "Congratulations! You guessed the word.", 0
capLose     BYTE "Hangman - Game Over", 0
boxLose     BYTE "Out of lives! The word is shown in red.", 0

; ---------------- dashboard text ----------------
dashTitle   BYTE "PLAYER DASHBOARD", 0
lblPlayed   BYTE "Games played  : ", 0
lblWon      BYTE "Games won     : ", 0
lblLost     BYTE "Games lost    : ", 0
lblRate     BYTE "Win rate      : ", 0
lblTotal    BYTE "Total score   : ", 0
lblBest     BYTE "Best score    : ", 0
lblBar      BYTE "Win rate bar  : [", 0
barEnd      BYTE "]", 0
percent     BYTE " %", 0
savedNote   BYTE "(statistics are saved in stats.dat)", 0
winRate     DWORD 0

; ---------------- help text ----------------
helpTitle   BYTE "HOW TO PLAY", 0
help1       BYTE "1. The computer picks a random word from words.txt", 0
help2       BYTE "2. Guess the word one letter at a time", 0
help3       BYTE "3. A correct letter is shown in all its places (+10 points)", 0
help4       BYTE "4. A wrong letter costs one life and draws part of the hangman", 0
help5       BYTE "5. Guess the word before you lose all 6 lives", 0
help6       BYTE "6. Winning gives +50 bonus and +20 for every life left", 0
help7       BYTE "You can add your own words to words.txt using Notepad.", 0

msgBye      BYTE "Thanks for playing Hangman! Your statistics are saved.", 0


.code
; ==============================================================
;  MAIN
; ==============================================================
main PROC
    call Randomize              ; seed the random number generator
    call LoadWords              ; read words.txt into wordList
    call LoadStats              ; read stats.dat

MenuLoop:
    call ShowMenu               ; returns the key pressed in AL
    cmp al, '1'
    je  Choice1
    cmp al, '2'
    je  Choice2
    cmp al, '3'
    je  Choice3
    cmp al, '4'
    je  ExitGame
    jmp MenuLoop                ; any other key: show menu again

Choice1:
    call PlayGame
    jmp MenuLoop
Choice2:
    call Dashboard
    jmp MenuLoop
Choice3:
    call HowToPlay
    jmp MenuLoop

ExitGame:
    call SaveStats
    mColor DEFAULT_COLOR
    call Clrscr
    mPrint msgBye
    call Crlf
    call WaitMsg
    exit
main ENDP


; ==============================================================
;  DrawFrame - draws a border around the whole screen (rows 0-22)
; ==============================================================
DrawFrame PROC
    mColor lightBlue
    mGoto 1, 0
    mPrint lineTop

    mov bl, 1                   ; BL = current row
    mov ecx, 21                 ; 21 middle rows
SideLoop:
    mov dl, 1
    mov dh, bl
    call Gotoxy
    mov edx, OFFSET lineMid
    call WriteString
    inc bl
    loop SideLoop

    mov dl, 1
    mov dh, bl
    call Gotoxy
    mPrint lineTop
    ret
DrawFrame ENDP


; ==============================================================
;  ShowMenu - draws the main menu
;  Returns: AL = key pressed
; ==============================================================
ShowMenu PROC
    mColor DEFAULT_COLOR
    call Clrscr
    call DrawFrame

    mColor yellow
    mGoto 30, 3
    mPrint title1
    mColor lightCyan
    mGoto 23, 5
    mPrint title2

    mColor white
    mGoto 32, 8
    mPrint opt1
    mGoto 32, 10
    mPrint opt2
    mGoto 32, 12
    mPrint opt3
    mGoto 32, 14
    mPrint opt4

    mColor lightGray
    mGoto 32, 17
    mPrint lblLoaded
    mov eax, wordCount
    call WriteDec

    mColor gray
    mGoto 10, 21
    mPrint names

    mColor yellow
    mGoto 28, 19
    mPrint askChoice
    call ReadChar               ; AL = key
    ret
ShowMenu ENDP


; ==============================================================
;  PlayGame - plays rounds until the player says No
; ==============================================================
PlayGame PROC
NewRound:
    call PickWord
    call InitGame

GameLoop:
    call DrawGame
    call ReadGuess              ; AL = letter, or 0 if ESC
    cmp al, 0
    je  QuitGame
    call CheckGuess
    call CheckWin               ; EAX = 1 if word is complete
    cmp eax, 1
    je  PlayerWon
    cmp lives, 0
    je  PlayerLost
    jmp GameLoop

PlayerWon:
    ; bonus = 50 + 20 * lives left
    mov eax, lives
    mov ebx, 20
    mul ebx
    add eax, 50
    add score, eax
    inc gamesWon
    call UpdateStats
    call DrawGame
    mColor lightGreen
    mGoto 4, 19
    mPrint msgWin
    mov ebx, OFFSET capWin
    mov edx, OFFSET boxWin
    call MsgBox                 ; Windows message box
    jmp AskAgain

PlayerLost:
    inc gamesLost
    call UpdateStats
    call DrawGame               ; lives = 0, so the word is shown in red
    mColor lightRed
    mGoto 4, 19
    mPrint msgLose
    mov ebx, OFFSET capLose
    mov edx, OFFSET boxLose
    call MsgBox

AskAgain:
    mColor white
    mGoto 4, 20
    mPrint msgAgain
    call ReadChar
    cmp al, 'y'
    je  NewRound
    cmp al, 'Y'
    je  NewRound

QuitGame:
    ret
PlayGame ENDP


; ==============================================================
;  PickWord - copies a random word from wordList into secret
; ==============================================================
PickWord PROC
    mov eax, wordCount
    call RandomRange            ; EAX = random number 0 .. wordCount-1

    mov ebx, WORD_SIZE
    mul ebx                     ; EAX = index * 16 = start of that row

    mov esi, OFFSET wordList
    add esi, eax                ; ESI -> chosen word
    mov edi, OFFSET secret
    mov ecx, WORD_SIZE
    cld
    rep movsb                   ; copy 16 bytes

    mov edx, OFFSET secret
    call StrLength              ; EAX = length of word
    mov wordLen, eax
    ret
PickWord ENDP


; ==============================================================
;  InitGame - resets everything for a new round
; ==============================================================
InitGame PROC
    mov lives, MAX_LIVES
    mov wrongCount, 0
    mov score, 0

    ; clear the guessed[] array
    mov edi, OFFSET guessed
    mov ecx, 26
    mov al, 0
    cld
    rep stosb

    ; fill maskWord with underscores
    mov edi, OFFSET maskWord
    mov ecx, wordLen
    mov al, '_'
    rep stosb
    mov BYTE PTR [edi], 0       ; end of string
    ret
InitGame ENDP


; ==============================================================
;  ReadGuess - reads a letter from the keyboard
;  Returns: AL = capital letter A-Z, or AL = 0 if ESC was pressed
; ==============================================================
ReadGuess PROC
ReadAgain:
    call ReadChar
    cmp al, 27                  ; ESC key
    je  PressedEsc

    cmp al, 'a'                 ; small letter?  convert to capital
    jb  CheckCapital
    cmp al, 'z'
    ja  NotLetter
    sub al, 32

CheckCapital:
    cmp al, 'A'
    jb  NotLetter
    cmp al, 'Z'
    ja  NotLetter

    movzx ebx, al               ; check if already guessed
    sub ebx, 'A'                ; EBX = 0 for A, 1 for B ...
    cmp guessed[ebx], 0
    jne AlreadyTried
    ret                         ; valid new letter in AL

NotLetter:
    push eax
    mColor yellow
    mGoto 4, 19
    mPrint msgInvalid
    pop eax
    jmp ReadAgain

AlreadyTried:
    push eax
    mColor yellow
    mGoto 4, 19
    mPrint msgRepeat
    pop eax
    jmp ReadAgain

PressedEsc:
    mov al, 0
    ret
ReadGuess ENDP


; ==============================================================
;  CheckGuess - checks the letter in AL against the secret word
; ==============================================================
CheckGuess PROC
    mov bl, 0                   ; BL = 1 if the letter is found
    mov esi, 0
    mov ecx, wordLen
SearchLoop:
    cmp secret[esi], al
    jne NextLetter
    mov maskWord[esi], al       ; reveal this position
    add score, 10
    mov bl, 1
NextLetter:
    inc esi
    loop SearchLoop

    movzx edx, al
    sub edx, 'A'                ; EDX = index of the letter
    cmp bl, 1
    je  RightGuess

    mov guessed[edx], 2         ; wrong guess
    dec lives
    inc wrongCount
    ret

RightGuess:
    mov guessed[edx], 1         ; correct guess
    ret
CheckGuess ENDP


; ==============================================================
;  CheckWin - looks for '_' in maskWord using SCASB
;  Returns: EAX = 1 if no '_' is left (player won), else 0
; ==============================================================
CheckWin PROC
    mov edi, OFFSET maskWord
    mov ecx, wordLen
    mov al, '_'
    cld
    repne scasb                 ; search for '_'
    je  NotFinished             ; found one, word not complete
    mov eax, 1
    ret
NotFinished:
    mov eax, 0
    ret
CheckWin ENDP


; ==============================================================
;  UpdateStats - adds the finished round to the statistics
; ==============================================================
UpdateStats PROC
    inc gamesPlayed
    mov eax, score
    add totalScore, eax
    cmp eax, bestScore
    jbe NotBest
    mov bestScore, eax
NotBest:
    call SaveStats              ; save after every round
    ret
UpdateStats ENDP


; ==============================================================
;  DrawGame - draws the complete game screen
; ==============================================================
DrawGame PROC
    mColor DEFAULT_COLOR
    call Clrscr
    call DrawFrame

    mColor yellow
    mGoto 32, 1
    mPrint gameTitle

    call DrawHangman

    ; ---- secret word ----
    mColor lightCyan
    mGoto 40, 4
    mPrint lblWord

    mGoto 40, 6
    mov esi, 0
    mov ecx, wordLen
PrintWord:
    mov al, maskWord[esi]
    cmp al, '_'
    je  Hidden
    mColor lightGreen           ; found letter
    mov al, maskWord[esi]
    jmp PrintIt
Hidden:
    cmp lives, 0                ; game lost? then show the real letter
    je  Reveal
    mColor white
    mov al, '_'
    jmp PrintIt
Reveal:
    mColor lightRed
    mov al, secret[esi]
PrintIt:
    call WriteChar
    mov al, ' '
    call WriteChar
    inc esi
    loop PrintWord

    ; ---- information ----
    mColor white
    mGoto 40, 8
    mPrint lblLetters
    mov eax, wordLen
    call WriteDec
    mGoto 40, 9
    mPrint lblLives
    mov eax, lives
    call WriteDec
    mGoto 40, 10
    mPrint lblScore
    mov eax, score
    call WriteDec
    mGoto 40, 11
    mPrint lblWrong
    mov eax, wrongCount
    call WriteDec
    mPrint outOf6

    call DrawLetters

    mColor gray
    mGoto 4, 21
    mPrint helpLine
    mColor DEFAULT_COLOR
    ret
DrawGame ENDP


; ==============================================================
;  DrawHangman - draws the gallows and one body part per mistake
; ==============================================================
DrawHangman PROC
    mColor brown
    mGoto 8, 4
    mPrint gal1
    mGoto 8, 5
    mPrint gal2
    mGoto 8, 6
    mPrint gal3
    mGoto 8, 7
    mPrint gal3
    mGoto 8, 8
    mPrint gal3
    mGoto 8, 9
    mPrint gal3
    mGoto 8, 10
    mPrint gal4

    mColor lightRed
    cmp wrongCount, 1
    jb  PartsDone
    mGoto 10, 6                 ; head
    mov al, 'O'
    call WriteChar

    cmp wrongCount, 2
    jb  PartsDone
    mGoto 10, 7                 ; body
    mov al, '|'
    call WriteChar

    cmp wrongCount, 3
    jb  PartsDone
    mGoto 9, 7                  ; left arm
    mov al, '/'
    call WriteChar

    cmp wrongCount, 4
    jb  PartsDone
    mGoto 11, 7                 ; right arm
    mov al, '\'
    call WriteChar

    cmp wrongCount, 5
    jb  PartsDone
    mGoto 9, 8                  ; left leg
    mov al, '/'
    call WriteChar

    cmp wrongCount, 6
    jb  PartsDone
    mGoto 11, 8                 ; right leg
    mov al, '\'
    call WriteChar

PartsDone:
    ret
DrawHangman ENDP


; ==============================================================
;  DrawLetters - shows A to Z like a keyboard
;  grey = not tried, green = correct, red = wrong
; ==============================================================
DrawLetters PROC
    mColor lightCyan
    mGoto 6, 13
    mPrint lblKeys

    mov ebx, 0                  ; EBX = letter number (0 = A)
    mov dl, 8                   ; column
    mov dh, 15                  ; row
    mov ecx, 26
LetterLoop:
    call Gotoxy

    cmp guessed[ebx], 1
    je  GreenKey
    cmp guessed[ebx], 2
    je  RedKey
    mColor black + (lightGray * 16)
    jmp ShowKey
GreenKey:
    mColor white + (green * 16)
    jmp ShowKey
RedKey:
    mColor white + (red * 16)
ShowKey:
    mov al, ' '
    call WriteChar
    mov al, 'A'
    add al, bl                  ; letter = 'A' + number
    call WriteChar
    mov al, ' '
    call WriteChar

    add dl, 5                   ; next column
    inc ebx
    cmp ebx, 13                 ; after M go to the second row
    jne SameRow
    mov dl, 8
    mov dh, 17
SameRow:
    loop LetterLoop

    mColor DEFAULT_COLOR
    ret
DrawLetters ENDP


; ==============================================================
;  Dashboard - shows the saved statistics
; ==============================================================
Dashboard PROC
    mColor DEFAULT_COLOR
    call Clrscr
    call DrawFrame

    mColor yellow
    mGoto 31, 2
    mPrint dashTitle

    ; win rate = gamesWon * 100 / gamesPlayed
    mov winRate, 0
    cmp gamesPlayed, 0
    je  ShowNumbers             ; avoid dividing by zero
    mov eax, gamesWon
    mov ebx, 100
    mul ebx
    div gamesPlayed
    mov winRate, eax

ShowNumbers:
    mColor white
    mGoto 20, 5
    mPrint lblPlayed
    mov eax, gamesPlayed
    call WriteDec

    mGoto 20, 7
    mPrint lblWon
    mov eax, gamesWon
    call WriteDec

    mGoto 20, 9
    mPrint lblLost
    mov eax, gamesLost
    call WriteDec

    mGoto 20, 11
    mPrint lblRate
    mov eax, winRate
    call WriteDec
    mPrint percent

    mGoto 20, 13
    mPrint lblTotal
    mov eax, totalScore
    call WriteDec

    mGoto 20, 15
    mPrint lblBest
    mov eax, bestScore
    call WriteDec

    ; ---- bar: one '#' for every 5 percent (20 characters = 100%) ----
    mGoto 20, 17
    mPrint lblBar
    mov eax, winRate
    mov edx, 0
    mov ebx, 5
    div ebx                     ; EAX = number of '#'
    mov ebx, eax                ; save it

    mColor lightGreen
    mov ecx, ebx
    cmp ecx, 0
    je  EmptyPart
FillLoop:
    mov al, '#'
    call WriteChar
    loop FillLoop

EmptyPart:
    mColor gray
    mov ecx, 20
    sub ecx, ebx
    cmp ecx, 0
    je  BarDone
EmptyLoop:
    mov al, '-'
    call WriteChar
    loop EmptyLoop

BarDone:
    mColor white
    mPrint barEnd

    mColor gray
    mGoto 20, 19
    mPrint savedNote

    mColor DEFAULT_COLOR
    mGoto 20, 21
    call WaitMsg
    ret
Dashboard ENDP


; ==============================================================
;  HowToPlay - instructions screen
; ==============================================================
HowToPlay PROC
    mColor DEFAULT_COLOR
    call Clrscr
    call DrawFrame

    mColor yellow
    mGoto 33, 2
    mPrint helpTitle

    mColor white
    mGoto 8, 5
    mPrint help1
    mGoto 8, 7
    mPrint help2
    mGoto 8, 9
    mPrint help3
    mGoto 8, 11
    mPrint help4
    mGoto 8, 13
    mPrint help5
    mGoto 8, 15
    mPrint help6
    mColor lightCyan
    mGoto 8, 18
    mPrint help7

    mColor DEFAULT_COLOR
    mGoto 8, 21
    call WaitMsg
    ret
HowToPlay ENDP


; ==============================================================
;  FILE HANDLING
; ==============================================================

; --------------------------------------------------------------
;  LoadWords - reads words.txt into wordList.
;  If the file is not found, it is created with the default words.
; --------------------------------------------------------------
LoadWords PROC
    mov wordCount, 0

    mov edx, OFFSET wordsFile
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je  NoWordsFile
    mov fileHandle, eax

    mov eax, fileHandle
    mov edx, OFFSET buffer
    mov ecx, BUFFER_SIZE - 1
    call ReadFromFile           ; EAX = number of bytes read
    jc  ReadFailed
    mov bytesRead, eax

    mov eax, fileHandle
    call CloseFile

    mov ebx, bytesRead
    mov buffer[ebx], 0          ; put 0 at the end of the text
    mov esi, OFFSET buffer
    call SplitWords

    cmp wordCount, 0            ; file was empty?
    jne LoadDone
    jmp UseDefault

ReadFailed:
    mov eax, fileHandle
    call CloseFile
    jmp UseDefault

NoWordsFile:
    ; create words.txt so the player can edit it later
    mov edx, OFFSET wordsFile
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    je  UseDefault
    mov fileHandle, eax
    mov eax, fileHandle
    mov edx, OFFSET defaultWords
    mov ecx, DEFAULT_LEN
    call WriteToFile
    mov eax, fileHandle
    call CloseFile

UseDefault:
    mov wordCount, 0
    mov esi, OFFSET defaultWords
    call SplitWords

LoadDone:
    ret
LoadWords ENDP


; --------------------------------------------------------------
;  SplitWords - breaks the text at ESI into words and stores them
;  in wordList. Any character that is not a letter ends a word.
;  Words shorter than 3 letters are ignored.
;  Address of a letter = wordList + (wordCount * 16) + position
; --------------------------------------------------------------
SplitWords PROC
    mov ecx, 0                  ; ECX = letters in the current word

NextChar:
    mov al, [esi]
    inc esi

    cmp al, 'a'                 ; small letter?  make it capital
    jb  IsCapital
    cmp al, 'z'
    ja  EndOfWord
    sub al, 32
IsCapital:
    cmp al, 'A'
    jb  EndOfWord
    cmp al, 'Z'
    ja  EndOfWord

    ; it is a letter - store it (extra letters after 15 are skipped)
    cmp ecx, WORD_SIZE - 1
    jae NextChar
    mov ebx, wordCount
    shl ebx, 4                  ; EBX = wordCount * 16
    add ebx, ecx
    mov wordList[ebx], al
    inc ecx
    jmp NextChar

EndOfWord:
    cmp ecx, 3                  ; too short?  ignore it
    jb  ResetWord
    mov ebx, wordCount
    shl ebx, 4
    add ebx, ecx
    mov wordList[ebx], 0        ; end the word with 0
    inc wordCount

ResetWord:
    mov ecx, 0
    cmp wordCount, MAX_WORDS    ; list full?
    jae SplitDone
    cmp al, 0                   ; end of text?
    jne NextChar

SplitDone:
    ret
SplitWords ENDP


; --------------------------------------------------------------
;  LoadStats - reads the 5 statistics DWORDs from stats.dat
; --------------------------------------------------------------
LoadStats PROC
    mov edx, OFFSET statsFile
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je  NoStats                 ; first time: keep zeros
    mov fileHandle, eax

    mov eax, fileHandle
    mov edx, OFFSET statsData
    mov ecx, STATS_BYTES
    call ReadFromFile

    mov eax, fileHandle
    call CloseFile
NoStats:
    ret
LoadStats ENDP


; --------------------------------------------------------------
;  SaveStats - writes the 5 statistics DWORDs to stats.dat
; --------------------------------------------------------------
SaveStats PROC
    mov edx, OFFSET statsFile
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    je  SaveDone
    mov fileHandle, eax

    mov eax, fileHandle
    mov edx, OFFSET statsData
    mov ecx, STATS_BYTES
    call WriteToFile

    mov eax, fileHandle
    call CloseFile
SaveDone:
    ret
SaveStats ENDP

END main
