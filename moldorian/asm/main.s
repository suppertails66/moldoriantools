
.include "sys/sms_arch.s"
  ;.include "base/ram.s"
;.include "base/macros.s"
  ;.include "res/defines.s"

.rombankmap
  bankstotal 64
  banksize $4000
  banks 64
.endro

.emptyfill $FF

.background "moldorian.gg"

.unbackground $80000 $FFFFF

; free unused space
.unbackground $F400 $FFFF
.unbackground $7BA0 $7FDF
.unbackground $BFA8 $BFFF
.unbackground $F3A0 $FFFF
.unbackground $236D0 $23FFF

; free space from disused script strings

; name entry screen

.unbackground $2CB9 $2DBF
; messages
.unbackground $3270 $327B
.unbackground $3E0E $3E22
.unbackground $3EFD $3F3F
; katakana movement table (page removed from naming screen)
.unbackground $2F3A $3035
; katakana drawing routine
.unbackground $30DB $3125
; katakana toggle routine
.unbackground $320D $3224

; diacritics when scrolling dialogue
.unbackground $13E2 $1423

;===============================================
; Update header after building
;===============================================
.smstag

;===============================================
; constants
;===============================================

  ;=====
  ; vwf settings
  ;=====

;  .define vwfBaseTileOffset $20
;  .define vwfEndTileOffset $8C
  .define vwfBaseTileOffset $01
  .define vwfEndTileOffset $90
  .define numVwfTiles vwfEndTileOffset-vwfBaseTileOffset
  
  .define vwfFullWidthSpaceCharIndex $00
  .define vwfSlashIndex $06
  .define vwfGIndex $14
  .define vwfWindowRBorderIndex $1C
  .define vwfSpaceCharIndex $20
  .define vwfOpenQuoteIndex $55
  .define vwfCloseQuoteIndex $56
  ; 5-pixel space used to allow printed numbers to align in columns properly
  .define vwfNumSpaceCharIndex $60
  .define vwfDividerIndex $6B
  .define vwfTileBrIndex $94
  
  .define controlCodeStartIndex $90
  .define controlCodeLimitIndex $A0
  .define terminatorIndex $FF
  
  .define playerNamePixelWidthLimit 35

  ;=====
  ; misc
  ;=====
  
  .define screenVisibleW 20
  .define screenVisibleH 18
  .define screenVisibleX 3
  .define screenVisibleY 2

;===============================================
; memory
;===============================================

; longjmp parameters
.define longjmpA $C335
.define longjmpHL $C336

.define metatileScrollY $C43D
.define metatileScrollX $C43E

.define printBaseX $C4A9
.define printBaseY $C4AA
.define printAreaHW $C4AB
  .define printAreaW $C4AB
  .define printAreaH $C4AC
.define printSpeed $C4AD
.define printOffsetXY $C4AE
  .define printOffsetY $C4AE
  .define printOffsetX $C4AF

.define playerName $C833
  
.enum $D000
  vwfAllocationArray    ds numVwfTiles
                                ; MUST BE $100-ALIGNED!
                                ; bytes in this array are nonzero if
                                ; the corresponding tile has been
                                ; allocated for display
  vwfAllocationArrayPos db
;  stringPrintBuffer     ds $180
  curStringBank         db      ; most recent string's bank/ptr
  curStringPtr          dw      ; (for e.g. post-print centering calculations)
  vwfBuffer             ds bytesPerTile
  vwfBufferAllocatedTile db     ; nonzero determines tile VWF composition
                                ; buffer gets sent to
  vwfPixelOffset        db
  vwfNoResetFlag        db      ; if nonzero, do not reset vwfPixelOffset
                                ; to zero when starting to print a new
                                ; string
  vwfFullDeallocFlag    db      ; if nonzero, deallocating a VWF tile zeroes
                                ; its reference counter rather than
                                ; decrementing it
  vwfTransferCharSize   db
;  vwfTransferLeftSize   db
  vwfTransferRight_leftShift  db
  tilemapIsInC000       db      ; nonzero when a tilemap is present in
                                ; C000 for future restoration
  lastPrintOffsetX      db
  lastPrintOffsetY      db
  lastPrintBaseX        db
  lastPrintBaseY        db
  scratch               .dw
    scratchLo             db
    scratchHi             db
  newWindowDrawnFlag    db
  tilemapIsInC2D4       db      ; reserved for yes/no prompt
  stringIsPrinting      db
  vwfBufferPending      db
  introRemainingCounter db
  
.ende

;===============================================
; existing routines
;===============================================

.define readTileFromNametable $0F94
.define setUpPrintParams $FCE
.define drawWindowBase $FDD
.define sendRawTileToVdp $172
.define sendCharToNametable $F4E
.define sendTileToNametable $F64
.define printStdChar $12B7
.define waitForKey $1495
.define waitVblank $01CB
.define readControllerInput $00DA
.define runMenu $296B

; call with A == banknum and HL == routine pointer,
; and $C335 = A and $C336-C337 = HL for the actual call to the target routine.
; preserves return value in A.
; expensive, do not call in tight loops
.define longjmp $75E

.define countStringBytes $1A77

.define print8BitNum $1B03
.define printNum $1B30

.define saveStdTilemapToC000 $10F0
.define saveStdTilemap $10F9
.define writeStdTilemapFromC000 $114E
.define writeStdTilemap $115A

.define printStdString $13AD

.define loadRawExternalTiles $828

.define clearNametableArea $0456

;===============================================
; macros
;===============================================

.macro callExternal
  ld a,(mapperSlot1Ctrl)
  push af
  
    ld a,:\1
    ld (mapperSlot1Ctrl),a
    call \1
  
  pop af
  ld (mapperSlot1Ctrl),a
.endm

.macro doLongjmp
  ld a,:\1
  ld hl,\1
  call longjmp
.endm







;===============================================
; disable diacritics
;===============================================

.bank $00 slot 0
.org $12BF
.section "skip diacritic check" overwrite
  jp $1329
  ; auto-wrapping too (no, we need this)
;  jp $1358
.ends

; unbackground freed space
.unbackground $12C2 $1328
;.unbackground $12C2 $1357

;===============================================
; disable automatic line wrapping
;===============================================

.bank $00 slot 0
.org $1331
.section "no auto line wrapping" overwrite
  jp $133C
.ends

;===============================================
; generic call to slot1 routine
;===============================================

/*.bank $00 slot 0
.section "external call" free
  ; C = target bank
  ; HL = pointer
  callExternalRoutine:
    ld a,(mapperSlot1Ctrl)
    push af
    
      ld a,c
      ld (mapperSlot1Ctrl),a
      ld de,@done
      push de
      jp (hl)
    
    @done:
    pop af
    ld (mapperSlot1Ctrl),a
.ends */

;===============================================
; flag when a tilemap is saved to C000
; pending future restoration
;===============================================

.bank $00 slot 0
.org $10F1
.section "flag on C000 tilemap save 1" overwrite
  call flagOnC000TilemapSave
.ends

.bank $00 slot 0
.section "flag on C000 tilemap save 2" free
  flagOnC000TilemapSave:
  ;  inc (tilemapIsInC000)
    push af
      ld a,$FF
      ld (tilemapIsInC000),a
    
    ; make up work
    @done:
    pop af
    ld de,$C000
    ret
  
  flagOnC000TilemapRestore:
    push af
    
      push hl
;      push de
        ; deallocate restored area
        ld a,($C000)      ; x
        ld h,a
        ld a,($C001)      ; y
        ld l,a
        ld a,($C002)      ; w
        ld d,a
        ld a,($C003)      ; h
        ld e,a
        call deallocVwfTileArea
;      pop de
      pop hl
    
      ; flag no content in C000
      xor a
      ld (tilemapIsInC000),a
      jr flagOnC000TilemapSave@done
    
.ends

.bank $00 slot 0
.org $114F
.section "flag on C000 tilemap restore 1" overwrite
  call flagOnC000TilemapRestore
.ends

;.bank $00 slot 0
;.section "flag on C000 tilemap restore 2" free
;.ends

;===============================================
; vwf tile allocation
;===============================================

.bank $00 slot 0
.section "vwf tile allocation 1a" free
  ; returns a free VWF tile index in A
  ;
  ; NOTE: loops infinitely if no tiles free
  allocVwfTile:
;    callExternal allocVwfTile_ext
    ld a,(mapperSlot1Ctrl)
    push af
    
      ld a,:allocVwfTile_ext
      ld (mapperSlot1Ctrl),a
      call allocVwfTile_ext
      ld (scratchLo),a
    
    pop af
    ld (mapperSlot1Ctrl),a
    
    ld a,(scratchLo)
    ret
.ends

.slot 1
.section "vwf tile allocation 1b" superfree
  ; returns a free VWF tile index in A
  ;
  ; NOTE: loops infinitely if no tiles free
  allocVwfTile_ext:
    push hl
    push de
    
      ld h,>vwfAllocationArray
      ld a,(vwfAllocationArrayPos)
      ld l,a
      ; save starting search point to E
      ld e,a
      ld d,$00  ; flag: set after garbage collection
      @searchLoop:
        
        ; preincrement (saves a little time)
        inc l
        ; wrap around at end of array
        ld a,l
        cp numVwfTiles
        jr c,+
          ld l,$00
;          ld a,l
        +:
        
        ; skip over tile ranges that must be preserved
        
        ; tiles $19-$1F (menus and cursors)
        ; 1B and 1C are diacriticaled border windows, which we don't need
        cp $1B-vwfBaseTileOffset
        jr nc,+
        cp $19-vwfBaseTileOffset
        jr c,+
          ld l,$1B-vwfBaseTileOffset
          jr @prohibitedRangesChecked
        +:
        cp $20-vwfBaseTileOffset
        jr nc,+
        cp $1D-vwfBaseTileOffset
        jr c,+
          ld l,$20-vwfBaseTileOffset
          jr @prohibitedRangesChecked
        +:
        ; "dash" (used as divider in menus)
        cp $60-vwfBaseTileOffset
        jr nz,+
          ld l,$61-vwfBaseTileOffset
          jr @prohibitedRangesChecked
        +:
        ; 8C = left border w/ cursor
        ; 8D = shadow
        cp $8D-vwfBaseTileOffset
        jr nc,+
        cp $8C-vwfBaseTileOffset
        jr c,+
          ld l,$8E-vwfBaseTileOffset
        +:
        
        @prohibitedRangesChecked:
        
        ; check if second loop done (D nonzero)
        ld a,d
        or a
        jr z,+
          ; check if current index == startindex
          ld a,e
          cp l
          jr nz,+
            @fullLoad:
            
            ; uh-oh: we ran garbage collection, but there are still no tiles
            ; available. there's nothing we can do to actually fix the problem
            ; at this point, so we just declare all tiles free and cause some
            ; visual corruption so the new stuff can print.
;            call freeAllVwfTiles
            
            ; actually, just overwrite the next tile in the sequence and
            ; re-run this whole procedure next time we print something.
            ; will cause considerable slowdown but less noticeable corruption
            jr @done
            
            ; TODO: possible last resort: search for blank/duplicate tiles
            ; or blank VWF tiles outside of current window
        +:
        
        ; if allocation array is totally full (we've looped to our starting
        ; point), run garbage collection and hope for the best
        ; (note: actually can run when array is one short of full. same deal.)
        ld a,e
        cp l    ; compare current pos to initial
        jr nz,+
          call collectVwfGarbage
          
          ; flag D so that, if no tiles are available even after
          ; garbage collection, we can detect a second loop
          inc d
        +:
        
        @checkCurrentTile:
        ld a,(hl)
        or a
        jr nz,@searchLoop
      
      @done:
      
      ; mark tile as allocated (nonzero)
;      inc (hl)
      ld a,$FF
      ld (hl),a
      
      ; save search pos
      ld a,l
      ld (vwfAllocationArrayPos),a
      
      ; add offset to actual tile index
      add a,vwfBaseTileOffset
    
    pop de
    pop hl
    ret
    
    
.ends

.bank $00 slot 0
.section "vwf tile allocation 1c" free
  ; fully reset the VWF allocation buffer.
  ; clears existing buffer contents, then reads all visible tiles from VDP and
  ; marks those actually in use as allocated.
  ; obviously has considerable overhead, so this routine's use should be
  ; minimized as much as possible.
  collectVwfGarbage:
    callExternal collectVwfGarbage_ext
    ret
.ends

.slot 1
.section "vwf tile allocation 1d" superfree
  ; fully reset the VWF allocation buffer.
  ; clears existing buffer contents, then reads all visible tiles from VDP and
  ; marks those actually in use as allocated.
  ; obviously has considerable overhead, so this routine's use should be
  ; minimized as much as possible.
  collectVwfGarbage_ext:
    ; clear buffer
    call freeAllVwfTiles
    
    push hl
    push de
    push bc
      
      ;=====
      ; evaluate visible screen area and mark all used VWF tiles as
      ; allocated
      ;=====
      
      ld h,screenVisibleX
      ld l,screenVisibleY
      ld d,screenVisibleW
      ld e,screenVisibleH+1     ; the +1 here fixes the intro, which
                                ; prints strings justpast  the bottom of the
                                ; screen and scrolls them into visibility
      
      ; vwfFullDeallocFlag nonzero with high bit clear
      ;   = increment reference counter
      ld a,$01
      ld (vwfFullDeallocFlag),a
        ; allocate area
        call deallocVwfTileArea
      xor a
      ld (vwfFullDeallocFlag),a
    
      ;=====
      ; if VWF tiles have been temporarily hidden behind another tilemap,
      ; mark them as allocated
      ;=====
      
      call markHiddenVwfTilesAllocated
    
    @done:
    pop bc
    pop de
    pop hl
    
    ret
.ends

.bank $00 slot 0
.section "mark hidden vwf tiles 1" free
  markHiddenVwfTilesAllocated:
    
    ld a,(tilemapIsInC000)
    or a
    jr z,+
      @hiddenC000TilemapCheck:
      
      ld a,($C000+2)    ; window w
      ld d,a
      ld a,($C000+3)    ; window h
      ld e,a
      ld hl,$C000+4     ; tile data start
    
      call checkHiddenVwfTiles
    +:
    
    ld a,(tilemapIsInC2D4)
    or a
    jr z,+
      @hiddenC2D4TilemapCheck:
      
      ld a,($C2D4+2)    ; window w
      ld d,a
      ld a,($C2D4+3)    ; window h
      ld e,a
      ld hl,$C2D4+4     ; tile data start
    
      call checkHiddenVwfTiles
    +:
      
    @done:
    ret
.ends

.bank $00 slot 0
.section "mark hidden vwf tiles 2" free
  ; HL = data pointer
  ; DE = w/h
  checkHiddenVwfTiles:
      
      @yLoop:
        
        ; save W
        push de
          
          @xLoop:
            ; get high nametable byte (which is stored second for
            ; some reason)
            inc hl
            ld a,(hl)
            
            ; if bit 0 of high nametable byte is set, this tile is in the
            ; second half of the pattern table and we don't care about it
            rr a
            jr c,+
              dec hl
              ; get low nametable byte
              ld a,(hl)
              inc hl
              
              ; ignore tiles < start index
              cp vwfBaseTileOffset
              jr c,+
                
                ; ignore tiles > end index
                cp vwfEndTileOffset
                jr nc,+
                
                  ; mark the tile as allocated
  ;                    call freeVwfTile
                  @hiddenTileFound:
                  sub vwfBaseTileOffset
                  ld c,a
                  ld b,>vwfAllocationArray
                  ld a,$FF
                  ld (bc),a
            
            +:
            inc hl
            dec d
            jr nz,@xLoop
            
          @xLoopDone:
        
        ; restore W
        pop de
        
        ; move to next Y
        dec e
        jr nz,@yLoop
    ret
.ends

.bank $00 slot 0
.section "vwf tile allocation 2" free
  ; marks a VWF tile as free
  ;
  ; A = tile index
  freeVwfTile:
    push hl
    
      sub vwfBaseTileOffset
      ld l,a
      ld h,>vwfAllocationArray
      
      ; if full deallocation flag zero, zero reference counter
      ld a,(vwfFullDeallocFlag)
      or a
      jr nz,@incReferenceCounterCheck
        ld (hl),$00
        jr @done
        
      ; if nonzero and high bit clear, increment reference counter
      @incReferenceCounterCheck:
      jp p,@decReferenceCounter
        inc (hl)
        jr @done
      
      ; if high bit set, decrement reference counter
      @decReferenceCounter:
        dec (hl)
    
    @done:
    pop hl
    ret
.ends

.bank $00 slot 0
.section "vwf tile allocation 3" free
  ; marks all VWF tiles as free
  freeAllVwfTiles:
    push hl
    push bc
      
      ld b,numVwfTiles
      ld hl,vwfAllocationArray
      -:
        ld (hl),$00
        inc l
        djnz -
    
    pop bc
    pop hl
    ret
.ends

.bank $00 slot 0
.section "vwf tile allocation 4a" free
  ; reads the nametable in the specified coordinates and deallocates all
  ; VWF tiles contained within
  ;
  ; HL = screen-local tile x/y
  ; DE = box w/h
  deallocVwfTileArea:
    callExternal deallocVwfTileArea_ext
    ret
.ends

.slot 1
.section "vwf tile allocation 4b" superfree
  deallocVwfTileArea_ext:
    push hl
    push de
      
      @yLoop:
        
        ; save W
        push hl
        push de
          
          @xLoop:
            ; read tile using readTileFromNametable
            push de
              call readTileFromNametable
              
              ; if bit 0 of high nametable byte is set, this tile is in the
              ; second half of the pattern table and we don't care about it
              rr d
              jr c,+
                ld a,e
                
                ; ignore tiles < start index
                cp vwfBaseTileOffset
                jr c,+
                  
                  ; ignore tiles > end index
                  cp vwfEndTileOffset
                  jr nc,+
                  
                    ; free the tile
                    call freeVwfTile
                  
              +:
            pop de
            
            ; move to next X
            inc h
            dec d
            jr nz,@xLoop
            
          @xLoopDone:
        
        ; restore W
        pop de
        pop hl
        
        ; move to next Y
        inc l
        dec e
        jr nz,@yLoop
    
    @done:
    pop de
    pop hl
  ret
.ends

;===============================================
; do vwf tile deallocation where needed
;===============================================

/*.bank $00 slot 0
.section "metatile to tile coords" free
  ; HL = metatile X/Y
  ; DE = metatile W/H
  ;
  ; returns converted values in same registers
  metatileToTileCoords:
    sla l
    sla h
    sla d
    sla e
    ret
.ends */

  ;=====
  ; redrawMetaileArea
  ;=====

  .bank $00 slot 0
  .org $0AF3
  .section "vwf tile deallocation redrawMetaileArea 1" overwrite
    call redrawMetatileArea_vwfDealloc
  .ends

  .bank $00 slot 0
  .section "vwf tile deallocation redrawMetaileArea 2" free
    redrawMetatileArea_vwfDealloc:
      push de
      push hl
      
        ; convert metatile coordinates to tile coordinates
;        call metatileToTileCoords
        sla l
        sla h
        sla d
        sla e
        
        ; deallocate area
;        ld a,$FF
;        ld (vwfFullDeallocFlag),a
          call deallocVwfTileArea
;        xor a
;        ld (vwfFullDeallocFlag),a
        
      pop hl
      pop de
      
      ; make up work
      ld a,(metatileScrollX)
      ret
  .ends

  ;=====
  ; drawWindowBase
  ;=====

  .bank $00 slot 0
  .org $0FE1
  .section "vwf tile deallocation drawWindowBase 1" overwrite
    call drawWindowBase_vwfDealloc
  .ends

  .bank $00 slot 0
  .section "vwf tile deallocation drawWindowBase 2" free
    drawWindowBase_vwfDealloc:
;      push hl
      push de
      push bc
      
        ; get window coords
        ld a,(printBaseX)
        ld h,a
        ld a,(printBaseY)
        ld l,a
        
        ; get window area
        ld a,(printAreaW)
        ld d,a
        ld a,(printAreaH)
        ld e,a
        
        ; deallocate area
        call deallocVwfTileArea
        
        ; ensure hidden tiles are preserved
        call markHiddenVwfTilesAllocated
      
      pop bc
      pop de
;      pop hl
    
      ld a,$FF
      ld (newWindowDrawnFlag),a
      
      ; make up work
      ld hl,$C44D
      ret
  .ends

  ;=====
  ; clearNametableArea
  ;=====

  .bank $00 slot 0
  .org $0456
  .section "vwf tile deallocation clearNametableArea 1" overwrite
    jp clearNametableArea_vwfDealloc
  .ends

  .bank $00 slot 0
  .section "vwf tile deallocation clearNametableArea 2" free
    ; BC = w/h
    ; DE = nametable data
    ; HL = x/y
    clearNametableArea_vwfDealloc:
      ; make up work
      push bc
      push de
      push hl
      
;      ld a,$FF
;      ld (vwfFullDeallocFlag),a
      push de
        ; deallocate area
        push bc
        pop de
        call deallocVwfTileArea
      pop de
;      xor a
;      ld (vwfFullDeallocFlag),a
      
      ; make up work
      jp $0459
  .ends

/*  ;=====
  ; saveStdTilemap (actually an "allocation" but w/e)
  ;
  ; we need to increment the reference counter of any affected VWF tile,
  ; since it may be restored later
  ;=====

  .bank $00 slot 0
  .org $1117
  .section "vwf tile deallocation saveStdTilemap 1" overwrite
    call saveStdTilemap_vwfAlloc
  .ends

  .bank $00 slot 0
  .section "vwf tile deallocation saveStdTilemap 2" free
    saveStdTilemap_vwfAlloc:
      ; make up work
      push de
      pop ix
      
      ; DE = w/h
      push bc
      pop de
      
      ; nonzero with high bit clear = increment reference counter
      ld a,$01
      ld (vwfFullDeallocFlag),a
        ; allocate area
        call deallocVwfTileArea
      xor a
      ld (vwfFullDeallocFlag),a
      
      ret
  .ends

  ;=====
  ; writeStdTilemap
  ;=====

  .bank $00 slot 0
  .org $116C
  .section "vwf tile deallocation writeStdTilemap 1" overwrite
    call writeStdTilemap_vwfDealloc
  .ends

  .bank $00 slot 0
  .section "vwf tile deallocation writeStdTilemap 2" free
    writeStdTilemap_vwfDealloc:
;      ld a,$FF
;      ld (vwfFullDeallocFlag),a
;      xor a
;      ld (vwfFullDeallocFlag),a
      
      ; make up work
      push de
      pop ix
      
      ; DE = w/h
      push bc
      pop de
      
      ; deallocate area
      call deallocVwfTileArea
      
      ret
  .ends */

  ;=====
  ; yes/no prompt
  ;=====

  .bank $00 slot 0
  .org $11E5
  .section "yes/no prompt use flagging 1" overwrite
    call flagYesNoPromptUse
  .ends

  .bank $00 slot 0
  .section "yes/no prompt use flagging 2" free
    flagYesNoPromptUse:
      ld a,$FF
      ld (tilemapIsInC2D4),a
      
      ; make up work
      call saveStdTilemap
      ret
  .ends

  .bank $00 slot 0
  .org $1223
  .section "yes/no prompt use flagging 3" overwrite
    call flagYesNoPromptUnuse
  .ends

  .bank $00 slot 0
  .section "yes/no prompt use flagging 4" free
    flagYesNoPromptUnuse:
      xor a
      ld (tilemapIsInC2D4),a
      
      ; make up work
      call writeStdTilemap
      ret
  .ends

;===============================================
; vwf font
;===============================================

.include "out/font/font.inc"

/*.macro sendVwfBufferIfNeeded
  ld a,(stringIsPrinting)
  or a
  jr z,+
  ld a,(printSpeed)
  or a
  jr z,++
    +:
    call sendVwfBuffer
  ++:
.endm */

.slot 1
.section "font lookups" align $4000 superfree
  ; must be $100-aligned but WLA-DX can't enforce this without a separate
  ; section which we can't make because then it couldn't be made to be part
  ; of the superfree section the code that accesses it is in.
  ; so we'll just hope we don't have to do this more than once!!
  fontSizeTable:
    .incbin "out/font/sizetable.bin" FSIZE fontCharLimit
    .define numFontChars fontCharLimit-1

  fontRightShiftBankTbl:
    .db :font_rshift_00
    .db :font_rshift_01
    .db :font_rshift_02
    .db :font_rshift_03
    .db :font_rshift_04
    .db :font_rshift_05
    .db :font_rshift_06
    .db :font_rshift_07
  fontRightShiftPtrTbl:
    .dw font_rshift_00
    .dw font_rshift_01
    .dw font_rshift_02
    .dw font_rshift_03
    .dw font_rshift_04
    .dw font_rshift_05
    .dw font_rshift_06
    .dw font_rshift_07
  fontLeftShiftBankTbl:
    .db :font_lshift_00
    .db :font_lshift_01
    .db :font_lshift_02
    .db :font_lshift_03
    .db :font_lshift_04
    .db :font_lshift_05
    .db :font_lshift_06
    .db :font_lshift_07
  fontLeftShiftPtrTbl:
    .dw font_lshift_00
    .dw font_lshift_01
    .dw font_lshift_02
    .dw font_lshift_03
    .dw font_lshift_04
    .dw font_lshift_05
    .dw font_lshift_06
    .dw font_lshift_07
  
  charANDMasks:
    .db $00,$80,$C0,$E0,$F0,$F8,$FC,$FE,$FF
  
  ; C = target char
  printVwfChar:
  
    ; handle tile break
    ld a,c
    cp vwfTileBrIndex
    jr nz,+
      call sendVwfBufferIfPending
      call resetVwf
      ld hl,printOffsetX
      inc (hl)
      jp @done
    +:
    
    ; very special hack to free up VRAM space in shop windows:
    ; the full-width dash character (mapped to $6B in VWF font)
    ; is remapped directly to index $60 in the nametable (which is
    ; reserved and kept static for this purpose).
    ; all vwf operations are skipped; the character is sent directly to
    ; the nametable.
    ; this full-dash should never be used for anything except horizontal
    ; lines.
    cp vwfDividerIndex
    jr nz,+
      ; x/y pos (accounting for window border)
      ld a,(printBaseX)
      inc a
      ld h,a
      ld a,(printBaseY)
      inc a
      ld l,a
      ld de,(printOffsetXY)
      add hl,de
      
      ; tile $0060
      ld de,$0060
      
      call sendCharToNametable
      
      ld hl,printOffsetX
      inc (hl)
      jp @done
    +:
    
    ;=====
    ; reset buffer if window has moved or print x/y offset has changed,
    ; which we interpret to mean a new string (sequence) has been
    ; started.
    ; FIXME: no reset will occur if a new character is drawn at the
    ; exact x/y position of the previous one. does this matter?
    ;=====
  
    ; if target char is invalid, ignore
;    ld a,c
    cp numFontChars
    jp nc,@done
    
    ; if local print x or y has changed from last print,
    ; reset buffer
    ld a,(printOffsetX)
    ld hl,lastPrintOffsetX
    cp (hl)
    jr z,+
      -:
      call resetVwf
      jr @resetChecksDone
    +:
      ld a,(printOffsetY)
      ld hl,lastPrintOffsetY
      cp (hl)
      jr nz,-
    ++:
    
    ; if window base x or y has changed from last print,
    ; reset buffer
    ld a,(printBaseX)
    ld hl,lastPrintBaseX
    cp (hl)
    jr z,+
      -:
      call resetVwf
      jr @resetChecksDone
    +:
      ld a,(printBaseY)
      ld hl,lastPrintBaseY
      cp (hl)
      jr nz,-
    ++:
    
    ; if new window has been drawn since last print, reset buffer
    ld a,(newWindowDrawnFlag)
    jr z,+
      call resetVwf
      xor a
      ld (newWindowDrawnFlag),a
    +:
    
    @resetChecksDone:
    
    ; vwf composition works like this:
    ; 1. OR left part of new character into composition buffer using
    ;    appropriate entry from right-shifted character tables.
    ;    (if vwfPixelOffset is zero, we can copy instead of ORing)
    ; 2. send composition buffer to VDP (allocating tile if not already done)
    ; 3. if composition buffer was filled, clear it.
    ; 4. if entire character has already been copied, we're done.
    ; 5. copy right part of new character directly to composition buffer using
    ;    appropriate entry from left-shifted character tables.
    ; 6. send composition buffer to VDP (allocating tile)
    
    ;=====
    ; look up size of target char
    ;=====
    
    ld h,>fontSizeTable
    ld a,c
    ld l,a
    
    ; get width
    ld a,(hl)
    ; if width is zero, we have nothing to do
    or a
    jp z,@done
    
    ld (vwfTransferCharSize),a
    
    ;=====
    ; compute size of left/right transfers
    ;=====
    
    ; B = width of character
/*    ld b,a
    
    ; get count of pixels remaining in buffer
    ld a,(vwfPixelOffset)
    sub $08
    neg
    
    ; if remaining pixels >= width of transfer, only left transfer needed
    cp b
    jp m,@bothTransfers
    @leftTransferOnly:
      ld a,b
      ld (vwfTransferLeftSize),a
      ld (vwfTransferLeftSize),$00
      jr +
    @bothTransfers:
      ld (vwfTransferLeftSize),a
      sub b
      ld (vwfTransferRightSize),a
    +: */
    
    ;=====
    ; transfer 1: XOR left part of target char with buffer
    ;=====
    
    @transfer1:
    
    ; if char is space, no transfer needed
    ; (or it wouldn't be, except what if nothing else has been printed
    ; to the buffer yet? then the part we skipped won't get the background
    ; color)
;    ld a,c
;    cp vwfSpaceCharIndex
;    jr z,@transfer1Done
    
      push bc
        
        ;=====
        ; look up character data
        ;=====
        
        ; B = bank
        ld a,(vwfPixelOffset)
        ld e,a
        ld d,$00
        ld hl,fontRightShiftBankTbl
        add hl,de
        ld b,(hl)
        
        ; HL = pointer to char table base
        ld hl,fontRightShiftPtrTbl
        ; pixel offset *= 2
        sla e
        rl d
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ; add offset to actual char
        ld e,c
        ld d,$00
        ; * 32 for tile offset
        .rept 5
          sla e
          rl d
        .endr
        add hl,de
        
        ; can copy to buffer instead of ORing if pixel offset is zero
        ld a,(vwfPixelOffset)
        or a
        jr nz,+
          ld de,vwfBuffer
          call copyToTileBuffer
          jr @dataTransferred
        +:
        
        ; look up AND mask to remove low bits
        push hl
          ld hl,charANDMasks
          ld a,(vwfPixelOffset)
          ld e,a
          ld d,$00
          add hl,de
          ld c,(hl)
        pop hl
        
        ;=====
        ; OR to buffer
        ;=====
        
        ld de,vwfBuffer
        call orToTileBuffer
        
        @dataTransferred:
        
      pop bc
      
      ; check if border needs to be added to tile
      call checkBorderTransfer
    
      ;=====
      ; send modified buffer
      ;=====
;       call sendVwfBuffer
    
    @transfer1CompositionDone:
    
    ; determine right transfer shift amount
    ld a,(vwfPixelOffset)
    ld b,a
    sub $08
    neg
    ld (vwfTransferRight_leftShift),a
    
    ; advance vwfPixelOffset by transfer size
;    ld a,b
;    ld b,a
    ld a,(vwfTransferCharSize)
    add a,b
    
    cp $08
    jr nc,+
      ; if position in VWF buffer < 8, no second transfer needed
      
      ; send modified buffer if print speed nonzero (printing character-
      ; by-character); if text printing is instant, this just wastes time.
      ; also send if only printing a single character.
      push af
;        sendVwfBufferIfNeeded
        ld a,$FF
        ld (vwfBufferPending),a
        
        ; if printing independent character rather than entire string,
        ; do buffer send
        ld a,(stringIsPrinting)
        or a
        jr z,++
        ; if print speed is zero (instant), don't do buffer send
        ld a,(printSpeed)
        or a
        jr z,+++
          ++:
          call sendVwfBuffer
        +++:
      pop af
      
      ld (vwfPixelOffset),a
      jr @done
    +:
    jr nz,+
      ; if we filled the VWF buffer exactly to capacity, then we need to
      ; send it, but don't need a right transfer or new tile allocation.
      ; instead, we reset the buffer in case more text is added.
      
      ; send modified buffer
      call sendVwfBuffer
      
      ; reset buffer
;      xor a
;      ld (vwfPixelOffset),a
      call resetVwf
      ; move to next x-pos
      ld a,(printOffsetX)
      inc a
      ld (printOffsetX),a
      jr @done
    +:
    
    ;=====
    ; buffer filled, and second transfer needed
    ;=====
    
    push af
      ;send modified buffer
      call sendVwfBuffer
      
      ; we'll add content for the second transfer, so set the
      ; buffer pending flag
      ld a,$FF
      ld (vwfBufferPending),a
    pop af
    
    and $07
    ld (vwfPixelOffset),a
    ; new allocation needed
    xor a
    ld (vwfBufferAllocatedTile),a
    ; move to next x-pos
    ld hl,printOffsetX
    inc (hl)
    
    ;=====
    ; transfer 2: copy right part of character to buffer
    ;=====
    
    @transfer2:
    
    ; transfer size of zero = skip
;    ld a,(vwfTransferRightSize)
;    jr z,@transfer2Done
    
    ; if char is space, no transfer needed
    ; (or it wouldn't be, except... something, I've already forgotten
    ; what this breaks. but it definitely breaks something)
;    ld a,c
;    cp vwfSpaceCharIndex
;    jr z,@transfer2Done
    
      ;=====
      ; look up character data
      ;=====
      
      ; B = bank
      ld a,(vwfTransferRight_leftShift)
      ld e,a
      ld d,$00
      ld hl,fontLeftShiftBankTbl
      add hl,de
      ld b,(hl)
      
      ; HL = pointer to char table base
      ld hl,fontLeftShiftPtrTbl
      ; pixel offset *= 2
      sla e
      rl d
      add hl,de
      ld a,(hl)
      inc hl
      ld h,(hl)
      ld l,a
      ; add offset to actual char
      ld e,c
      ld d,$00
      ; * 32 for tile offset
      .rept 5
        sla e
        rl d
      .endr
      add hl,de
      
      ;=====
      ; copy to buffer
      ;=====
      
      ld de,vwfBuffer
;      ld a,b
      call copyToTileBuffer
      
      ; check if border needs to be added to tile
      call checkBorderTransfer
    
      ;=====
      ; send modified buffer
      ;=====
;      call sendVwfBuffer

      ; transfer only needed here for single-character print;
      ; string prints will handle terminating tile themselves
      ld a,(stringIsPrinting)
      or a
      jr nz,+
        call sendVwfBuffer
;        jr ++
      +:
;        ld a,$FF
;        ld (vwfBufferPending),a
;      ++:
    
    @transfer2Done:
    
    ;=====
    ; finish up
    ;=====
    
    @done:
    
      ;=====
      ; update last-printed data
      ;=====
      
      ld a,(printOffsetX)
      ld (lastPrintOffsetX),a
      ld a,(printOffsetY)
      ld (lastPrintOffsetY),a
      
      ld a,(printBaseX)
      ld (lastPrintBaseX),a
      ld a,(printBaseY)
      ld (lastPrintBaseY),a
    
    ret
  
  sendVwfBuffer:
    push bc
      
      ;=====
      ; allocate tile for buffer if unallocated
      ;=====
      ld a,(vwfBufferAllocatedTile)
      ld c,a    ; C will be zero if tile is newly allocated,
                ; so we know to send it to the nametable later
      or a
      jr nz,+
        call allocVwfTile
        ld (vwfBufferAllocatedTile),a
      +:
      
      ; HL = dst tile index
      ld l,a
      ld h,$00
      ; DE = src data
      ld de,vwfBuffer
        call sendRawTileToVdp
      
      ;=====
      ; if tile newly allocated, send to nametable
      ;=====
      ld a,c    ; check if initial tile num was zero
      or a
      jr nz,+
      
        ;=====
        ; send to nametable
        ;=====
        
        ; x/y pos (accounting for window border)
        ld a,(printBaseX)
        inc a
        ld h,a
        ld a,(printBaseY)
        inc a
        ld l,a
        ld de,(printOffsetXY)
        add hl,de
        
        ; tile index
        ld a,(vwfBufferAllocatedTile)
        ld e,a
        ld d,$00
        
        call sendCharToNametable
      +:
      
      ; reset buffer pending flag
      xor a
      ld (vwfBufferPending),a
    
    pop bc
    ret
  
  checkBorderTransfer:
    ;=====
    ; check if we printed into the tile containing the right border
    ; of the window. if so, we need to draw the border onto the
    ; tile.
    ; (done primarily to allow us to "cheat" so we can squeeze
    ; seven-character party member names into what was supposed to be
    ; a four-tile space)
    ;=====
    
    ld a,(printOffsetX)
    inc a
    inc a
    ld hl,printAreaW
    cp (hl)
    jr nz,+
      push bc
        ; border is 3px on right side of tile
        ld c,$F8
        ld b,:font_rshift_00
        ld de,vwfBuffer
        ld hl,font_rshift_00+(bytesPerTile*vwfWindowRBorderIndex)
        call orToTileBuffer
      pop bc
    +:
    
    ret
    
.ends

  
.bank 0 slot 0
.section "string tile width" free
  findStringTileWidth:
    ; HL = ptr
    ; return width in C
    
    call findStringPixelWidth
    
    ; C = pixel width
    
    ; divide by 8
    ld a,c
    sra c
    sra c
    sra c
    
    ;  if C is not divisible by 8, add 1 to result
    and $07
    jr z,+
      inc c
    +:
    
    ret
.ends
    
.bank 0 slot 0
.section "string pixel width" free
  findStringPixelWidth:
    
    ; HL = string ptr
    ; return width in C (8-bit is fine)
    
    push hl
    push de
    
      ld c,$00
      ld d,>fontSizeTable
      
      -:
        ; ignore control codes
        ld a,(hl)
        cp terminatorIndex
        jr z,@done
        cp controlCodeStartIndex
        jr c,+
        cp controlCodeLimitIndex
        jr nc,++
          +:
          
          ; get width from table
          ld e,a
          ld a,(mapperSlot1Ctrl)
          push af
            ld a,:fontSizeTable
            ld (mapperSlot1Ctrl),a
            ld a,(de)
            
            ; add to current count
            add a,c
            ld c,a
          pop af
          ld (mapperSlot1Ctrl),a
        ++:
        
        inc hl
        jr -
    
    @done:
    pop de
    pop hl
    ret
.ends

/*.bank 0 slot 0
.section "string pixel width" free
  findStringPixelWidth:
    callExternal findStringPixelWidth_ext
    ret
.ends

.bank 0 slot 0
.section "string tile width" free
  findStringTileWidth:
    callExternal findStringTileWidth_ext
    ret
.ends */

.bank 0 slot 0
.section "reset vwf" free
  resetVwf:
    xor a
    
    ; reset pixel x-pos
    ld (vwfPixelOffset),a
    ld (vwfBufferAllocatedTile),a
    
    ; clear tile composition buffer
    ld hl,vwfBuffer
    ld b,bytesPerTile
    -:
      ld (hl),a
      inc hl
      djnz -
    ret
.ends

.bank 0 slot 0
.section "vwf xor" free
  ; B = src data bank
  ; C = AND mask for each existing byte in buffer
  ; DE = dst pointer
  ; HL = src data pointer
  orToTileBuffer:
    ld a,(mapperSlot1Ctrl)
    push af
      
      ld a,b
      ld (mapperSlot1Ctrl),a
      ld b,bytesPerTile
      -:
        ld a,(de)
        and c
        or (hl)
        ld (de),a
        
        inc hl
        inc de
        djnz -
      
    pop af
    ld (mapperSlot1Ctrl),a
    ret
.ends

.bank 0 slot 0
.section "vwf copy" free
  ; B = src data bank
  ; DE = dst pointer
  ; HL = src data pointer
  copyToTileBuffer:
    ld a,(mapperSlot1Ctrl)
    push af
      
      ld a,b
      ld (mapperSlot1Ctrl),a
      ld bc,bytesPerTile
      ldir
      
    pop af
    ld (mapperSlot1Ctrl),a
    ret
.ends

.bank 0 slot 0
.org $13A1
.section "do vwf 1" overwrite
  ld c,a
  call doVwf
  nop
  nop
  nop
.ends

.bank 0 slot 0
.section "do vwf 2" free
  doVwf:
    ld a,(mapperSlot1Ctrl)
    push af
      
      ; C = target char index
      ld a,:printVwfChar
      ld (mapperSlot1Ctrl),a
      call printVwfChar
      
    pop af
    ld (mapperSlot1Ctrl),a
    ret
.ends

  ;=====
  ; string print updates
  ;=====

  .bank $00 slot 0
  .section "new string print" free
    printString:
      push af
        ld a,$FF
        ld (stringIsPrinting),a
      pop af
      
      call oldPrintString
      
/*      ; if print speed is 0 and VWF pixel offset nonzero, we need to
      ; send the remaining buffer content
      ld a,(printSpeed)
      or a
      jr nz,+
      ld a,(vwfPixelOffset)
      or a
      jr z,+
;        ld (longjmpA),a
;        ld (longjmpHL),hl
;        doLongjmp sendVwfBuffer
        callExternal sendVwfBuffer
      +: */
      
      ; the last tile may not have been send if it wasn't completely full,
      ; so do that now if necessary
      push hl
        call sendVwfBufferIfPending
      pop hl
      
      xor a
      ld (stringIsPrinting),a
      
      ret
  .ends

  .bank $00 slot 0
  .section "send vwf buffer if pending" free
    sendVwfBufferIfPending:
      ld a,(vwfBufferPending)
      or a
      jr z,+
        callExternal sendVwfBuffer
      +:
      ret
  .ends

  ;=====
  ; send VWF buffer if pending when a [wait] op is encountered
  ;=====
  
  .bank $00 slot 0
  .org $136E
  .section "send vwf buffer if pending (wait op) 1" overwrite
    call sendVwfOnWaitOp
  .ends
  
  .bank $00 slot 0
  .section "send vwf buffer if pending (wait op) 2" free
    sendVwfOnWaitOp:
      call sendVwfBufferIfPending
      
      ; make up work
      jp $1495
  .ends

  ;=====
  ; send VWF buffer if pending when a [br] op is encountered
  ;=====
  
  .bank $00 slot 0
  .org $135D
  .section "send vwf buffer if pending (br op) 1" overwrite
    jp sendVwfOnBrOp
  .ends
  
  .bank $00 slot 0
  .section "send vwf buffer if pending (br op) 2" free
    sendVwfOnBrOp:
      call sendVwfBufferIfPending
      
      xor a
      ld (printOffsetX),a
      
      ; make up work
      jp $1361
  .ends

  ;=====
  ; send VWF buffer if pending and waiting for next character in
  ; text with nonzero print speed
  ;=====
  
  .bank $00 slot 0
  .org $137B
  .section "send vwf buffer if pending (non-instant text wait) 1" overwrite
    jp sendVwfOnSlowTextWait
  .ends
  
  .bank $00 slot 0
  .section "send vwf buffer if pending (non-instant text wait) 2" free
    sendVwfOnSlowTextWait:
      push hl
      push de
        call sendVwfBufferIfPending
      pop de
      pop hl
      
      ; make up work
      ld a,(printSpeed)
      ld b,a
      ld a,($C345)
      jp $137F
  .ends

;===============================================
; string hash maps
;===============================================

.include "out/script/string_bucket_hashtable.inc"

; labels we care about:
; * bucketArrayHashTable (to look up bucket array by string key)
; * stringHashBuckets (to get bank for pointers in bucketArrayHashTable)

;===============================================
; routine that prints from a string without
; doing a hash lookup, for cases where
; we've added new strings and need to use them
;===============================================

.bank $00 slot 0
.section "new string manual print" free
  printNewString:
    push af
    push bc
    push de
      call printString
    pop de
    pop bc
    pop af
    ret
.ends

.bank $00 slot 0
.section "old string manual print banked" free
  ; for cases where we need to print an existing string from a bank
  ; outside the one it was originally used in
  ;
  ; B = bank
  ; HL = pointer
  printStdStringWithBank:
    ld a,(mapperSlot1Ctrl)
    push af
      ld a,b
      ld (mapperSlot1Ctrl),a
      call printStdString
    pop af
    ld (mapperSlot1Ctrl),a
    ret
.ends

;===============================================
; do hash map lookup on strings
;===============================================

  .bank $00 slot 0
  .org $13AD
  .section "string hash map 1a" overwrite
    ; redirect calls to the original printStdString to our hash map
    ; lookup/print routine
    jp hashMapLookupPrep
    oldPrintString:
  .ends

  .bank $00 slot 0
  .org $13DE
  .section "string hash map 1b" overwrite
    ; remove pops at ends of routine
    ret
  .ends

  .bank $00 slot 0
  .section "string hash map 2" free
    hashMapLookupPrep:
      ; make up work
      push af
      push bc
      push de
      
      ; ?
;      push hl
      
      ;=====
      ; save current slot1 bank
      ;=====
      ld a,(mapperSlot1Ctrl)
      push af
        
        ;=====
        ; ready and print the looked-up string
        ;=====
        
        ; look up hashed bank/pointer
        call findHashedString
        
        ; FE = bank change not needed (e.g. for strings in RAM)
        ld a,c
        cp $FE
        jr z,@print
        ; if returned banknum is FF, string not found
        cp $FF
        jr nz,@loadHashBank
        
          @hashLookupFailed:
          ; TODO: print the unhashed pointer
          ld a,:failString
          ld hl,failString
        
        @loadHashBank:
        ; load needed bank
        ld (mapperSlot1Ctrl),a
        
        ; save string position for future use
;        ld (curStringBank),a
;        ld (curStringPtr),hl
        
        ;=====
        ; print
        ;=====
        
        @print:
        call printString
        
      ;=====
      ; restore original slot1 bank
      ;=====
      @restoreOrigBank:
      pop af
      ld (mapperSlot1Ctrl),a
      
      @done:
      
      ; TODO: this returns a pointer to the original, unmapped string.
      ; some callers (e.g. the intro sequence) expect a pointer to the "next"
      ; string here. these need to be fixed, and this push/pop removed
;      pop hl
      
      pop de
      pop bc
      pop af
      ret
  .ends
  
  .bank $00 slot 0
  .section "string hash map 2b" free
    ; HL = orig string pointer
    ; bank containing original string should be loaded in correct slot
    ;
    ; returns new bank in C, new pointer in HL
    findHashedString:
      ld a,(mapperSlot1Ctrl)
      push af
      
        ;=====
        ; determine which bank we're targeting
        ; based on srcptr in HL
        ;=====
        ld a,h
        
        ; C000-FFFF = RAM
        cp $C0
        jr nc,@targetRam
        
        ; 8000-BFFF = expansion RAM
        ; (appears to always be mapped into slot 2)
        cp $80
        jr nc,@targetRam
        
        ; 4000-7FFF = slot 1
        cp $40
        jr nc,@targetSlot1
          
            ;=====
            ; if in ROM, target appropriate slot
            ;=====
            
            @targetSlot0:
    ;        ld a,(mapperSlot0Ctrl)
;            xor a    ; anything in slot 0 should be in bank 0
            ld c,$00    ; anything in slot 0 should be in bank 0
            jr +
            
            @targetSlot1:
            ld a,(mapperSlot1Ctrl)
            ld c,a
            
            +:
              
              ; set up banknum as param
;              ld c,a
            
              ;=====
              ; call lookup routine
              ;=====
              ld a,:lookUpHashedString
              ld (mapperSlot1Ctrl),a
              call lookUpHashedString
            
              ;=====
              ; finish
              ;=====
              
              jr @lookupDone
            
            ;=====
            ; if in RAM, ???
            ;=====
            
            @targetRam:
            ; TODO
            ; main character name, others? numbers?
  ;            jr @restoreOrigBank
            ld c,$FE
            jr @done
      
          @lookupDone:
          
          ;=====
          ; reset printing buffers, etc., if needed
          ;=====
          
  ;          ld a,(vwfNoResetFlag)
  ;          or a
  ;          jr nz,+
  ;            call resetVwfProtected
  ;          +:
      
      @done:
      pop af
      ld (mapperSlot1Ctrl),a
      ret
  .ends

  .slot 1
  .section "string hash map 3" superfree
    ;===============================================
    ; hash map lookup for translated strings
    ;
    ; parameters:
    ;   C  = banknum of orig string
    ;   HL = raw pointer to orig string (in
    ;        appropriate slot)
    ; 
    ; returns:
    ;   C  = banknum of mapped string (FF if not
    ;        in map)
    ;   HL = slot1 pointer to mapped string
    ;===============================================
    lookUpHashedString:
      ; save raw srcptr
      push hl
      
        ; convert raw pointer to hash key (AND with $1FFF)
        ld a,h
        and $1F
        ld h,a
        
        ; multiply by 2 and add $4000 to get slot1 pointer
        sla l
        rl h
        ld de,$4000
        add hl,de
        
        call doStringBucketLookup
      
      ; restore raw srcptr
      pop de
      
      ; if high byte of result ptr is FF, string not mapped
      ld a,h
      cp $FF
      jr z, @failure
      
        call getStringInfoFromBucketArray
        ; return banknum in A
;        ld a,c
        jr @done
      
      ; failure
      @failure:
      ld c,$FF
      
      @done:
      ret
    
    resetVwfProtected:
      push hl
      push bc
      
        call resetVwf
      
      pop bc
      pop hl
      ret
      
    failString:
      ; "#"
      .rept $100
        .db $17,$FF
      .endr
      
  .ends

  .bank 0 slot 0
  .section "string hash map 4" free
    ; HL = key ptr
    doStringBucketLookup:
      ld a,(mapperSlot1Ctrl)
      push af
      
        ld a,:bucketArrayHashTable
        ld (mapperSlot1Ctrl),a
        
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        
      pop af
      ld (mapperSlot1Ctrl),a
      ret
  .ends

  .bank 0 slot 0
  .section "string hash map 5" free
    ; HL = bucket pointer
    ; DE = orig srcptr
    ; C =  orig bank
    ;
    ; return:
    ; C = new bank
    ; HL = new ptr
    getStringInfoFromBucketArray:
      ld a,(mapperSlot1Ctrl)
      push af
      
        push ix
          
          ; IX = bucker pointer
          push hl
          pop ix
      
          ld a,:stringHashBuckets
          ld (mapperSlot1Ctrl),a
          
          @bucketCheckLoop:
            ; check if array end reached (string not found)
            ld a,(ix+0)
            cp $FF
            jr z,@failure
            
              ; check if src banknum matches
              cp c
              jr nz,@notFound
              
              ; check if low byte of srcptr matches
              ld a,(ix+1)
              cp e
              jr nz,@notFound
              
              ; check if high byte of srcptr matches
              ld a,(ix+2)
              cp d
              jr nz,@notFound
              
              ;=====
              ; match found!
              ;=====
              
              @found:
              ; new bank
              ld c,(ix+3)
              ; new srcptr
              ld l,(ix+4)
              ld h,(ix+5)
              jr @done
            
            @notFound:
            push de
              ld de,$0006
              add ix,de
            pop de
            jr @bucketCheckLoop
          
          @failure:
          ; A should be $FF at this point
          ld c,a
        
        @done:
        pop ix
      
      pop af
      ld (mapperSlot1Ctrl),a
      ret
  .ends

;===============================================
; use 5-pixel space for printed numbers so
; columns align correctly
;===============================================

.bank $00 slot 0
.org $1AFA
.section "new number spaces" overwrite
  ld (hl),vwfNumSpaceCharIndex
.ends
  
  ;=====
  ; fix digit counting
  ;=====

  .bank $00 slot 0
  .org $1B23
  .section "new number spaces fix digit count 1" overwrite
    call skipLeadingNumSpaces
    nop
    nop
    nop
  .ends

  .bank $00 slot 0
  .org $1B4D
  .section "new number spaces fix digit count 2" overwrite
    call skipLeadingNumSpaces
    nop
    nop
    nop
  .ends

  .bank $00 slot 0
  .section "new number spaces fix digit count 3" free
    skipLeadingNumSpaces:
      ld a,vwfNumSpaceCharIndex
      -:
        inc hl
        cp (hl)
        jp z,-
      ret
  .ends

  ;=====
  ; fix battle sprite numbers
  ;=====
  
  .bank $03 slot 1
  .org $1DE3
  .section "battle spaces 1" overwrite
    jp formatBattleSpaces
  .ends

  .bank $03 slot 1
  .section "battle spaces 2" free
    formatBattleSpaces:
    -:
      ; fetch tile-converted digit
      ld a,(de)
      cp vwfNumSpaceCharIndex
      jp nz,+
        ; if "digit" is our new space character
        ld a,$2D
        jr ++
      +:
        ; if digit is, in fact, a digit
        sub $07
        add a,c
      ++:
      ld (de),a
      inc de
      djnz -
    
    jp $5DF4
  .ends

;===============================================
; new default player name
;===============================================

.bank $01 slot 1
.org $0611
.section "default hero name 1" overwrite
  ld hl,playerDefaultName
.ends

.bank $01 slot 1
.section "default hero name 2" free
  playerDefaultName:
    .incbin "out/script/hero_default_name.bin"
.ends

  ;=====
  ; don't fill with spaces
  ;=====

  .bank $00 slot 0
  .org $3149
  .section "no space fill on name entry screen" overwrite
    jp $3162
  .ends

;===============================================
; fix countStringGlyphs
;===============================================

.bank $00 slot 0
.org $1A5A
.section "fix countStringGlyphs 1" size $1D overwrite
;  callExternal countStringGlyphsFixed
  ; return tile width in A
;  ld a,c
;  ret

  push hl
  push de

/*    call findHashedString
        
    ; FE = bank change not needed (e.g. for strings in RAM)
    ld a,c
    cp $FE
    jr z,@findWidth
    ; if returned banknum is FF, string not found
  ;  cp $FF
  ;  jr nz,+
    
  ;    @hashLookupFailed:
  ;    ld a,:failString
  ;    ld hl,failString
    
  ;  +:
    
    ;=====
    ; get tile width
    ;=====
    
    @findWidth:
    call findStringTileWidth */
    
    call countStringGlyphsFixed
  
  pop de
  pop hl
  ld a,c
  ret
.ends

.bank $00 slot 0
.section "countNewStringGlyphs" free
;  callExternal countStringGlyphsFixed
  ; return tile width in A
;  ld a,c
;  ret
  
  countNewStringGlyphs:
    push hl
    push de
      
      call countNewStringGlyphsFixed
    
    pop de
    pop hl
    ld a,c
    ret
.ends

;.slot 1
;.section "fix countStringGlyphs 2" superfree
.bank $00 slot 0
.section "fix countStringGlyphs 2" free
  countNewStringGlyphsFixed:
    ld c,$FE    ; bank change not needed
    jr countStringGlyphsFixed@hashDone
    
  ; HL = string ptr
  ; returns tile width in C
  countStringGlyphsFixed:
    
;    ld a,:findHashedString
;    ld hl,findHashedString
;    call longjmp

;    ld (longjmpHL),hl
;    doLongjmp findHashedString
    call findHashedString
    
    @hashDone:
    ld a,(mapperSlot1Ctrl)
    push af
        
      ; FE = bank change not needed (e.g. for strings in RAM)
      ld a,c
      cp $FE
      jr z,@findWidth
      ; if returned banknum is FF, string not found
      cp $FF
      jr nz,+
      
        @hashLookupFailed:
        ld a,:failString
        ld hl,failString
      
      +:
      
      ld (mapperSlot1Ctrl),a
    
      ;=====
      ; get tile width
      ;=====
      
      @findWidth:
  ;    ld (longjmpA),a
  ;    ld (longjmpHL),hl
  ;    doLongjmp findStringTileWidth
      call findStringTileWidth
    
    pop af
    ld (mapperSlot1Ctrl),a
    
    @done:
    ret
.ends

;===============================================
; fix extended HP/MP labels on data screen
;===============================================

.bank $01 slot 1
.org $0BC2
.section "extended hp/mp labels data screen 1" overwrite
  ld hl,$0201   ; print x/y offset
.ends

.bank $01 slot 1
.org $0BD3
.section "extended hp/mp labels data screen 2" overwrite
  ld hl,$0202   ; print x/y offset
.ends

;===============================================
; name entry
;===============================================

  .define nameEntryRowOffset 0

  .bank $00 slot 0
  .org $2DC0
  .section "name entry tile pos table" overwrite
    ; x/y pairs of screen coordinates of the tile for each selection index
    
    ; index $00
    .db $05,$08+nameEntryRowOffset
    ; index $01
    .db $05,$09+nameEntryRowOffset
    ; index $02
    .db $05,$0A+nameEntryRowOffset
    ; index $03
    .db $05,$0B+nameEntryRowOffset
    ; index $04
    .db $05,$0C+nameEntryRowOffset
    
    ; index $05
    .db $07,$08+nameEntryRowOffset
    ; index $06
    .db $07,$09+nameEntryRowOffset
    ; index $07
    .db $07,$0A+nameEntryRowOffset
    ; index $08
    .db $07,$0B+nameEntryRowOffset
    ; index $09
    .db $07,$0C+nameEntryRowOffset
    
    ; index $0A
    .db $09,$08+nameEntryRowOffset
    ; index $0B
    .db $09,$09+nameEntryRowOffset
    ; index $0C
    .db $09,$0A+nameEntryRowOffset
    ; index $0D
    .db $09,$0B+nameEntryRowOffset
    ; index $0E
    .db $09,$0C+nameEntryRowOffset
    
    ; index $0F
    .db $0B,$08+nameEntryRowOffset
    ; index $10
    .db $0B,$09+nameEntryRowOffset
    ; index $11
    .db $0B,$0A+nameEntryRowOffset
    ; index $12
    .db $0B,$0B+nameEntryRowOffset
    ; index $13
    .db $0B,$0C+nameEntryRowOffset
    
    ; index $14
    .db $0D,$08+nameEntryRowOffset
    ; index $15
    .db $0D,$09+nameEntryRowOffset
    ; index $16
    .db $0D,$0A+nameEntryRowOffset
    ; index $17
    .db $0D,$0B+nameEntryRowOffset
    ; index $18
    .db $0D,$0C+nameEntryRowOffset
    
    ; index $19
    .db $0F,$08+nameEntryRowOffset
    ; index $1A
    .db $0F,$09+nameEntryRowOffset
    ; index $1B
    .db $0F,$0A+nameEntryRowOffset
    ; index $1C
    .db $0F,$0B+nameEntryRowOffset
    ; index $1D
    .db $0F,$0C+nameEntryRowOffset
    
    ; index $1E
    .db $11,$08+nameEntryRowOffset
    ; index $1F
    .db $11,$09+nameEntryRowOffset
    ; index $20
    .db $11,$0A+nameEntryRowOffset
    ; index $21
    .db $11,$0B+nameEntryRowOffset
    ; index $22
    .db $11,$0C+nameEntryRowOffset
    
    ; index $23
    .db $13,$08+nameEntryRowOffset
    ; index $24
    .db $13,$09+nameEntryRowOffset
    ; index $25
    .db $13,$0A+nameEntryRowOffset
    ; index $26
    .db $13,$0B+nameEntryRowOffset
    ; index $27
    .db $13,$0C+nameEntryRowOffset
    
    ; index $28
    .db $15,$08+nameEntryRowOffset
    ; index $29
    .db $15,$09+nameEntryRowOffset
    ; index $2A
    .db $15,$0A+nameEntryRowOffset
    ; index $2B
    .db $15,$0B+nameEntryRowOffset
    ; index $2C
    .db $15,$0C+nameEntryRowOffset
    
    ; row
    
    ; index $2D
    .db $05,$0D+nameEntryRowOffset
    ; index $2E
    .db $07,$0D+nameEntryRowOffset
    ; index $2F
    .db $09,$0D+nameEntryRowOffset
    ; index $30
    .db $0B,$0D+nameEntryRowOffset
    ; index $31
    .db $0D,$0D+nameEntryRowOffset
    ; index $32
    .db $0F,$0D+nameEntryRowOffset
    ; index $33
    .db $11,$0D+nameEntryRowOffset
    ; index $34
    .db $13,$0D+nameEntryRowOffset
    ; index $35
    .db $15,$0D+nameEntryRowOffset
    
    ; row
    
    ; index $36
    .db $05,$0E+nameEntryRowOffset
    ; index $37
    .db $07,$0E+nameEntryRowOffset
    ; index $38
    .db $09,$0E+nameEntryRowOffset
    ; index $39
    .db $0B,$0E+nameEntryRowOffset
    
    ; bottom row
    
    ; index $3A
    .db $05,$12
    ; index $3B
    .db $07,$12
    ; index $3C
    .db $0A,$12
    ; index $3D
    .db $0F,$12
    ; index $3E
    .db $13,$12
  .ends

  .bank $00 slot 0
  .org $2E3E
  .section "name entry cursor movement table" overwrite
    ;=====
    ; movement table 0x2E3E = hiragana
    ;=====
    
    ; indices to move to when up/down/left/right pressed, in that order
    
    ; index $00
    .db $36,$01,$28,$05
    ; index $01
    .db $00,$02,$29,$06
    ; index $02
    .db $01,$03,$2A,$07
    ; index $03
    .db $02,$04,$2B,$08
    ; index $04
    .db $03,$2D,$2C,$09
    
    ; index $05
    .db $37,$06,$00,$0A
    ; index $06
    .db $05,$07,$01,$0B
    ; index $07
    .db $06,$08,$02,$0C
    ; index $08
    .db $07,$09,$03,$0D
    ; index $09
    .db $08,$2E,$04,$0E
    
    ; index $0A
    .db $38,$0B,$05,$0F
    ; index $0B
    .db $0A,$0C,$06,$10
    ; index $0C
    .db $0B,$0D,$07,$11
    ; index $0D
    .db $0C,$0E,$08,$12
    ; index $0E
    .db $0D,$2F,$09,$13
    
    ; index $0F
    .db $39,$10,$0A,$14
    ; index $10
    .db $0F,$11,$0B,$15
    ; index $11
    .db $10,$12,$0C,$16
    ; index $12
    .db $11,$13,$0D,$17
    ; index $13
    .db $12,$30,$0E,$18
    
    ; index $14
    .db $31,$15,$0F,$19
    ; index $15
    .db $14,$16,$10,$1A
    ; index $16
    .db $15,$17,$11,$1B
    ; index $17
    .db $16,$18,$12,$1C
    ; index $18
    .db $17,$31,$13,$1D
    
    ; index $19
    .db $3D,$1A,$14,$1E
    ; index $1A
    .db $19,$1B,$15,$1F
    ; index $1B
    .db $1A,$1C,$16,$20
    ; index $1C
    .db $1B,$1D,$17,$21
    ; index $1D
    .db $1C,$32,$18,$22
    
    ; index $1E
    .db $3D,$1F,$19,$23
    ; index $1F
    .db $1E,$20,$1A,$24
    ; index $20
    .db $1F,$21,$1B,$25
    ; index $21
    .db $20,$22,$1C,$26
    ; index $22
    .db $21,$33,$1D,$27
    
    ; index $23
    .db $3E,$24,$1E,$28
    ; index $24
    .db $23,$25,$1F,$29
    ; index $25
    .db $24,$26,$20,$2A
    ; index $26
    .db $25,$27,$21,$2B
    ; index $27
    .db $26,$34,$22,$2C
    
    ; index $28
    .db $3E,$29,$23,$00
    ; index $29
    .db $28,$2A,$24,$01
    ; index $2A
    .db $29,$2B,$25,$02
    ; index $2B
    .db $2A,$2C,$26,$03
    ; index $2C
    .db $2B,$35,$27,$04
    
    ; row
    
    ; index $2D
    .db $04,$36,$35,$2E
    ; index $2E
    .db $09,$37,$2D,$2F
    ; index $2F
    .db $0E,$38,$2E,$30
    ; index $30
    .db $13,$39,$2F,$31
    ; index $31
    .db $18,$14,$30,$32
    ; index $32
    .db $1D,$3D,$31,$33
    ; index $33
    .db $22,$3D,$32,$34
    ; index $34
    .db $27,$3E,$33,$35
    ; index $35
    .db $2C,$3E,$34,$2D
    
    ; row
    
    ; index $36
    .db $2D,$00,$39,$37
    ; index $37
    .db $2E,$05,$36,$38
    ; index $38
    .db $2F,$0A,$37,$39
    ; index $39
    .db $30,$0F,$38,$36
    
    ; bottom row
    
    ; index $3A
    ; dakuten
    .db $2D,$00,$3E,$3B
    ; index $3B
    ; handakuten
    .db $2E,$05,$3A,$3C
    ; index $3C
    ; kana toggle
    .db $30,$0F,$3B,$3D
    ; index $3D
    ; back
    .db $32,$19,$3E,$3E
    ; index $3E
    ; done
    .db $34,$23,$3D,$3D
  .ends

  /*;=====
  ; movement table 0x2F3A = katakana (removed)
  ;=====

  ; index $00
  .db $3A,$01,$28,$05
  ; index $01
  .db $00,$02,$29,$06
  ; index $02
  .db $01,$03,$2A,$07
  ; index $03
  .db $02,$04,$2B,$08
  ; index $04
  .db $03,$2D,$2C,$09
  ; index $05
  .db $3B,$06,$00,$0A
  ; index $06
  .db $05,$07,$01,$0B
  ; index $07
  .db $06,$08,$02,$0C
  ; index $08
  .db $07,$09,$03,$0D
  ; index $09
  .db $08,$37,$04,$0E
  ; index $0A
  .db $2F,$0B,$05,$0F
  ; index $0B
  .db $0A,$0C,$06,$10
  ; index $0C
  .db $0B,$0D,$07,$11
  ; index $0D
  .db $0C,$0E,$08,$12
  ; index $0E
  .db $0D,$2F,$09,$13
  ; index $0F
  .db $3C,$10,$0A,$14
  ; index $10
  .db $0F,$11,$0B,$15
  ; index $11
  .db $10,$12,$0C,$16
  ; index $12
  .db $11,$13,$0D,$17
  ; index $13
  .db $12,$30,$0E,$18
  ; index $14
  .db $3C,$15,$0F,$19
  ; index $15
  .db $14,$16,$10,$1A
  ; index $16
  .db $15,$17,$11,$1B
  ; index $17
  .db $16,$18,$12,$1C
  ; index $18
  .db $17,$31,$13,$1D
  ; index $19
  .db $3D,$1A,$14,$1E
  ; index $1A
  .db $19,$1B,$15,$1F
  ; index $1B
  .db $1A,$1C,$16,$20
  ; index $1C
  .db $1B,$1D,$17,$21
  ; index $1D
  .db $1C,$32,$18,$22
  ; index $1E
  .db $3D,$1F,$19,$23
  ; index $1F
  .db $1E,$20,$1A,$24
  ; index $20
  .db $1F,$21,$1B,$25
  ; index $21
  .db $20,$22,$1C,$26
  ; index $22
  .db $21,$33,$1D,$27
  ; index $23
  .db $3E,$24,$1E,$28
  ; index $24
  .db $23,$25,$1F,$29
  ; index $25
  .db $24,$26,$20,$2A
  ; index $26
  .db $25,$27,$21,$2B
  ; index $27
  .db $26,$34,$22,$2C
  ; index $28
  .db $3E,$29,$23,$00
  ; index $29
  .db $28,$2A,$24,$01
  ; index $2A
  .db $29,$2B,$25,$02
  ; index $2B
  .db $2A,$2C,$26,$03
  ; index $2C
  .db $2B,$35,$27,$04
  ; index $2D
  .db $04,$36,$35,$2F
  ; index $2E
  .db $09,$37,$2D,$2F
  ; index $2F
  .db $0E,$38,$2D,$30
  ; index $30
  .db $13,$39,$2F,$31
  ; index $31
  .db $18,$3C,$30,$32
  ; index $32
  .db $1D,$3D,$31,$33
  ; index $33
  .db $22,$3D,$32,$34
  ; index $34
  .db $27,$3E,$33,$35
  ; index $35
  .db $2C,$3E,$34,$2D
  ; index $36
  .db $2D,$3A,$39,$37
  ; index $37
  .db $09,$3B,$36,$38
  ; index $38
  .db $2F,$0A,$37,$39
  ; index $39
  .db $30,$3C,$38,$36
  ; index $3A
  .db $36,$00,$3E,$3B
  ; index $3B
  .db $37,$05,$3A,$3C
  ; index $3C
  .db $39,$0F,$3B,$3D
  ; index $3D
  .db $32,$19,$3C,$3E
  ; index $3E
  .db $34,$23,$3D,$3A */

  .bank $00 slot 0
  .org $3126
  .section "name entry no diacritics" overwrite
    jp $3138
  .ends

  .bank $00 slot 0
  .org $306F
  .section "name entry shift lines 1" overwrite
  ;  ld hl,$0100   ; hiragana row 1 x/y
    ld hl,$0100   ; hiragana row 1 x/y
  .ends

  .bank $00 slot 0
  .org $307B
  .section "name entry shift lines 2" overwrite
    ld hl,$0101   ; hiragana row 2 x/y
  .ends

  .bank $00 slot 0
  .org $3087
  .section "name entry shift lines 3" overwrite
    ld hl,$0102   ; hiragana row 3 x/y
  .ends

  .bank $00 slot 0
  .org $3093
  .section "name entry shift lines 4" overwrite
    ld hl,$0103   ; hiragana row 4 x/y
  .ends

  .bank $00 slot 0
  .org $309F
  .section "name entry shift lines 5" overwrite
    ld hl,$0104   ; hiragana row 5 x/y
  .ends

  .bank $00 slot 0
  .org $30AB
  .section "name entry shift lines 6" overwrite
    ld hl,$0105   ; hiragana row 6 x/y
  .ends

  .bank $00 slot 0
  .org $30C3
  .section "name entry shift lines 7" overwrite
    ; overwriting first part of katakana drawing routine
    ld hl,$0106
    ld ($C4AE),hl
    ld hl,$2DA4
    call printStdString
    jp $3126
  .ends

  .bank $00 slot 0
  .org $30B7
  .section "name entry shift lines 8" overwrite
    ld hl,$010A   ; hiragana row 8 x/y
  .ends

  .bank $00 slot 0
  .org $306B
  .section "name entry shift lines 9" overwrite
    ; make sure we don't draw the katakana screen (shouldn't happen anyway)
    nop
    nop
    nop
    nop
  .ends

  ;===============================================
  ; disable kana toggle
  ;===============================================

  .bank $00 slot 0
  .org $320A
  .section "name entry no kana toggle" overwrite
    jp $317F
  .ends
  
  ;===============================================
  ; use new character table
  ;===============================================
  
  .bank $00 slot 0
  .section "new name entry index->character map" free
    nameEntry_indexCharMap:
      .incbin "out/script/name_entry_chartable.bin"
  .ends

  .bank $00 slot 0
  .org $32C3
  .section "use new name entry charmap" size $57 overwrite
    ; runs when character added to name
    ; A = new index
    
    newCharEntryLookup:
    
    ;=====
    ; look up character index
    ;=====
    
    ld hl,nameEntry_indexCharMap
    ld e,a
    ld d,$00
    add hl,de
    ld a,(hl)
    ld e,a
    
    ;=====
    ; name may not exceed 8 bytes
    ;=====
    
    ld hl,playerName
    call countStringBytes
    cp $08
    jr nc,@done
    
      ;=====
      ; append to name
      ;=====
      
      ; add byte count to base name pointer
      ld b,$00
      ld c,a
      add hl,bc
      
      ; overwrite with new character
      ld (hl),e
      
      ; add terminator
      inc hl
      ld a,$FF
      ld (hl),a
  
      ;=====
      ; name may not exceed 35 pixels
      ; (new font is no more than 5 pixels per char, so this is guaranteed
      ; to allow at least 7 chars)
      ;=====
      
      push hl
        ld hl,playerName
        call findStringPixelWidth
      pop hl
      ld a,c
      cp playerNamePixelWidthLimit+1
      jr c,+
        ; erase the character we just added
        dec hl
        ld a,$FF
        ld (hl),a
        jr @done
      +:
    
      ;=====
      ; redraw
      ;=====
      
      ; our printing position may not have changed since the last
      ; time a character was added to the name, causing our new-string
      ; detection heuristic to fail, so we must reset the VWF buffer
      ; manually before printing
      call resetVwf
      
      ; draw
      call $313A
    
    @done:
    ld hl,playerName
    call $1A5A  ; old countStringGlyphs, now returns tile count
    ret
    
  .ends
  
  ;===============================================
  ; fix deletion (no diacritics)
  ;===============================================

  .bank $00 slot 0
  .org $32AE
  .section "fix name entry deletion" overwrite
    jp $32BC
  .ends
  
  ;===============================================
  ; make sure garbage collection doesn't destroy
  ; text content behind the name confirmation
  ; window, which for no real reason is closed
  ; before proceeding with the game
  ;===============================================
  
  .bank $00 slot 0
  .org $3236
  .section "name entry gc 1" overwrite
    call nameEntryGcCheck
  .ends
  
  .bank $00 slot 0
  .section "name entry gc 2" free
    nameEntryGcCheck:
      ; run garbage collection before opening window
      ; cheap but works
      call collectVwfGarbage
      
      ; make up work
      ld hl,$2CB4
      ret
  .ends
  
  ;===============================================
  ; use new quotation marks in confirmation
  ; message
  ;===============================================

/*  .bank $00 slot 0
  .org $3242
  .section "name entry confirmation quote 1" overwrite
    ld e,vwfOpenQuoteIndex
  .ends

  .bank $00 slot 0
  .org $324D
  .section "name entry confirmation quote 2" overwrite
    ld e,vwfCloseQuoteIndex
  .ends */
  
  ; actually, let's just add an extra string to make this neater
  .bank $00 slot 0
  .org $3242
  .section "name entry confirmation 1" overwrite
    ; first part of message (new)
    ld hl,nameEntryConfirmationStartMessage
    call printNewString
    ; player name
    ld hl,$C833
    call printStdString
    ; second part of message
    ld hl,$3270
    call printStdString
    
    jp $325E
  .ends
  
  .bank $00 slot 0
  .section "name entry confirmation 2" free
    nameEntryConfirmationStartMessage:
      .incbin "out/script/name_entry_confirmation.bin"
  .ends

;===============================================
; deallocate top line when dialogue box is
; scrolled
;===============================================

.bank $00 slot 0
.org $1349
.section "dialogue box scrolling dealloc 1" overwrite
  call dialogueBoxScrollDealloc
.ends

.bank $00 slot 0
.section "dialogue box scrolling dealloc 2" free
  dialogueBoxScrollDealloc:
    ; deallocate top text row of box
    
    ; H = X
    ld a,(printBaseX)
    inc a
    ld h,a
    ; L = Y
    ld a,(printBaseY)
    inc a
    ld l,a
    ; D = W
    ld a,(printAreaW)
    sub $02
    ld d,a
    ; E = H
    ld e,$01
    
    call deallocVwfTileArea
    
    ret
.ends

;===============================================
; correct, consistent use of stat terminology
;===============================================

.bank $01 slot 1
.org $24DD
.section "equipment change attack label" overwrite
  ld hl,$3F2F   ; orig $3F18 ("strength"), but this actually refers
                ; to the "attack" stat, i.e. strength + weapon power
.ends

;===============================================
; disable printing of item name before
; "you can't carry any more" messages in shops,
; since it doesn't play nicely with the
; quotation marks used for messages (even in
; the original game)
;===============================================

.bank $01 slot 1
.org $288E
.section "disable shop inventory full name printing" overwrite
  jp $6897
.ends

;===============================================
; add a "G" marker after the price in inns,
; since we can fit it in
;===============================================

.bank $01 slot 1
.org $317B
.section "inn G label 1" overwrite
  call doInnGLabel
.ends

.bank $01 slot 1
.section "inn G label 2" free
  doInnGLabel:
    push de
      ld e,vwfGIndex
      call printStdChar
    pop de
    
    ; make up work
    ld hl,$0002
    ret
.ends

;===============================================
; window modifications
;===============================================

  ;=====
  ; equip/remove window
  ;=====

  .bank $01 slot 1
  .org $2707
  .section "equip/remove window" overwrite
    ; base window x/y
    .db $0D-1,$08
    ; window w/h
    .db $05+1,$05
    ; text speed
    .db $00
  .ends

  ;=====
  ; shop item summary
  ;=====

  .bank $01 slot 1
  .org $2AC4
  .section "shop item summary window: weapon/armor label" overwrite
    ld hl,$0E00 ; print offset x/y (orig $0F00)
  .ends

  ;=====
  ; shop item comparison
  ;=====

  .bank $01 slot 1
  .org $2CB6
  .section "shop item comparison: attack/defense label" overwrite
    ld hl,$0E00-$0000 ; print offset x/y (orig $0E00)
  .ends

  .bank $01 slot 1
  .org $2CEB
  .section "shop item comparison: colon fix + shift item name right 1" overwrite
    jp shopDetailColonFix
  .ends

  .bank $01 slot 1
  .section "shop item comparison: colon fix + shift item name right 2" free
    shopDetailColonFix:
      ; print colon directly after name
      push de
        ld e,$11
        call printStdChar
      pop de
      
      ld a,$04+1
      ld (printOffsetX),a
      jp $6CF7
  .ends

  .bank $01 slot 1
  .org $2D1A
  .section "shop item comparison: shift value right" overwrite
    ld a,$0F+0    ; printOffsetX
  .ends

  ;=====
  ; unpoisoner dude's window
  ;=====

  .bank $01 slot 1
  .org $3ABB
  .section "unpoisoner dude's window" overwrite
    ; base window x/y
  ;  .db $0F,$05
    ; window w/h
  ;  .db $07,$07
    ; text speed
  ;  .db $00

    ; base window x/y
    .db $0F-2,$05
    ; window w/h
    .db $07+3,$07
    ; text speed
    .db $00
  .ends

  ;=====
  ; "on whom" window (item)
  ;=====

  .bank $01 slot 1
  .org $195E
  .section "'on whom' window (item)" overwrite
    ; base window x/y
    .db $03,$0C
    ; window w/h
    .db $06+1,$03
    ; text speed
    .db $00
  .ends

  ;=====
  ; "on whom" window (magic)
  ;=====

  .bank $01 slot 1
  .org $1EA2
  .section "'on whom' window (magic)" overwrite
    ; base window x/y
    .db $03,$0C
    ; window w/h
    .db $06+1,$03
    ; text speed
    .db $00
  .ends

  ;=====
  ; nudge shop item prices right
  ;=====

  .bank $01 slot 1
  .org $2EBF
  .section "shop item price" overwrite
    ld a,$09+2
  .ends

  ;=====
  ; nudge player gold amount in shops right
  ;=====

;  .bank $01 slot 1
;  .org $2EBF
;  .section "shop item price" overwrite
;    ld a,$09+2
;  .ends

  ;=====
  ; make player gold window smaller, since less
  ; space is needed now
  ;=====

  .bank $01 slot 1
  .org $27B6
  .section "shop gold window" overwrite
    ; base window x/y
    .db $0E+2,$02
    ; window w/h
    .db $09-2,$03
    ; text speed
    .db $00
  .ends

  ;=====
  ; drop/cancel window
  ;=====

  .bank $01 slot 1
  .org $1AC5
  .section "drop/cancel window" overwrite
    ; base window x/y
    .db $0E,$0A
    ; window w/h
    .db $05+1,$04
    ; text speed
    .db $00
  .ends

  ;=====
  ; character status screen "level" label
  ;=====

  .bank $01 slot 1
  .org $1663
  .section "character status screen 'level' label" overwrite
    ld hl,$0D00-$0000   ; offset x/y
  .ends

  .bank $01 slot 1
  .org $1534
  .section "character status screen 'level' number 1" overwrite
;    ld hl,$1000+$0100   ; offset x/y
    call decideStatusLevelNumPos
  .ends

  .bank $01 slot 1
  .section "character status screen 'level' number 2" free
    decideStatusLevelNumPos:
/*      ; base position
      ld hl,$1000+$0000   ; offset x/y
      
      ld a,(ix+$01)     ; get level
      
      ; if < 10, move right a tile
      cp 10
      jr nc,+
        inc h
      +:
      
      ret */
      
      ; why the hell did i write all that when we can just print a space
      ; before the number
      
      push af
      push de
        ld e,vwfSpaceCharIndex
        call printStdChar
      pop de
      pop af
      jp print8BitNum
      
  .ends

  ;=====
  ; character status screen EXP amount
  ;=====

  .bank $01 slot 1
  .org $158D
  .section "character status screen exp amount" overwrite
    ld hl,$0906+$0100   ; offset x/y
  .ends

  ;=====
  ; "'s equipment"
  ;=====

  .bank $01 slot 1
  .org $217D
  .section "'s equipment" overwrite
    ld hl,$0000+$0100   ; offset x/y
  .ends

  .bank $01 slot 1
  .org $21A8
  .section "'s items" overwrite
    ld hl,$0000+$0100   ; offset x/y
  .ends

  .bank $01 slot 1
  .org $21D3
  .section "'s spells" overwrite
    ld hl,$0000+$0100   ; offset x/y
  .ends

  ;=====
  ; shop price total report
  ;=====

  .bank $01 slot 1
  .org $2929
  .section "shop price total report" overwrite
    nop
    nop
    nop
    nop
    nop
  .ends

  ;=====
  ; space after "G" in current gold count in shops
  ;=====

  .bank $01 slot 1
  .org $2EE9
  .section "shop gold total 1" overwrite
    call printShopGoldSpace
  .ends

  .bank $01 slot 1
  .section "shop gold total 2" free
    printShopGoldSpace:
      
      push de
        ld e,vwfSpaceCharIndex
        call printStdChar
      pop de
      
      ; make up work
      jp printNum
  .ends

  ;=====
  ; use "HP" string instead of "H" in battle
  ;=====

  .bank $02 slot 1
  .org $0A27
  .section "battle hp label 1" overwrite
    call printBattleHpLabel
    nop
    nop
  .ends

  .bank $02 slot 1
  .section "battle hp label 2" free
    printBattleHpLabel:
      ; pointer to old "HP" string, as used on status menu or something
      ld hl,$3F07
      call printStdString
      
      ; add space
      ld e,vwfSpaceCharIndex
      jp printStdChar
      
/*      push bc
        ; same indicator used on the idle screen window
        ld hl,$4552
        ld b,1
        call printStdStringWithBank
      pop bc
      
      ret */
  .ends

;===============================================
; in-game manual
;===============================================

.define numManualSections 8
.define manualIndexTileW 18
.define manualIndexTileH (numManualSections*2)+2
.define manualIndexTileX 4
.define manualIndexTileY 2

.slot 1
.section "in-game manual" superfree
  manual_indexMenuTable:
    .incbin "out/script/manual_index.bin"
  manual_indexMenuCallbacks:
    .dw $0000
    .dw $2C5E
    .dw $2C71
    .dw $2C3F
    .dw $0000
    .dw $0000
    .dw $0000
    .dw $0000

  manual_section0:
    .incbin "out/script/manual_section0.bin"
  manual_section1:
    .incbin "out/script/manual_section1.bin"
  manual_section2:
    .incbin "out/script/manual_section2.bin"
  manual_section3:
    .incbin "out/script/manual_section3.bin"
  manual_section4:
    .incbin "out/script/manual_section4.bin"
  manual_section5:
    .incbin "out/script/manual_section5.bin"
  manual_section6:
    .incbin "out/script/manual_section6.bin"
  manual_section7:
    .incbin "out/script/manual_section7.bin"
    
  manual_sectionTable:
    .dw manual_section0
    .dw manual_section1
    .dw manual_section2
    .dw manual_section3
    .dw manual_section4
    .dw manual_section5
    .dw manual_section6
    .dw manual_section7
  
  manual_intro:
    .incbin "out/script/manual_intro.bin"
  
  manualBoxPrintParams:
    ; base window x/y
    .db manualIndexTileX,manualIndexTileY
    ; window w/h
    .db manualIndexTileW,manualIndexTileH
    ; text speed
    .db $00
  
  drawManualBox:
    push hl
      ld hl,manualBoxPrintParams
      call setUpPrintParams
      
      xor a
      ld (printSpeed),a
      ld (printOffsetX),a
      ld (printOffsetY),a
      
      call drawWindowBase
    pop hl
    ret
  
  runUserManual:
    push af
    push bc
    push de
    push hl
      
      ;=====
      ; show intro message
      ;=====
      
      call drawManualBox
      ld hl,manual_intro
      call printNewString
      call waitForKey
      
      xor a
      
      @manualMainLoop:
        
        push af
        
          ;=====
          ; print index menu
          ;=====
          
          ; draw selection window
          
          call drawManualBox
          
          ; just in case
          call resetVwf
          
          ; draw each option
          
          ; address of first menu option
          ld hl,manual_indexMenuTable+(numManualSections*2)+1
          ld b,numManualSections
          -:
            ; draw string
            call printNewString
            
            ; move to next line
            ld a,(printOffsetY)
            add a,$02
            ld (printOffsetY),a
            xor a
            ld (printOffsetX),a
            
            djnz -
        
        pop af
        
        ;=====
        ; run index menu logic
        ;=====
        
        ld b,$00
        ld c,a  ; default selection
        ld a,numManualSections
        ld d,numManualSections
        ld hl,manual_indexMenuCallbacks
        call runMenu
        
        ;=====
        ; if menu cancelled, done
        ;=====
        
        jr c,@done
        push af
        
          ;=====
          ; get pointer to corresponding section's data
          ;=====
          
          sla a
          ld e,a
          ld d,$00
          ld hl,manual_sectionTable
          add hl,de
          ld a,(hl)
          inc hl
          ld h,(hl)
          ld l,a
          
          ;=====
          ; show the section
          ;=====
          
          
          call runManualSection
        
        ;=====
        ; loop to menu
        ;=====
        
        pop af
        jr @manualMainLoop
      
    
    @done:
    pop hl
    pop de
    pop bc
    pop af
    ret
  
  
  ; HL = section data pointer
  runManualSection:
    push hl
    push bc
      ; just in case
      call resetVwf
    pop bc
    pop hl
    
    ; first byte of section = number of pages
    ld a,(hl)
    inc hl
    dec a
    ld b,a
    
    ; current pagenum
    ld c,$00
    
    @sectionPageLoop:
      
      ;=====
      ; show page content
      ;=====
      
      ; draw base window
      call drawManualBox
      
      ;=====
      ; draw page count
      ;=====
      
      push hl
        ; y
        ld a,(printAreaH)
        sub 2
        ld (printOffsetY),a
        
        ; x
        ld a,13
        ld (printOffsetX),a
        
        ; print current pagenum
        push bc
          ld a,c
          inc a
          ld b,2        ; number of digits
          call print8BitNum
        pop bc
        
        ; print "/"
        ld e,vwfSlashIndex
        call printStdChar
        
        ; print max pagenum
        push bc
          ld a,b
          inc a
          ld b,2
          call print8BitNum
        pop bc
        
        ; reset print offset
        xor a
        ld (printOffsetX),a
        ld (printOffsetY),a
      pop hl
      
      
      
      ;=====
      ; draw page markers if needed
      ;=====
        
      ; draw left arrow if not on first page
      ld a,c
      or a
      jr z,+
        push hl
          ; hl = x/y
          ld a,(printAreaH)
          ld e,a
          ld a,(printBaseY)
          add a,e
          dec a
          ld l,a
          ld a,(printBaseX)
          inc a
          ld h,a
          
          ; de = tile ($1F = right arrow)
          ld d,$0A
          ld e,$1F
          call sendCharToNametable
          
        pop hl
      +:
        
      ; draw right arrow if not on last page
      ld a,c
      cp b
      jr z,+
        push hl
          ; hl = x/y
          
          ld a,(printAreaH)
          ld e,a
          ld a,(printBaseY)
          add a,e
          dec a
          ld l,a
          
          ld a,(printAreaW)
          ld e,a
          ld a,(printBaseX)
          add a,e
          sub $02
          ld h,a
          
          ; de = tile ($1F = right arrow)
          ld d,$08
          ld e,$1F
          call sendCharToNametable
          
        pop hl
      +:
      
      ; look up pointer to page string
      push hl
        ; HL = pointer to offset table
        
        ; DE = current pagenum * 2
        ld a,c
        sla a
        ld e,a
        ld d,$00
        add hl,de
        
        ; read content offset
        ld e,(hl)
        inc hl
        ld d,(hl)
      ; restore base table pointer
      pop hl
      
      ; draw string
      push hl
        add hl,de
        call printNewString
      pop hl
      
      ;=====
      ; wait for user input
      ;=====
      
      @sectionWaitLoop:
        call waitVblank
        call readControllerInput
        bit 2,a
        jr z,+
          @leftPressed:
          ; get current pagenum
          ld a,c
          
          ; don't decrement if zero
          or a
          jr z,@sectionWaitLoop
          
          dec c
          jp @sectionPageLoop
        +:
        bit 3,a
        jr z,+
          @rightPressed:
          ; get current pagenum
          ld a,c
          
          ; don't increment if on last page
          cp b
          jr z,@sectionWaitLoop
          
          inc c
          jp @sectionPageLoop
        +:
        ; if button 2 pressed
        bit 5,a
        jr z,+
          ; if on last page, close
          ld a,c
          cp b
          jr z,@done
          ; otherwise, go to next page
          jr @rightPressed
        +:
        ; if button 1, or start pressed, close section
        and $50
        jp z,@sectionWaitLoop
    
    @done:
    ret
  
;  useInGameManual_test:
;    call runUserManual
    
    ; make up work
;    xor a
;    ld ($C830),a
;    jp $054B
  
;    ret
  
  translationCredits:
    .incbin "out/script/translation_credits.bin"
  
  runTranslationCredits:
    ld hl,translationCredits
    jp runManualSection
  
.ends

;===============================================
; use in-game manual and translation credits
;===============================================

.define numNewMenuOptions 2

  ;===============================================
  ; new strings
  ;===============================================

  .bank $01 slot 1
  .section "new menu strings" free
    userManualString:
      .incbin "out/script/manual_menulabel.bin"
    translationCreditsString:
      .incbin "out/script/credits_menulabel.bin"
  .ends
  
  ;===============================================
  ; draw new strings and add additional options
  ; to menus.
  ;
  ; there are three different versions of the
  ; main menu, each with their own setup routine:
  ; 1  no save files: new game only
  ; 2. 1-2 save files: new game, continue, copy,
  ;    delete
  ; 3. 3 save files: new game, continue, copy
  ;    (no delete)
  ;===============================================

  .bank $01 slot 1
  .org $087B
  .section "set up new menu options menu window defs" overwrite
    newMenuV1_windowParams:
      ; base window x/y
      .db $03,$02
      ; window w/h
      .db $08+6,$03+(numNewMenuOptions*2)
      ; text speed
      .db $00
    newMenuV2_windowParams:
      ; base window x/y
      .db $03,$02
      ; window w/h
      .db $08+6,$09+(numNewMenuOptions*2)
      ; text speed
      .db $00
    newMenuV3_windowParams:
      ; base window x/y
      .db $03,$02
      ; window w/h
      .db $08+6,$07+(numNewMenuOptions*2)
      ; text speed
      .db $00
  .ends
  
  ;===============================================
  ; menu v1
  ;===============================================

  .bank $01 slot 1
  .org $06CA
  .section "set up new menu options menu v1 1" overwrite
    call setUpNewMenuOptionsV1
  .ends

  .bank $01 slot 1
  .section "set up new menu options menu v1 2" free
    setUpNewMenuOptionsV1:
      ; make up work
      call printStdString
      
      ; new
      ld hl,$0002       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,userManualString
      call printNewString
      ld hl,$0004       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,translationCreditsString
      call printNewString
      
      ret
  .ends

  .bank $01 slot 1
  .org $06D0
  .section "set up new menu options menu v1 3" overwrite
    ; number of menu options
    ld a,$01+numNewMenuOptions
    ld d,$01+numNewMenuOptions
  .ends

  .bank $01 slot 1
  .org $06DD
  .section "set up new menu options menu v1 4" overwrite
    ; when option selected
    jp menuV1_optionSelected
  .ends
  
  ;===============================================
  ; menu v2
  ;===============================================

  .bank $01 slot 1
  .org $0692
  .section "set up new menu options menu v2 1" overwrite
    call setUpNewMenuOptionsV2
  .ends

  .bank $01 slot 1
  .section "set up new menu options menu v2 2" free
    setUpNewMenuOptionsV2:
      ; make up work
      call printStdString
      
      ; new
      ld hl,$0008       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,userManualString
      call printNewString
      ld hl,$000A       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,translationCreditsString
      call printNewString
      
      ret
  .ends

  .bank $01 slot 1
  .org $0698
  .section "set up new menu options menu v2 3" overwrite
    ; number of menu options
    ld a,$04+numNewMenuOptions
    ld d,$04+numNewMenuOptions
  .ends

  .bank $01 slot 1
  .org $06B5
  .section "set up new menu options menu v2 4" overwrite
    ; when option selected
    jp menuV2_optionSelected
  .ends
  
  ;===============================================
  ; menu v3
  ;===============================================

  .bank $01 slot 1
  .org $070A
  .section "set up new menu options menu v3 1" overwrite
    call setUpNewMenuOptionsV3
  .ends

  .bank $01 slot 1
  .section "set up new menu options menu v3 2" free
    setUpNewMenuOptionsV3:
      ; make up work
      call printStdString
      
      ; new
      ld hl,$0006       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,userManualString
      call printNewString
      ld hl,$0008       ; offset x/y
      ld (printOffsetXY),hl
      ld hl,translationCreditsString
      call printNewString
      
      ret
  .ends

  .bank $01 slot 1
  .org $0710
  .section "set up new menu options menu v3 3" overwrite
    ; number of menu options
    ld a,$03+numNewMenuOptions
    ld d,$03+numNewMenuOptions
  .ends

  .bank $01 slot 1
  .org $0729
  .section "set up new menu options menu v3 4" overwrite
    ; when option selected
    jp menuV3_optionSelected
  .ends

;.bank $01 slot 1
;.org $072C
;.section "use in-game manual 1" overwrite
;  jp useInGameManual_test
;.ends

.bank $01 slot 1
.section "use in-game manual 2" free
  useInGameManual:
    doLongjmp runUserManual
    jp $464D
  
  useTranslationCredits:
    doLongjmp runTranslationCredits
    jp $464D
  
  
  
  menuV1_optionSelected:
    ; A = selected menu options
    or a
    jp z,$472C  ; 00 = new game
    dec a
    jr z,useInGameManual
    jr useTranslationCredits
  
  menuV2_optionSelected:
;    or a
;    jp z,$472C  ; 00 = new game
;    dec a
;    jp z,$47BE  ; 01 = continue
;    dec a
;    jp z,$47E3  ; 02 = copy
;    dec a
;    jp z,$4846  ; 03 = delete
    dec a
    jr z,useInGameManual
    dec a
    jr z,useTranslationCredits
    ; ??? should never happen???
    jp $486C
  
  menuV3_optionSelected:
    dec a
    jr z,useInGameManual
    dec a
    jr z,useTranslationCredits
    ; ??? should never happen???
    jp $486C
.ends

;===============================================
; plural enemy names
;===============================================

  ;===============================================
  ; enemy name table
  ;===============================================

  .bank $03 slot 1
  .section "plural enemy names" free
    pluralEnemyNameTableBase:
      .incbin "out/script/enemy_names_plural.bin"
  .ends

  .bank $03 slot 1
  .org $22D5
  .section "use plural enemy names 1" overwrite
    jp printEnemyNameWithPlurality
  .ends

  .bank $03 slot 1
  .section "use plural enemy names 2" free
    printEnemyNameWithPlurality:
      ; B = enemy ID
      
      ; get total enemy count
      ld a,($C508)
      ld c,a
      
      ; check enemy plurality.
      ; at this point, C7B7 is an array of raw enemy IDs, including
      ; duplicates for multiple enemies of same type.
      ; we need to search this array for the first instance of the target
      ; ID, then read until array end to see if there's more than one.
      
      ; find first enemy instance (guaranteed to exist)
      ld hl,$C7B7
      -:
        dec c
        jp m,@singleEnemy
        ld a,(hl)
        inc hl
        cp b
        jr nz,-
      
      ; first instance of enemy found: check for another one
      -:
        dec c
        jp m,@singleEnemy
        ld a,(hl)
        inc hl
        cp b
        jr nz,-
      
      @pluralEnemy:
      push de
        ; HL = pointer to offset table
        ld hl,pluralEnemyNameTableBase+1
        push hl
          ; DE = enemy ID * 2
          ld a,b
          ld e,a
          ld d,$00
          sla e
          rl d
          add hl,de
          
          ; read content offset
          ld e,(hl)
          inc hl
          ld d,(hl)
        pop hl
        
        ; add string offset to base
        add hl,de
        
        ; print
        call printNewString
        
      pop de
      jp $62E2
      
      @singleEnemy:
      ; make up work
      ld a,$12
      ld l,$07
      jp $62D9
      
  .ends

;===============================================
; respect plurality of curse count in shaman
; dialogue
;===============================================

.bank $01 slot 1
.section "plural curse count 1" free
  pluralCurseCount1String:
    .incbin "out/script/curse_count_plural_1.bin"
  pluralCurseCount2String:
    .incbin "out/script/curse_count_plural_2.bin"
.ends

/*.bank $01 slot 1
.org $38BA
.section "plural curse count 2" overwrite
  jp doPluralCurseCount
.ends

.bank $01 slot 1
.section "plural curse count 3" free
  doPluralCurseCount:
    ; c = count
    ld a,c
    dec a
    jr nz,@plural
    
    @singular:
    ; make up work
    ld a,$12
    call $6EF0
    jp $78BF
    
    @plural:
    push hl
      ld hl,pluralCurseCountString
      call printNewString
    pop hl
    jp $78BF
    
.ends */

.bank $01 slot 1
.org $38A4
.section "plural curse count 2" size $16 overwrite
  ; message start
  call doPluralCurseCount1
  ; number of curses
  push bc
    ld a,c
    ld b,$00
    call print8BitNum
  pop bc
  ; message middle
  call doPluralCurseCount2
  ; name
  ld a,b
  call $3366
  jp pluralCurseCountDone
.ends

.bank $01 slot 1
.section "plural curse count 3" free
  doPluralCurseCount1:
    ; c = count
    ld a,c
    dec a
    jr nz,@plural
    
    @singular:
    ; make up work
    ld a,$10
    call $6EF0
    ret
    
    @plural:
    push hl
      ld hl,pluralCurseCount1String
      call printNewString
    pop hl
    ret
    
  doPluralCurseCount2:
    ; c = count
    ld a,c
    dec a
    jr nz,@plural
    
    @singular:
    ; make up work
    ld a,$11
    call $6EF0
    ret
    
    @plural:
    push hl
      ld hl,pluralCurseCount2String
      call printNewString
    pop hl
    ret
  
  pluralCurseCountDone:
    ; make up work
    ld a,$12
    call $6EF0
    jp $78BF
    
.ends

;===============================================
; no redundant space before sell prices
;===============================================

.bank $01 slot 1
.org $29D6
.section "shop sell price space" overwrite
  jp $69DD
.ends

;===============================================
; intro
;===============================================


/*.bank $03 slot 1
.section "intro strings" free
  introStrings:
    .incbin "out/script/intro.bin"
.ends

.bank $03 slot 1
.org $1917
.section "use new intro strings 1" overwrite
  ; start from our new string table
  ld hl,introStrings
.ends

.bank $03 slot 1
.org $192F
.section "use new intro strings 2" overwrite
  ; do not hash the new string pointers
  call countNewStringGlyphs
.ends

.bank $03 slot 1
.org $193F
.section "use new intro strings 3" overwrite
  ; do not hash the new string pointers
  call printNewString
.ends */

  ;===============================================
  ; completely rewritten because true VWF is too
  ; slow.
  ; instead, the graphics are prerendered during
  ; the build process, loaded all at once before
  ; the intro starts, and only the tilemaps are
  ; sent as the intro progresses.
  ;===============================================
  
  .define introDstTilenum $90
  
  .slot 1
  .section "intro 1" superfree
    introGraphics:
      .incbin "out/script/intro/grp.bin" FSIZE introGraphicsSize
  .ends
  
  .define numIntroGraphicTiles introGraphicsSize/bytesPerTile
  
  .bank $03 slot 1
  .section "intro 2" free
    introTilemaps:
      .incbin "out/script/intro/tilemaps.bin"
    
    loadIntroGraphics:
      ; make up work
      call setUpPrintParams
      
      ; load intro graphics
      ld a,:introGraphics
      ld bc,numIntroGraphicTiles
      ld de,introGraphics
      ld hl,introDstTilenum
      jp loadRawExternalTiles
    
    
  .ends
  
  .bank $03 slot 1
  .org $1909
  .section "intro 3" overwrite
    call loadIntroGraphics
  .ends
  
  .bank $03 slot 1
  .org $1917
  .section "intro 4" SIZE $51 overwrite
    ld hl,introTilemaps
    
    ; fetch number of intro tilemaps
    ld a,(hl)
    inc hl
;    ld (introRemainingCounter),a
    ld b,a
    
    @introLoop:
      ; intro continues until no tilemaps remain
      dec b
      jp z,$5968
        ld a,b
        ld (introRemainingCounter),a
      
        ; clear next line
        push hl
          ld hl,$0314
          ld bc,$1402
          ld de,$0800
          call clearNametableArea
        pop hl
        
        ; print next line
        call printIntroLine
        
        ; wait
        ld b,$10
        -:
          push bc
            ld b,$01
            call $01FA
            ld b,$05
            call $01B9
          pop bc
          ld a,($C345)
          ; check for start button = intro + title screen skip
          bit 6,a
          jp nz,$5981
          ; check for any other button = intro skip
          or a
          jp nz,$597C
          djnz -
        ld a,($C435)
        inc a
        ld ($C435),a
        
        ld a,(introRemainingCounter)
        ld b,a
        jr @introLoop
    
  .ends
  
  .bank $03 slot 1
  .section "intro 5" free
    ; hl = src data
    printIntroLine:
      push bc
      push de
        ; fetch number of tiles in line
        ld a,(hl)
        ld b,a
        inc hl
        ; fetch line centering offset
        ld a,(hl)
        ld c,a
        inc hl
        
        @tileSendLoop:
          ; fetch nametable data
          ld a,(hl)
          ld e,a
          inc hl
          ld a,(hl)
          ld d,a
          inc hl
          
          push hl
            ld a,c      ; x
            ld h,a
            ld l,$0F+5    ; y
            call sendTileToNametable
          pop hl
          
          ; move to next tile X
          inc c
          djnz @tileSendLoop
      
      pop de
      pop bc
      ret
  .ends

;===============================================
; title screen
;===============================================

.bank $03 slot 1
.org $1A94
.section "title screen 1" overwrite
  ld a,:titleScreenData
  ld hl,titleScreenData
  nop
  nop
.ends

.slot 1
.section "title screen 2" superfree
  titleScreenData:
    .incbin "out/cmp/title_data.bin"
.ends

;===============================================
; fix credits typos
;===============================================

; credits are plain ASCII and I don't feel like spending half
; an hour doing this "properly", so let's be lazy

.bank $08 slot 1
.section "fix credits 1" free
  credits_graphics1:
    .asc "    GRAPHICS"
    .db $90,$90
    .asc " THOMAS NOGUCHI"
    .db $FF
.ends

.bank $08 slot 1
.section "fix credits 2" free
  credits_graphics2:
    .asc "    GRAPHICS"
    .db $90,$90
    .asc " KENSUKE SUZUKI"
    .db $90
    .asc " FUMIHIDE AOKI"
    .db $90
    .asc " HIROKAZU WABIKO"
    .db $FF
.ends

.bank $08 slot 1
.section "fix credits 3" free
  credits_producer:
    .asc "     PRODUCER"
    .db $90,$90
    .asc "  KENSUKE SUZUKI"
    .db $FF
.ends

.bank $08 slot 1
.org $2504
.section "fix credits 4" overwrite
  .dw credits_graphics1
.ends

.bank $08 slot 1
.org $2509
.section "fix credits 5" overwrite
  .dw credits_graphics2
.ends

.bank $08 slot 1
.org $2513
.section "fix credits 6" overwrite
  .dw credits_producer
.ends


