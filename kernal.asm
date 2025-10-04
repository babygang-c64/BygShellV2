//===============================================================
// KERNAL : C64 Kernal usefull calls and OS specific values
//===============================================================

#importonce

//---------------------------------------------------------------
// C64 Kernal usefull calls and OS specific values
//---------------------------------------------------------------

.label CHRGET = $0073
.label CHRGOT = $0079
.label IGONE = $0308    // BASIC processing hook
.label IEVAL = $030A

// Basic vectors

.label NEWSTT  = $A7AE
.label GONE3   = $A7E7
.label READY   = $a474
.label ERRORX  = $A43A
.label STRPRT  = $ab21
.label STRPRT4 = STRPRT+4
.label RESLST  = $A09E
.label CLR     = $A65E
.label COPY    = $aa52
.label PTRGET  = $B08B


// Kernal vectors

.label IIRQ = $0314

.label DSPP   = $EA13   // print character at screen pos
.label GETIN  = $FFE4
.label SETNAM = $FFBD
.label SETLFS = $ffba
.label SETMSG = $ff90
.label SECOND = $ff93
.label TKSA   = $ff96
.label acptr  = $ffa5
.label CIOUT  = $ffa8
.label UNTALK = $ffab
.label UNLSTN = $ffae
.label LISTEN = $ffb1
.label TALK   = $ffb4
.label READST = $ffb7
.label OPEN   = $ffc0
.label CLOSE  = $ffc3
.label CHKIN  = $ffc6
.label CHKOUT = $ffc9
.label CLRCHN = $ffcc
.label CHRIN  = $ffcf
.label CHROUT = $ffd2
.label LOAD   = $ffd5
.label SAVE   = $ffd8
.label STOP   = $ffe1
.label CLALL  = $ffe7
.label IECIN  = $ffa5
.label UNTLK  = $FFAB
.label PLOT   = $FFF0
.label CLEARSCREEN = $E544
.label SCNKEY = $FF9F

// Variables

.label COUNT         = $0B   // buffer length
.label STATUS        = $90   // IEC status
.label ST            = $90
.label DFLTI         = $99   // Default input device
.label DFLTO         = $9A   // Default output device
.label MEMIO         = $35
.label MEMSTD        = $37
.label MEMIOKERNAL   = $36
.label FORPNT        = $49
.label TXTPTR        = $7A
.label CURSOR_ONOFF  = 204
.label CURSOR_STATUS = 207
.label LGRNAM        = $B7
.label CURRDEVICE    = $BA  // Current device number
.label NDX           = $c6  // text buffer index
.label INDX          = $c8  // end of logical line for input (0-79)
.label LSXP          = $c9  // cursor Y input
.label LSTP          = $ca  // cursor X input
.label KEYPRESS      = $cb  // $3c, $3f, $01, $07 = space, r/s, enter, cursor down
.label BLNSW         = $cc  // cursor blink control
.label BLNON         = $cf  // cursor blink on flag
.label GDBLN         = $ce  // character under cursor
.label PNT           = $d1  // address of current screen line (logical line)
.label PNTR          = $d3  // logical X cursor position in line (0-79)
.label LNMX          = $d5  // max logical line length : 39 or 79
.label TBLX          = $d6  // cursor physical line number : 0-24
.label GDCOL         = 647  // character under cursor color
.label CURSOR_COLOR  = 646  // write color
.label SHFLAG        = $28d // shift,ctrl,c= flag, ctrl=4

// Definitions

.const MSG_ALL = $C0
.const MSG_NONE = $00
.const MSG_ERR = $80


// $FE00 : reset file info SETLFS
// sta $b8 // file #
// stx $ba // device #
// sty $b9 // secondary

// Keystrokes

.label BACKSPACE=$14
.label RIGHT=$1D
.label UP=$91
.label LEFT=$9D
.label DOWN=$11
.label INS=$94
.label CTRLA=1      // unix style home
.label CTRLE=5      // unix style end
.label RUNSTOP=$03
.label CTRLK=$0b    // master key
.label CTRLO=$0f    // end key
.label CTRLT=$14
.label CTRLU=$15    // home key
.label CTRLX=$18
.label CTRLS=$13
.label CTRLW=23
.label RETURN=13
.label RVSON=18
.label RVSOFF=146
.label WHITE=5
.label LIGHT_GRAY=155
