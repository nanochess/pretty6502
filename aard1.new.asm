        ;
        ; Aardvark
        ;
        ; by Oscar Toledo G. (nanochess)
        ;
        ; Creation date: Sep/02/2016.
        ; Revision date: Dec/02/2016. Added holes and playfield mouth/eggs.
        ; Revision date: Dec/03/2016. Added enemy bitmaps and color.
        ; Revision date: Dec/04/2016. Tongue can be started/reverted with joystick.
        ;                             Added eggs in board.
        ; Revision date: Dec/06/2016. Tongue rules more close to arcade. Queen ants
        ;                             are now fixed and flashing. Counts eaten eggs
        ;                             and score. Displays score.
        ; Revision date: Dec/07/2016. Enemies are filled randomly, also two speeds.
        ;                             Aardvark centered. Dots are thicker now (uses
        ;                             2 rows). Aardvark walks slower.
        ; Revision date: Dec/11/2016. Now is main bank of 8K ROM. Worm appears at
        ;                             tongue tip level. Player can eat ants and
        ;                             worms.
        ; Revision date: Dec/12/2016. Enemy collisions now are checked here to avoid
        ;                             too many cycles used in display.
        ; Revision date: Jan/18/2016. Added Ranz des Vaches and Mountain King music.
        ; Revision date: Jan/19/2016. Corrected lack of feet in aardvark. Added
        ;                             tongue touched music. Added sound effects.
        ;                             Aardvark exits level when all eggs eaten.
        ;                             Remade code for collision of tongue. Corrected
        ;                             bug where eating right queen would delete left
        ;                             queen.
        ; Revision date: May/27/2017. Moved all display code to bank 0, this makes it
        ;                             to work with Atari Flashback Portable.
        ; Revision date: Oct/02/2017. Sun moves to left. Counts level.
        ; Revision date: Oct/08/2017. Added tongue retrain sound effect. Changes hole
        ;                             position randomly.
        ; Revision date: Oct/09/2017. Lives counting. Avoids worm appearing over ant.
        ;                             Going down has priority over going left/right
        ;                             but tries also left/right. New enemies: red
        ;                             ant and caterpillar. Only one worm can appear
        ;                             at any moment. Added more difficulty per level.
        ;                             Calculates bonus. New enemy: spider.
        ; Revision date: Oct/10/2017. Solved bug where worm would overwrite spider.
        ;                             Solved bug where tongue removed eggs without
        ;                             adjusting egg count. Solved bug where 150 points
        ;                             sprites wouldn't disappear. Added click sound
        ;                             effect for sunset. Added title screen.
        ; Revision date: Nov/01/2017. Changed holes1-6 to bitmap interpretation.
        ; Revision date: Nov/02/2017. Moved eggs and tongue to extra RAM (Sara chip).
        ; Revision date: Nov/03/2017. Renamed level as antHill. Now tongue and eggs
        ;                             bitmaps are intermixed (new display kernel).
        ;                             Sprites now appear at right places. Now hole
        ;                             map is aligned with kernelLst. Updated egg
        ;                             count. Configurable X-limit.
        ; Revision date: Nov/04/2017. Relocated direction bit. Collisions working
        ;                             again.
        ; Revision date: Nov/05/2017. Corrected worm catch. Score resets REFP0/1.
        ;                             Collision working again. Supports player
        ;                             reflection in display kernel.
        ;

        ; Next available label: aa128
        ; Free label: aa84, aa85

        ; TODO:
        ; * Bug: live counting isn't working right.
        ; * Bug: egg counting isn't working right.
        ; * Tune collisions.
        ; * Check if spider is working.
        ; * Bug: slight bam tone after winning music.
        ; * Bug: spider is slow to appear or doesn't appear.
        ; * Handle holes like a bitset instead of coordinate.
        ;   * Allow backtracking (using up)
        ;   * Test in MAME for movement details
        ; * Clouds (using PF)
        ; * Maybe new aardvark sprite, maybe multicolor, maybe 48px:
        ;   * Aardvark moving ears.
        ;   * Aardvark sprite sitting when tongue is touched.
        ;   * Aardvark walking.
        ; * Options in title screen.
        ;   * Starting level.
        ; * Message "Press start" in title screen.
        ; * Intermediate screen (losing live and completing level):
        ;       ants
        ;    x worms
        ;       * 10 = bonus
        ; * Game over (shown below intermediate screen)
        ; * Give an extra live each 20000 points.

        ; Differences versus arcade:
        ; * Arcade has 8 tunnels, we have 7.
        ; * Red ant appears at tunnel 4, in arcade is 5.
        ; * Centipede appears at tunnel 5, in arcade is 6.
        ; * Worm can appear at tunnel 7 in arcade (we have no space in screen)

        ; Things in unreleased ROM:
        ; * Sun timer using a digit counter.
        ; * White line after first bottom section
        ; * Level and time in second bottom section (separated)

        ; Game in brief:
        ;   * Move tongue in joystick direction.
        ;   * Press button to retrain tongue.
        ;   * Bugs appear randomly on both sides.
        ;   * Bug touching tongue -> lost life.
        ;   * Tongue touching bug from behind -> score.
        ;   * Spider descends from top to bottom, if touch tip -> lost life.
        ;   * If tongue eats queen -> all enemies in board disappear.
        ;   * Eating all dots -> level change.
        ;   * Each level has different configuration of holes in floors.
        ; * Ant: 100 points, appears starting in level 1, tunnels 1-4
        ; * Red ant: 150 points, appears starting in level 2, tunnel 5
        ; * Centipede: 150 points, appears starting in level 3, tunnel 6
        ; * Worm: 200 points, appears always at level of tongue.
        ;   * Only enemy that can appear at tunnel 7.
        ; * Tongue cannot move in tunnel 8, nor there are points, only can eat queen.
        ; * On restarting level the holes configuration changes.
        ; * On restarting level preserves darkness even if the initial animation is
        ;   done again.
        ; * Sun starts more at left per level. Since level 22 always starts barely
        ;   some pixels from left.
        ; * Extra lives each 20000 points

        processor 6502

        include aardm.asm

        ;
        ; Set object in X
        ; A = X position
        ; First argument = Object to position (0=P0, 1=P1, 2=M0, 3=M1, 4=BALL)
        ;
        MAC     set_x_position
        sta     WSYNC           ; 0- Start line synchro
        sec                     ; 2- Set carry flag (avoids it in loop)
.AE2:   sbc     #15             ; 4- Uses required time dividing A by 15
        bcs     .AE2            ; 6/7 - 11/16/21/26/31/36/41/46/51/56/61/66
        tay                     ; 8
        lda     fine_adjustment-$f1,y; 13 - Eats 5 cycles crossing page
        sta     HMP0+{1}
        nop
        sta     RESP0+{1}       ; 21/26/31/36/41/46/51/56/61/66/71 - "big" positioning
        ENDM

        org     $f000           ; ROM start address (4K)

        REPEAT  256
        .byte   $4f
        REPEND

START:
        sta     bank1           ; Ghost
        sei                     ; Disable interruptions
        cld                     ; Disable decimal mode
        jmp     START2

ba0:    sta     bank0
        jmp     0               ; Ghost

        sta     bank1           ; Ghost
        jmp     ba1

ba2:    sta     bank0
        jmp     0               ; Ghost

        sta     bank1
        jmp     ba3

START2:
        ldy     rand
        ; Clean up the memory
        ldx     #$ff            ; Load X with $FF...
        txs                     ; ...copy to stack pointer
        lda     #0              ; Load zero in accumulator
AE1:    sta     0,X             ; Save in address 0 plus X
        dex                     ; Decrement X
        bne     AE1             ; Repeat until X is zero.
        sta     SWACNT          ; Allow to read joysticks
        sta     SWBCNT          ; Allow to read buttons
        tsx                     ; ldx #$ff
        stx     prev_button
        sty     rand

        lda     rand
        sta     level_seed

title_screen:
        lda     #20
        sta     temp1
        jmp     ba2

ba3:
        lda     #0
        sta     antHill
        lda     #4
        sta     lives

        lda     #0
        sta     score
        sta     score+1
        sta     score+2

        ldx     #tongue_size*2-12
aa124:  lda     #0
        sta     tongue1+W,x
        sta     tongue1+W+1,x
        sta     tongue1+W+2,x
        sta     tongue1+W+3,x
        sta     tongue1+W+4,x
        sta     tongue1+W+5,x
        txa
        sec
        sbc     #12
        tax
        bpl     aa124

        ;
        ; Goes to next level
        ;
next_level:
        inc     antHill
        inc     level_seed

        ;
        ; Setup starting sun position
        ;
        lda     antHill
        asl
        bmi     aa82
        asl
        bpl     aa83
aa82:   lda     #$80
aa83:   eor     #$ff
        adc     #$98
        sta     sun_pos

        lda     #$00
        sta     COLUBK          ; Background color

        ; VERTICAL_SYNC
        lda     #2
        sta     VSYNC           ; Start vertical synchro
        sta     WSYNC           ; Wait for 3 lines
        sta     WSYNC
        sta     WSYNC
        ;
        lda     #43
        sta     TIM64T
        lda     #0
        sta     VSYNC           ; Stop vertical synchro

        ldx     #tongue_size*2-12
aa29:   lda     #0
        sta     tongue1+W,x
        sta     tongue1+W+1,x
        sta     tongue1+W+2,x
        sta     tongue1+W+3,x
        sta     tongue1+W+4,x
        sta     tongue1+W+5,x
        cpx     #0
        beq     .+4
        lda     #$aa
        sta     eggs1+W,x
        sta     eggs1+W+2,x
        sta     eggs1+W+3,x
        sta     eggs1+W+5,x
        lsr
        sta     eggs1+W+1,x
        sta     eggs1+W+4,x
        txa
        sec
        sbc     #12
        tax
        bpl     aa29

        lda     #7*20
        sta     eggs

        ;
        ; Setup queen ants
        ;
        lda     #sprite_queen_ant+ENEMY_DIR_MASK
        sta     enemy0_t
        sta     enemy8_t
        lda     #$2e
        sta     enemy0_x
        lda     #$66
        sta     enemy8_x

        jmp     aa73

restart_level:
        inc     level_seed
        lda     #$00
        sta     effect0
        sta     effect1
        sta     ants_eaten
        sta     worms_eaten
        sta     COLUBK          ; Background color

        ; VERTICAL_SYNC
        lda     #2
        sta     VSYNC           ; Start vertical synchro
        sta     WSYNC           ; Wait for 3 lines
        sta     WSYNC
        sta     WSYNC
        ;
        lda     #43
        sta     TIM64T
        lda     #0
        sta     VSYNC           ; Stop vertical synchro

aa73:
        lda     #1              ; Ranz des Vaches (Rossini)
        sta     tracker
        lda     #1              ; Start immediately
        sta     tracker_c

        lda     #6
        sta     aa_x_pos
        lda     #1
        sta     timer
        lda     #0
        sta     filling
        sta     flags
        ;
        ; Delete tongue and delete also any eggs under
        ;
        ldx     #tongue_size*2-12
aa69:
        ldy     #5
aa80:   lda     tongue1+R,x
        eor     #$ff
        and     eggs1+R,x
        sta     eggs1+W,x
        lda     #0
        sta     tongue1+W,x
        inx
        dey
        bpl     aa80
        txa
        sec
        sbc     #18
        tax
        bpl     aa69

        lda     #0
        sta     enemy1_t
        sta     enemy2_t
        sta     enemy3_t
        sta     enemy4_t
        sta     enemy5_t
        sta     enemy6_t
        sta     enemy7_t
        sta     enemy9_t
        sta     enemy10_t
        sta     enemy11_t
        sta     enemy12_t
        sta     enemy13_t
        sta     enemy14_t
        sta     enemy15_t
        sta     holeCols
        sta     holeCols+1
        sta     holeCols+2
        sta     holeCols+3
        sta     holeCols+4
        sta     holeCols+5
        sta     holeCols+6
        sta     holeCols+7
        lda     #$ff
        sta     tip_y
        jmp     aa75

main_loop:
        lda     #$00
        sta     COLUBK          ; Background color

        ; VERTICAL_SYNC
        lda     #2
        sta     VSYNC           ; Start vertical synchro
        sta     WSYNC           ; Wait for 3 lines
        sta     WSYNC
        sta     WSYNC
        ;
        lda     #43
        sta     TIM64T
        lda     #0
        sta     VSYNC           ; Stop vertical synchro

aa75:
        ; Nanochess' mini sound effects player
        ldx     tracker
        bne     ef4
        lda     effect0
        beq     ef0
        tax
        lda     sound_effect,x
        bne     ef1
        sta     effect0
        beq     ef0

ef1:    sta     AUDF0
        lda     sound_effect+1,x
        sta     AUDC0
        lsr
        lsr
        lsr
        lsr
        inx
        inx
        stx     effect0

ef0:    sta     AUDV0

        lda     effect1
        beq     ef2
        tax
        lda     sound_effect,x
        bne     ef3
        sta     effect1
        beq     ef2

ef3:    sta     AUDF1
        lda     sound_effect+1,x
        sta     AUDC1
        lsr
        lsr
        lsr
        lsr
        inx
        inx
        stx     effect1

ef2:    sta     AUDV1
        bpl     tr0

        ; Nanochess' mini tracker
ef4:
        ldx     tracker
        beq     tr1
        dec     tracker_c
        bne     tr3
        lda     music-1,x
        bne     tr2
        sta     tracker
        beq     tr1

tr2:    and     #$1f
        asl
        tay
        lda     music_notes-2,y
        sta     AUDC0
        lda     music_notes-1,y
        sta     AUDF0
        lda     music-1,x
        lsr
        lsr
        and     #$38
        sta     tracker_c
        lda     music,x
        asl
        tay
        lda     music_notes-2,y
        sta     AUDC1
        lda     music_notes-1,y
        sta     AUDF1
        inx
        inx
        stx     tracker
        lda     #$3f
        sta     tracker_v
tr3:    dec     tracker_v
        lda     tracker_v
        lsr
        lsr
        cpx     #43
        bcs     tr1
        lda     tracker_v
        and     #$03
        bne     tr4
        lda     #$02
tr4:    ora     #$0c
tr1:    sta     AUDV0
        sta     AUDV1
tr0:

        lda     aa_x_pos
        cmp     #$0f            ; Corrects left side X-pos, for some reason it breaks.
        bcs     *+4
        sbc     #2
        set_x_position 0        ; Player 0
        ;	ldx #1		; Player 1
        lda     sun_pos
        set_x_position 1        ; Player 1
        lda     #84
        set_x_position 2        ; Missile 0
        lda     #$20
        sta     NUSIZ0
        sta     NUSIZ1

        jsr     build_hole_map

        lda     #$00
        sta     GRP0
        sta     GRP1
        sta     COLUPF
        lda     #$20
        sta     CTRLPF

        jmp     ba0

ba1:

        ;
        ; Score zone
        ;
        sta     WSYNC           ; 0
        ldx     #$00            ; 3
        stx     COLUBK          ; 5 Background color
        stx     GRP0            ; 8
        stx     GRP1            ; 11
        stx     REFP0           ; 14
        stx     REFP1           ; 17
        sta     en5             ; 20
        lda     score           ; 23
        and     #$0f            ; 26
        asl                     ; 28
        asl                     ; 30
        asl                     ; 32
        sta     en4             ; 34
        lda     score           ; 37
        lsr                     ; 40
        and     #$78            ; 42
        sta     en3             ; 44
        lda     #$21            ; 47
        sta     CTRLPF          ; 49
        lda     #lives_color    ; 52
        sta     COLUPF          ; 54
        ldx     lives           ; 57
        cpx     #7              ; 60
        bcc     aa88            ; 62
        ldx     #7              ; 64
aa88:
        lda     lives_pf,x      ; 66
        sta     WSYNC           ; 71
        sta     PF0
        lda     lives_pf+8,x
        sta     PF1
        lda     lives_pf+16,x
        sta     PF2
        lda     score+1         ; 35
        and     #$0f            ; 38
        asl                     ; 40
        asl                     ; 42
        asl                     ; 44
        sta     en2             ; 46
        lda     score+1         ; 49
        lsr                     ; 52
        and     #$78            ; 54
        sta     en1             ; 56
        lda     score+2         ; 59
        and     #$0f            ; 62
        asl                     ; 64
        asl                     ; 66
        asl                     ; 68
        sta     en0             ; 70
        ldx     #0

        lda     #score_color    ; 73
        jmp     $f400           ; 75
        org     $F400
mp0:
        sta     WSYNC
        stx     GRP0
        stx     GRP1
        ldy     #numbers>>8     ; 8
        sty     en0+1           ; 11
        sty     en1+1           ; 14
        sty     en2+1           ; 17
        sty     en3+1           ; 20
        sty     en4+1           ; 23
        sty     en5+1           ; 26

        sta     COLUP0          ; 29
        sta     COLUP1          ; 32
        lda     #$03            ; 35    3 copies together
        ldx     #$f0            ; 37
        stx     RESP0           ; 39
        stx     RESP1           ; 42
        stx     HMP0            ; 45
        sta     NUSIZ0          ; 48
        sta     NUSIZ1          ; 51
        lsr                     ; 53
        sta     VDELP0          ; 56
        sta     VDELP1          ; 59
        lsr
        sta     HMP1
        sta     WSYNC           ; 62
        sta     HMOVE           ; 3
        lda     #4
        sta     temp2
mp1:    ldy     temp2           ; 2
        lda     (en0),y         ; 7
        sta     GRP0            ; 10
        sta     WSYNC           ; 13 + 61 = 76
        lda     (en1),y         ; 5
        sta     GRP1            ; 8
        lda     (en2),y         ; 13
        sta     GRP0            ; 16
        lda     (en3),y         ; 21
        sta     temp1           ; 24 Write (this depends on being at "root" stack pos)
        lda     (en4),y         ; 29       (and of course not being called)
        tax                     ; 31
        lda     (en5),y         ; 36
        tay                     ; 38
        lda     temp1           ; 41 Read
        sta     GRP1            ; 44
        stx     GRP0            ; 47
        sty     GRP1            ; 50
        sta     GRP0            ; 53
        dec     temp2           ; 58
        bpl     mp1             ; 60/61
mp3:
        ; Looks for code spanning page
        if      (mp1&$ff00)!=(mp3&$ff00)
        lda     megabug3        ; :P
        endif
        echo    "mp0 ",mp0," mp1 ",mp1," mp3 ",mp3

        ;
        ; End of graphics (204 lines)
        ;
        ldx     #$00
        lda     #2
        sta     WSYNC
        sta     VBLANK
        stx     VDELP0
        stx     VDELP1
        stx     GRP0
        stx     GRP1
        stx     PF0
        stx     PF1
        stx     PF2

        ;
        ; Start overscan timer
        ;
        lda     #43             ; 37 lines * 76 = 2812 cycles / 64 = 43.9375
        sta     TIM64T

        lda     flags
        and     #$03
        cmp     #$02            ; Tongue touched?
        bne     aa67
        jmp     wait_overscan

aa67:   lda     eggs
        bne     aa70
        ldx     aa_x_pos
        cpx     #52
        bne     aa71
        inc     aa_x_pos
        lda     #43             ; Mountain King (Grieg)
        sta     tracker
        lda     #1
        sta     tracker_c
        lda     #0
        sta     filling
        sta     flags
        ldx     #tongue_size*2-1
        lda     #0
aa72:   sta     tongue1+W,x
        dex
        bpl     aa72

        sta     enemy0_t
        sta     enemy1_t
        sta     enemy2_t
        sta     enemy3_t
        sta     enemy4_t
        sta     enemy5_t
        sta     enemy6_t
        sta     enemy7_t
        sta     enemy8_t
        sta     enemy9_t
        sta     enemy10_t
        sta     enemy11_t
        sta     enemy12_t
        sta     enemy13_t
        sta     enemy14_t
        sta     enemy15_t
        sta     holeCols
        sta     holeCols+1
        sta     holeCols+2
        sta     holeCols+3
        sta     holeCols+4
        sta     holeCols+5
        sta     holeCols+6
        sta     holeCols+7
        lda     #$ff
        sta     tip_y
aa71:   jmp     aa34

aa70:   lda     flags
        and     #$fc
        sta     flags

        ;
        ; Check for collisions of enemies versus tongue (playfield pixels)
        ;
        ldx     #15
aa53:   lda     enemy0_t,x
        tay
        cmp     #non_interactive_sprites
        bcc     aa86
        cpx     #8
        bcs     aa45
        lda     cxLst,x
        and     #$20
        beq     aa86            ; No, jump
        bne     aa127

aa45:   lda     cxLst-8,x
        asl
        bpl     aa86

aa127:  tya
        and     #$f0
        cmp     #sprite_spider
        beq     aa106
        cmp     #sprite_worm    ; Is it a worm?
        beq     aa55
        bne     aa87

aa86:
        dex
        bpl     aa53
        jmp     aa78

        ;
        ; Spider
        ; * Kills if touches tongue tip
        ;
aa106:
        txa
        and     #$07
        cmp     tip_y           ; Is it at same level than tongue?
        bne     aa86            ; No, jumps
        lda     enemy0_x,x
        tay
        sbc     #3
        lsr
        lsr
        cmp     tip_x
        beq     aa56sc
        tya
        clc
        adc     #10
        lsr
        lsr
        cmp     tip_x
        beq     aa56sc
        bne     aa86

aa87:
        ;
        ; Ant:
        ; * Eaten if tongue tip.
        ; * Kills if it touch any other part of tongue.
        ;
        txa
        and     #$07
        cmp     tip_y           ; Is it at same level than tongue?
        bne     aa56sc          ; No, kills
        lda     enemy0_x,x
        sbc     #3
        tay
        lsr
        lsr
        cmp     tip_x
        beq     aa57
        bcs     aa56
        tya
        clc
        adc     #10
        lsr
        lsr
        cmp     tip_x
        beq     aa57
        bcc     aa56

aa57:   lda     enemy0_t,x
        cmp     #sprite_queen_ant+$20
        bcs     aa125
        cmp     #sprite_queen_ant
        bcs     aa59
aa125:  cmp     #pricey_sprites ; Red ant and caterpillar
        bcs     aa97
        sed
        lda     ants_eaten
        adc     #1
        sta     ants_eaten
        cld
        lda     #sprite_explosion; Goodbye ant
        .byte   $2c             ; BIT opcode to jump
aa97:   lda     #sprite_150
        ldy     #11
        bne     aa79

aa56sc: jmp     aa56

aa59:   jsr     clear_enemies
        ldy     #33
aa79:   sty     effect1
        bne     aa60

        ;
        ; Worm:
        ; * Eaten if tongue tip from behind.
        ; * Kills only if tongue tip in front.
        ;
aa55:   txa
        and     #$07
        cmp     tip_y
        bne     aa54
        lda     enemy0_x,x
        tay
        sbc     #3
        lsr
        lsr
        cmp     tip_x
        beq     aa58
        bcs     aa54
        tya
        clc
        adc     #10
        lsr
        lsr
        cmp     tip_x
        beq     aa58
        bcc     aa54
aa58:   lda     tip_dir
        beq     aa56
        lsr                     ; $ff left $00 right
        eor     enemy0_t,x
        and     #ENEMY_SPEED_MASK
        bne     aa56
        lda     flags
        and     #~FLAGS_WORM
        sta     flags
        inc     worms_eaten
        lda     #20
        sta     effect1
        lda     #sprite_200     ; 200 points
aa60:   sta     enemy0_t,x
        bne     aa54

        ; Kill
aa56:   lda     flags
        and     #$fc
        ora     #$01
        sta     flags

aa54:
        dex
        bmi     aa78
        jmp     aa53
aa78:

        lda     flags
        and     #$03
        beq     aa52
        jmp     wait_overscan

        ;
        ; Invoke an enemy
        ;
aa52:
        dec     timer
        beq     aa95
        jmp     aa14
aa95:
        jsr     random_proc     ; Get a random number (just because :P)
        tay                     ; Save it
        and     #$0e            ; Restart timer
        ora     #$01
        sta     timer
        lda     antHill         ; Starts at 1
        clc
        adc     #$03            ; Level 1 - fills 4 tunnels, 2 - 5 t., 4 and so- 6 t.
        cmp     #$06            ; No more than 6 tunnels
        bcc     aa92
        lda     #$06
aa92:   asl
        sta     temp1
        lda     filling
        cmp     temp1
        bcc     aa102
aa103:  jmp     aa8
aa102:
        and     #$0e
        lsr
        eor     #$07
        tax
        cmp     #$07
        bne     aa111
        lda     enemy8_t,x
        bne     aa111
        lda     #FLAGS_SPIDER
        bit     flags
        bne     aa111
        lda     sun_pos
        cmp     #8              ; Now it's night?
        beq     aa110           ; No, jump
aa111:  lda     enemy0_t,x      ; There is space for a common enemy?
        beq     aa12            ; Yep, jump.
aa110:  lda     enemy8_t,x      ; There is space for a worm/spider?
        bne     aa103           ; No, jump
        cpx     #0              ; Top tunnel?
        bne     aa101           ; No, jump
        lda     sun_pos
        cmp     #8              ; Now it's night?
        bne     aa101           ; No, jump
        lda     #FLAGS_SPIDER
        bit     flags           ; We have already the spider?
        bne     aa101           ; Yes, jump
        ora     flags
        sta     flags
        lda     #ENEMY_MAX_X
        sta     enemy8_x,x
        tya
        and     #ENEMY_SPEED_MASK
        ora     #sprite_spider
        sta     enemy8_t,x
        bne     aa8

aa101:
        txa
        and     #$07
        cmp     tip_y
        bne     aa103
        lda     #FLAGS_WORM
        bit     flags           ; Already a worm in screen?
        bne     aa8             ; Yes, jump
        ora     flags
        sta     flags
        tya
        and     #$40
        beq     aa37
        lda     enemy0_x,x
        cmp     #40
        bcc     aa90
aa91:   lda     #ENEMY_MIN_X
        sta     enemy8_x,x
        tya
        and     #ENEMY_SPEED_MASK
        ora     #sprite_worm+ENEMY_DIR_MASK
        sta     enemy8_t,x
        bne     aa8

aa37:   lda     enemy0_x,x
        cmp     #129
        bcs     aa91
aa90:   lda     #ENEMY_MAX_X
        sta     enemy8_x,x
        tya
        and     #ENEMY_SPEED_MASK
        ora     #sprite_worm
        sta     enemy8_t,x
        bne     aa8

aa12:   tya
        and     #$40
        beq     aa15
        lda     #ENEMY_MIN_X
        sta     enemy0_x,x
        tya
        and     #ENEMY_SPEED_MASK
        ora     enemies_going_right,x
        sta     enemy0_t,x
        bne     aa8

aa15:   lda     #ENEMY_MAX_X
        sta     enemy0_x,x
        tya
        and     #ENEMY_SPEED_MASK
        ora     enemies_going_left,x
        sta     enemy0_t,x
        ;	bne aa8

aa8:    ldx     antHill
        cpx     #32
        bcc     aa93
        ldx     #31
aa93:   lda     filling
        clc
        adc     #2
        cmp     refilling,x
        bne     aa94
        lda     #0
aa94:   sta     filling
aa14:

        ;
        ; Sun animation
        ;
        lda     frame
        and     #$1f            ; Each 32 frames
        bne     aa81
        lda     sun_pos
        cmp     #8
        beq     aa81
        dec     sun_pos         ; Move sun left by one pixel
        cmp     #9
        bne     aa81
        lda     #129            ; Click effect
        sta     effect0
aa81:

        ;
        ; Enemy animation and movement
        ;
        ldy     #0
        lda     frame
        and     #$07            ; Enemies change animation frame each 8 frames
        bne     aa11
        ldy     #8
aa11:   and     #$03            ; Enemies move each 4 frame
        beq     aa117
        jmp     aa43
aa117:
        ldx     #$0f
aa10:
        lda     enemy0_t,x      ; Active enemy?
        bne     aa118           ; Yes, jump
aa120:  dex
        bpl     aa10
        jmp     aa43

        ;
        ; Check first for brief sprites (explosion, 150 and 200 points)
        ;
aa118:  cmp     #non_interactive_sprites
        bcs     aa39
aa49:   inc     enemy0_t,x
        cmp     #sprite_150+$03
        beq     aa96
        cmp     #sprite_200+$03
        beq     aa46
        cmp     #sprite_200_spider+$03
        beq     aa46
        cmp     #sprite_explosion+$03
        bne     aa38sd
        lda     #$10            ; 100 points
        .byte   $2c             ; BIT opcode to jump
aa46:   lda     #$20            ; 200 points
        .byte   $2c             ; BIT opcode to jump
aa96:   lda     #$15            ; 150 points
        jsr     score_points
        lda     #$00
        sta     enemy0_t,x
aa38sd: jmp     aa38
        ;
        ; All other sprites
        ;
aa39:   and     #$f0
        cmp     #sprite_spider
        bne     aa108
        ;
        ; Spider handling
        ;
        lda     tip_y           ; Tongue tip active?
        bmi     aa120           ; No, jump (spider stays quiet)
        txa                     ; Get vertical position of spider
        and     #$07
        cmp     tip_y           ; Comparison with tongue tip vertical position.
        beq     aa109           ; Same vertical position? yes, jump
        bcs     aa120           ; Jump if spider deeper than tongue tip. It shouldn't happen
        stx     temp1
        tax
        lda     holeCols,x      ; Check if tongue goes thru a hole !!!
        lsr
        bcs     aa112
        lsr
        bcs     aa113
        lsr
        bcs     aa114
        lda     #0
        .byte   $2c             ; BIT opcode to jump
aa114:  lda     #8
        .byte   $2c             ; BIT opcode to jump
aa113:  lda     #16
        .byte   $2c             ; BIT opcode to jump
aa112:  lda     #24
        clc
        adc     kernelLst,x
        tax
        lda     hole_pos,x      ; Now get the X-coordinate for hole
        ldx     temp1
        sec                     ; There's an X-coordinate, center spider over it
        sbc     #2
        jmp     aa116

        ;
        ; Spider at same level than tongue tip
        ;
aa109:  lda     tip_x
        asl
        asl
        beq     aa116
        sbc     #1
aa116:  sbc     enemy0_x,x      ; Take a decision of direction to move
        beq     aa119           ; At target position? yes, jump
        bcc     aa44
        bcs     aa40

        ;
        ; Try to lower spider by one level
        ;
aa119:  cpx     #1              ; Is spider at bottom-most position?
        beq     aa41            ; Yes, jump, stay quiet
        cpx     #9
        beq     aa41
        lda     enemy0_t-1,x    ; Is it busy the next enemy slot?
        bne     aa41            ; Yes, jump, stay quiet
        lda     enemy0_x,x      ; Copy X position
        sta     enemy0_x-1,x
        lda     enemy0_t,x      ; Copy type
        sta     enemy0_t-1,x
        lda     #0              ; Erase spider from old slot
        sta     enemy0_t,x
        beq     aa41

        ;
        ; Ant, red ant, worm or centipede
        ;
aa108:
        cmp     #sprite_queen_ant
        beq     aa38
        cmp     #sprite_queen_ant+$10
        beq     aa38
        lda     enemy0_t,x
        and     #ENEMY_SPEED_MASK; Fast?
        beq     aa44
        lda     frame
        and     #$04
aa38sc: bne     aa38
aa44:
        lda     enemy0_t,x
        and     #ENEMY_DIR_MASK ; Goes to left?
        bne     aa40            ; No, jump
        dec     enemy0_x,x
        lda     enemy0_x,x
        cmp     #ENEMY_MIN_X    ; Reached left limit?
        bne     aa41            ; No, jump
aa42:
        lda     enemy0_t,x
        and     #$f0
        cmp     #sprite_worm
        bne     aa98
        lda     flags
        and     #~FLAGS_WORM
        sta     flags
aa98:   cmp     #sprite_spider  ; It could happen *sigh*
        bne     aa107
        lda     flags
        and     #~FLAGS_SPIDER
        sta     flags
aa107:  lda     #0
        sta     enemy0_t,x
        beq     aa38

aa40:
        inc     enemy0_x,x
        lda     enemy0_x,x
        cmp     #ENEMY_MAX_X    ; Reached right limit?
        beq     aa42            ; Yes, jump
aa41:
        tya
        eor     enemy0_t,x      ; Changed animation frame if required
        sta     enemy0_t,x
aa38:   dex
        bmi     aa43
        jmp     aa10
aa43:

        ;
        ; Queen ant flashing
        ;
        lda     frame
        and     #$01
        bne     aa34
        lda     enemy0_t
        beq     aa32
        cmp     #non_interactive_sprites
        bcs     aa51
        adc     #1
        cmp     #sprite_1000+8
        bne     aa32
        jsr     score_points_2  ; 1000 points
        lda     #0
        beq     aa32

aa51:   adc     #$07
        cmp     #sprite_queen_ant+$20
        bcc     aa32
        sbc     #$20
aa32:   sta     enemy0_t

        lda     enemy8_t
        beq     aa33
        cmp     #non_interactive_sprites
        bcs     aa50
        adc     #1
        cmp     #sprite_1000+8
        bne     aa33
        jsr     score_points_2  ; 1000 points
        lda     #0
        beq     aa33

aa50:   adc     #$07
        cmp     #sprite_queen_ant+$20
        bcc     aa33
        sbc     #$20
aa33:   sta     enemy8_t
aa34:
        ;
        ; Count frame, step on random generator
        ;
        inc     frame
        jsr     random_proc
        ;
        ; Aardvark enters game
        ;
        ldx     aa_x_pos
        cpx     #52
        beq     aa7
        lda     frame
        and     #$07
        bne     aa31
        inc     aa_x_pos
        cpx     #51
        bne     aa31
        ; Start tongue
        lda     #$02
        sta     holeCols+7
        ldx     #19
        stx     tip_x
        lda     #7
        sta     tip_y
        lda     #0
        sta     tip_dir
        jsr     point_egg
        ldx     tip_x
        lda     tip_y
        jsr     draw_block
aa31:
        lda     frame
        and     #$07
        bne     aa4
        lda     aa_offset
        eor     #$28
        sta     aa_offset
aa4:
        jmp     aa20

aa7:
        lda     #0

        jsr     fire_button     ; Fire button pressed?
        bpl     aa22            ; No, jump

        ldx     tip_x           ; Get tongue coordinates
        lda     tip_y
        cpx     #19
        bne     aa19
        cmp     #7
        beq     aa123           ; Is it at base? yes, jump without doing anything
aa19:
        jsr     clear_block
        lda     effect0
        cmp     #128
        bcs     aa122
        cmp     #66
        bcs     aa121
aa122:
        lda     #66
        sta     effect0
aa121:  ldx     tip_x
        beq     aa23
        dex
        lda     tip_y
        jsr     check_block
        bne     aa24
        inx

aa23:   cpx     #39
        beq     aa25
        inx
        lda     tip_y
        jsr     check_block
        bne     aa24

aa25:   ldx     tip_y
        lda     #$00
        sta     holeCols,x
        inc     tip_y
        jmp     aa20

aa24:   stx     tip_x
        jmp     aa20

aa123:  jmp     aa28

aa22:
        jsr     build_hole_map
        lda     SWCHA
        ; Note #$10 isn't used (going up)
        and     #$20            ; Going down?
        beq     aa17            ; Yes, jump
aa18:   lda     SWCHA
        bmi     aa16            ; Going right? No, jump
        lda     tip_y
        bmi     aa28
        beq     aa28            ; Last tunnel? Yes, cannot move
        lda     frame
        lsr
        bcc     aa28
        ldx     tip_x
        cpx     #39
        beq     aa28
        inx
aa26:   lda     tip_y
        jsr     check_block
        bne     aa30
        txa
        sec
        sbc     tip_x
        sta     tip_dir
        stx     tip_x
        lda     tip_y
        jsr     point_egg
        ldx     tip_x
        lda     tip_y
        jsr     draw_block
        jmp     aa20

aa30:   txa
        pha
        ldx     tip_x
        lda     tip_y
        jsr     clear_block
        pla
        sta     tip_x
aa28:   jmp     aa20

aa16:   rol                     ; Going left?
        bmi     aa20
        lda     tip_y
        bmi     aa20
        beq     aa20            ; Last tunnel? Yes, cannot move
        lda     frame
        lsr
        bcc     aa20
        ldx     tip_x
        beq     aa20
        dex
        bpl     aa26

        ;
        ; Going down
        ;
aa17:   ldx     tip_y           ; Get row of tongue tip
        bmi     aa18            ; Invalid? Yes, jump to check for right/left
        beq     aa18            ; Vertical limit? Yes, jump to check for right/left
        lda     kernelLst-1,x
        tax
        lda     tip_x           ; Tongue tip at 0?
        beq     aa18            ; Jump to check for right/left
        cmp     hole_pos,x
        beq     aa126
        cmp     hole_pos+8,x
        beq     aa27
        cmp     hole_pos+16,x
        beq     aa115
        cmp     hole_pos+24,x
        bne     aa18            ; No hole, so jump to check for right/left
        ldy     #$01
        .byte   $2c             ; BIT opcode to jump
aa115:  ldy     #$02
        .byte   $2c             ; BIT opcode to jump
aa126:  ldy     #$08
        .byte   $2c             ; BIT opcode to jump
aa27:   ldy     #$04
        tya
        ldx     tip_y
        dex
        ora     holeCols,x
        sta     holeCols,x
        stx     tip_y
        txa
        ldx     tip_x
        jsr     point_egg
        ldx     tip_x
        lda     tip_y
        jsr     draw_block
        lda     #0
        sta     tip_dir

aa20:

wait_overscan:
        lda     INTIM
        bne     wait_overscan
        sta     WSYNC
        sta     WSYNC

        lda     aa_x_pos
        cpx     #135
        bne     aa74
        jsr     bonus_screen
        jmp     next_level
aa74:

        lda     flags
        and     #$03
        cmp     #$02            ; Has finished tongue color changing animation?
        beq     aa68            ; Yes, jump
        jmp     main_loop       ; Continue with main loop

aa68:   dec     lives
        jsr     bonus_screen
        lda     lives
        bmi     aa89
        jmp     restart_level   ; Restart level

aa89:   jmp     title_screen

        ;
        ; Bonus screen
        ;
bonus_screen:
        ldx     worms_eaten
        beq     aa99
aa100:
        lda     ants_eaten
        jsr     score_points
        dex
        bne     aa100
aa99:
        rts

        ;
        ; Run random number generator
        ;
random_proc:
        ;
        ; Random number generator
        ;
        lda     rand
        sec
        ror
        eor     frame
        ror
        eor     rand
        ror
        eor     #9
        sta     rand
        rts

        ;
        ; Check for fire button
        ;
fire_button_single:
        lda     INPT4
        eor     #$ff
        tax
        eor     prev_button
        stx     prev_button
        bpl     fire_button1
        txa
fire_button1:
        rts

fire_button:
        lda     INPT4
        eor     #$ff
        sta     prev_button
        rts

        ;
        ; Calculate memory zone for tongue block
        ; a = zone (0-7)
        ;
calc_zone:
        asl                     ; x2
        asl                     ; x4
        sta     en0
        asl                     ; x8
        adc     en0             ; x12
        adc     #tongue1
        sta     en0
        adc     #<R
        sta     en1
        lda     #>W
        sta     en0+1
        sta     en1+1
        rts

        ;
        ; Check for tongue block
        ;
        ; a = zone (0-5)
        ; x = x pixel (0-39)
        ;
check_block:
        jsr     calc_zone
        lda     pixel_to_byte,x
        tay
        lda     (en1),y
        and     pixel_to_bit,x
        rts

        ;
        ; Clear enemies (used when eating queen ant)
        ;
clear_enemies:
        txa
        pha
        ldx     #9
aa61:   lda     enemy0_t,x
        cmp     #non_interactive_sprites
        bcc     aa62
        and     #$f0
        cmp     #sprite_worm
        beq     aa63
        cmp     #sprite_spider
        beq     aa104
        cmp     #pricey_sprites
        bcs     aa64
        lda     #sprite_explosion
        .byte   $2c             ; BIT opcode to jump
aa63:   lda     #sprite_200
        .byte   $2c             ; BIT opcode to jump
aa64:   lda     #sprite_150
        .byte   $2c             ; BIT opcode to jump
aa104:  lda     #sprite_200_spider
        sta     enemy0_t,x
        cmp     #sprite_200_spider
        bne     aa105
        lda     flags
        and     #~FLAGS_SPIDER
        sta     flags
aa105:
        cmp     #sprite_200     ; Only a worm gives a 200 points bonus
        bne     aa62
        lda     flags
        and     #~FLAGS_WORM
        sta     flags
aa62:   dex
        bpl     aa61
        pla
        tax
        lda     #sprite_1000
        rts

        ;
        ; Give points per egg eaten
        ;
        ; a = zone (0-7)
        ; x = x pixel (0-39)
        ;
point_egg:
        cmp     #0
        beq     aa35
        jsr     calc_zone
        lda     en1
        clc
        adc     #tongue_to_eggs
        sta     en1
        lda     pixel_to_byte,x
        tay
        lda     (en1),y
        and     pixel_to_bit,x
        beq     aa35
        lda     eggs
        ror
        lda     #1
        bcc     aa77
        lda     #6
aa77:   sta     effect0
        dec     eggs
        lda     #1

        ; Score 1 point for egg eaten
score_points:
        clc
        sed
        adc     score
        sta     score
aa48:   lda     score+1
        adc     #0
        sta     score+1
        lda     score+2
        adc     #0
        sta     score+2
        cld
aa35:
        rts

score_points_2:
        sec
        sed
        bcs     aa48

        ;
        ; Draw a tongue block
        ;
        ; a = zone (0-7)
        ; x = x pixel (0-39)
        ;
draw_block:
        jsr     calc_zone
        lda     pixel_to_byte,x
        tay
        lda     (en1),y
        ora     pixel_to_bit,x
        sta     (en0),y
        lda     en0
        clc
        adc     #tongue_to_eggs
        sta     en0
        lda     en1
        adc     #tongue_to_eggs
        sta     en1
        lda     (en1),y
        ora     pixel_to_bit,x
        sta     (en0),y
        rts

        ;
        ; Clear a tongue block
        ;
        ; a = zone (0-7)
        ; x = x pixel (0-39)
        ;
clear_block:
        jsr     calc_zone
        lda     pixel_to_byte,x
        tay
        lda     (en1),y
        and     pixel_to_bit2,x
        sta     (en0),y
        lda     en0
        clc
        adc     #tongue_to_eggs
        sta     en0
        lda     en1
        adc     #tongue_to_eggs
        sta     en1
        lda     (en1),y
        and     pixel_to_bit2,x
        sta     (en0),y
        rts

        ;
        ; Build random hole map for the current level seed
        ; See also random.c
        ;
build_hole_map: SUBROUTINE
.lastPat        = tmpVars
        lda     #255
        sta     .lastPat
        ldy     #NUM_FLOORS-1
        ldx     level_seed
.0:
        lda     random_level,x
        tax
        and     #$07
        cmp     .lastPat
        bne     .1
        txa
        lsr
        lsr
        tax
        and     #$07
.1:
        sta     kernelLst,y
        sta     .lastPat
        dey
        bne     .0
        sty     kernelLst       ; Fixed tunnel for queen ants
        rts

        ;
        ; With the help of:
        ;
        ; http://alienbill.com/2600/basic/music/tune2600.html
        ; http://piano-player.info/
        ;

        ;
        ; Songs refer to these notes.
        ; These notes contain frequency and "instrument" and are
        ; choosen per usage in song instead of full "continuous" octaves
        ;
music_notes:
        .byte   12,12           ; 1
        .byte   4,28
        .byte   4,25            ; 3
        .byte   4,22
        .byte   4,18            ; 5
        .byte   4,16

        .byte   12,20           ; 7
        .byte   12,19
        .byte   12,18           ; 9
        .byte   12,17
        .byte   12,15           ; 11
        .byte   12,14
        .byte   12,13           ; 13
        .byte   12,11
        .byte   4,31            ; 15

        .byte   6,7             ; 16
        .byte   6,6             ; 17
        .byte   12,27           ; 18
        .byte   12,23           ; 19

        .byte   0,0             ; 20 Unused

        .byte   6,7             ; 21
        .byte   12,30
        .byte   12,27           ; 23
        .byte   12,24
        .byte   12,20           ; 25
        .byte   12,18

        .byte   0,0             ; 27 Unused
        .byte   1,12            ; 29
        .byte   1,6             ; 31
        .byte   1,13            ; 33
        .byte   1,9             ; 35
        .byte   0,0

        ;
        ; Global label to access music
        ;
music:

        ;
        ; Ranz des vaches
        ;
music_ranz_des_vaches:
        .byte   6*32+2,22       ; 1 -> tracker
        .byte   1*32+3,23
        .byte   1*32+1,21
        .byte   1*32+2,22
        .byte   1*32+4,24
        .byte   1*32+1,21

        .byte   6*32+2,22
        .byte   1*32+3,23
        .byte   1*32+1,21
        .byte   1*32+2,22
        .byte   1*32+4,24
        .byte   1*32+1,21

        .byte   6*32+2,22
        .byte   1*32+4,24
        .byte   1*32+6,26
        .byte   1*32+5,25
        .byte   1*32+1,21
        .byte   1*32+4,24

        .byte   5*32+3,23
        .byte   1*32+5,25

        .byte   0,0

        ;
        ; Mountain king
        ;
music_mountain_king:
        .byte   2*32+7,16       ; 43 -> tracker
        .byte   2*32+9,16
        .byte   2*32+10,18
        .byte   2*32+11,18
        .byte   2*32+13,16
        .byte   2*32+10,16
        .byte   4*32+13,18

        .byte   2*32+12,16
        .byte   2*32+9,16
        .byte   4*32+12,18
        .byte   2*32+11,16
        .byte   2*32+8,16
        .byte   4*32+11,18

        .byte   2*32+7,16
        .byte   2*32+9,16
        .byte   2*32+10,18
        .byte   2*32+11,18
        .byte   2*32+13,16
        .byte   2*32+10,16
        .byte   2*32+13,18
        .byte   2*32+15,18

        .byte   2*32+14,17
        .byte   2*32+13,17
        .byte   2*32+10,19
        .byte   2*32+13,19
        .byte   7*32+14,17

        .byte   0,0

        ;
        ; Death music
        ;
music_touch:
        .byte   4*32+28,28      ; 97 -> tracker
        .byte   4*32+29,29
        .byte   4*32+30,30
        .byte   7*32+31,31
        .byte   0,0

        ;
        ; Global label to access sound effects
        ;
sound_effect:
        .byte   0

        .byte   $04,$81         ; 1 Eating egg (1)
        .byte   $03,$71         ; 3
        .byte   0               ; 5

        .byte   $08,$81         ; 6 Eating egg (2)
        .byte   $07,$71         ; 8
        .byte   0               ; 10

        .byte   $07,$88         ; 11 Eating bug
        .byte   $06,$88         ; 13
        .byte   $07,$88         ; 15
        .byte   $06,$88         ; 17
        .byte   0               ; 19

        .byte   $1c,$fc         ; 20 Eating worm
        .byte   $1c,$cc         ; 22
        .byte   $1c,$ac         ; 24
        .byte   $1c,$8c         ; 26
        .byte   $1c,$6c         ; 28
        .byte   $1c,$4c         ; 30
        .byte   0               ; 32

        .byte   $1c,$fc         ; 33 Eating queen
        .byte   $1c,$cc         ; 35
        .byte   $1c,$ac         ; 37
        .byte   $1c,$8c         ; 39
        .byte   $1c,$6c         ; 41
        .byte   $1c,$4c         ; 43
        .byte   $10,$ec         ; 45
        .byte   $10,$cc         ; 47
        .byte   $10,$ac         ; 49
        .byte   $10,$6c         ; 51
        .byte   $10,$4c         ; 53
        .byte   $10,$3c         ; 55
        .byte   $10,$4c         ; 57
        .byte   $10,$3c         ; 59
        .byte   $10,$4c         ; 61
        .byte   $10,$3c         ; 63
        .byte   0               ; 65

        .byte   $1f,$c4         ; 66 Retrain tongue
        .byte   $1e,$b4         ; 68
        .byte   $1d,$c4         ; 70
        .byte   $1c,$b4         ; 72
        .byte   $1b,$c4         ; 74
        .byte   $1a,$b4         ; 76
        .byte   $19,$c4         ; 78
        .byte   $18,$b4         ; 80
        .byte   $17,$c4         ; 82
        .byte   $16,$b4         ; 84
        .byte   $15,$c4         ; 86
        .byte   $14,$b4         ; 88
        .byte   $13,$c4         ; 90
        .byte   $12,$b4         ; 92
        .byte   $11,$c4         ; 94
        .byte   $10,$b4         ; 96
        .byte   $0f,$c4         ; 98
        .byte   $0e,$b4         ; 100
        .byte   $0d,$c4         ; 102
        .byte   $0c,$b4         ; 104
        .byte   $0b,$c4         ; 106
        .byte   $0a,$b4         ; 108
        .byte   $09,$c4         ; 110
        .byte   $08,$b4         ; 112
        .byte   $07,$c4         ; 114
        .byte   $06,$b4         ; 116
        .byte   $05,$c4         ; 118
        .byte   $04,$b4         ; 120
        .byte   $03,$c4         ; 122
        .byte   $02,$b4         ; 124
        .byte   $01,$c4         ; 126
        .byte   0

        .byte   $18,$c1         ; 129 Click effect for sunset
        .byte   $0c,$61         ; 131
        .byte   $06,$a1         ; 133
        .byte   $03,$41         ; 135
        .byte   $02,$81         ; 137
        .byte   $01,$21         ; 139
        .byte   0

        echo    "Before random_level at $fd00: ",*

        org     $fd00

        .include "aardlev.asm"

        org     $fe00
fine_adjustment:
        .byte   $70             ; -7
        .byte   $60             ; -6
        .byte   $50             ; -5
        .byte   $40             ; -4
        .byte   $30             ; -3
        .byte   $20             ; -2
        .byte   $10             ; -1
        .byte   $00             ; 0
        .byte   $f0             ; +1
        .byte   $e0             ; +2
        .byte   $d0             ; +3
        .byte   $c0             ; +4
        .byte   $b0             ; +5
        .byte   $a0             ; +6
        .byte   $90             ; +7

pixel_to_byte:
        .byte   0,0,0,0,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2
        .byte   3,3,3,3,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5

pixel_to_bit:
        .byte   $10,$20,$40,$80
        .byte   $80,$40,$20,$10,$08,$04,$02,$01
        .byte   $01,$02,$04,$08,$10,$20,$40,$80

        .byte   $10,$20,$40,$80
        .byte   $80,$40,$20,$10,$08,$04,$02,$01
        .byte   $01,$02,$04,$08,$10,$20,$40,$80

pixel_to_bit2:
        .byte   $ef,$df,$bf,$7f
        .byte   $7f,$bf,$df,$ef,$f7,$fb,$fd,$fe
        .byte   $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

        .byte   $ef,$df,$bf,$7f
        .byte   $7f,$bf,$df,$ef,$f7,$fb,$fd,$fe
        .byte   $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f

        ;
        ; Position for holes (in "fat" pixels)
        ; Note vertical sorting, one line of holes is made from one column of data.
        ;      A  B  C  D  E  F  G  H
        ;
hole_pos:
        .byte   0, 6, 3, 0, 0, 0, 0, 0
        .byte   12,12, 9, 6, 9, 3, 0,15
        .byte   26,18,20,26,23,15,18,23
        .byte   0,32,35,32, 0,29,29,35

        ;
        ; Lives representation as playfield graphics
        ;
lives_pf:
        .byte   $00,$40,$40,$40,$40,$40,$40,$40
        .byte   $00,$00,$80,$a0,$a8,$aa,$aa,$aa
        .byte   $00,$00,$00,$00,$00,$00,$01,$05

        ;
        ; Refilling constant per level
        ;
refilling:
        .byte   128,126,124,122,120,118,116,114
        .byte   112,110,108,106,104,102,100,98
        .byte   96,94,92,90,88,86,84,82
        .byte   80,78,76,74,72,70,68,66

        ;
        ; Enemies per tunnel
        ;
enemies_going_right:
        .byte   0
        .byte   0
        .byte   sprite_caterpillar+ENEMY_DIR_MASK
        .byte   sprite_red_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   0
        .byte   0
        .byte   sprite_caterpillar+ENEMY_DIR_MASK
        .byte   sprite_red_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK
        .byte   sprite_ant+ENEMY_DIR_MASK

enemies_going_left:
        .byte   0
        .byte   0
        .byte   sprite_caterpillar
        .byte   sprite_red_ant
        .byte   sprite_ant
        .byte   sprite_ant
        .byte   sprite_ant
        .byte   sprite_ant
        .byte   0
        .byte   0
        .byte   sprite_caterpillar
        .byte   sprite_red_ant
        .byte   sprite_ant
        .byte   sprite_ant
        .byte   sprite_ant
        .byte   sprite_ant

        org     $ff00
numbers:
        .byte   $fe,$c6,$c6,$c6,$fe,$00,$00,$00
        .byte   $78,$30,$30,$70,$30,$00,$00,$00
        .byte   $fe,$c0,$fe,$06,$fe,$00,$00,$00
        .byte   $fe,$06,$fe,$06,$fe,$00,$00,$00
        .byte   $06,$06,$fe,$c6,$c6,$00,$00,$00
        .byte   $fe,$06,$fe,$c0,$fe,$00,$00,$00
        .byte   $fe,$c6,$fe,$c0,$fe,$00,$00,$00
        .byte   $18,$18,$0c,$06,$fe,$00,$00,$00
        .byte   $fe,$c6,$fe,$c6,$fe,$00,$00,$00
        .byte   $fe,$06,$fe,$c6,$fe,$00,$00,$00

        org     $fffc
        .word   START           ; RESET
        .word   START           ; BRK

