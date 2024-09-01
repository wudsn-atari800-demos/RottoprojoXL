; >>> RottoprojoXL - Players and Missiles Dot Cube in 254 bytes <<<
;
; (c) 2011-05-23 by JAC! of WUDSN
;
; I coded this one to prove that I'am absolutely bad in many things...
; ... design, graphics, sound, cooking, ...
; ... but hell, I do know size coding on Atari ;-)
; 
; Based on the awesome code by Skate / Plush. Man you rule!
; Related to: Rottoprojo64 Coder Pron
; https://www.pouet.net/prod.php?which=56981
; 
; When I first saw Skate's prod I simply could not believe it.
; He did in 256 bytes what I had always planned for 512, one day, maybe.
; Later, he posted the following, and then I could not stop my synapses anymore.
; 
; [quote]
; I'll give you a nice example on how multiplatform 128b/256b or any similar
; size competition doesn't make sense at all.
; Here is my recently releases c64 256b (254 actually) cube rotation effect:
; https://www.pouet.net/prod.php?which=56981
; And here is the Atari 800 XL/XE port:
; http://www.akaydin.com/atari/codes/skate/previews/rottoprojo800.zip
; Both machines are 6502 based and core code is exactly the same.
; But because of the c64 and atari sprite structure differences 
; actually sprites are called players & missiles on Atari platform)
; Atari version is 384 bytes at the moment. It can be optimized but
; i don't think i will ever be able to reach 256 bytes.
; I'll try using graphic modes but i don't think it will help so much.
; [/quote]
; 
; For three days, I could not stop arranging the bytes in my head.
; Over and over again. Now, I'm released from this pain. Phew.
;
; This version also has some "sound", "sync" and "colors".
; And I kept the original file size despite my lovely 6-byte Heather.
; With the optimizations contained here, the core of the computation
; is down to 170 bytes. So a C64 version would be much smaller
; but I'm preparing something that will beat it anyway ;-)
;
; Load from MyPicoDos or any other game DOS.
; Created using WUDSN IDE, visit https://www.wudsn.com for more.

;Constants
CUBE_SIZE	= 61
DISTANCE	= 137
POINTS		= 4
HIGH		= POINTS

; Zeropage Addresses
cnt		= $14
vertexX		= $80	;8 bytes for 4x16-bit vertex coordinates
vertexY		= $88	;8 bytes for 4x16-bit vertex coordinates
vertexZ		= $90	;8 bytes for 4x16-bit vertex coordinates
object		= $98	;Object counter
rotatedVertex	= $99	;Low part of 16-bit vertex coordinate
storage1	= $ba
storage2	= $bb
p1		= $bc

; Main Memory Addresses
pmbase	= $7800

	opt l+
	org $2000

;
; Rotate Vertex
; -------------
; Description:
; Rotates a vertex on 1 or 2 axes.
; First rotation is on z-axis
; Second rotation is on y-axis (optional, depends on the state flag)
; IN: X
; OUT: X, unchanged
; DESTROYS: A,Y

	.macro m_rotate_vertex
	; Rotate on z-axis
	ldy vertexY,x
	lda vertexY+HIGH,x
	jsr rotate_single_axis
	sta vertexY,x
	sty vertexY+HIGH,x

	lda cnt			;128/50s axis toggle
	bpl skip
	; Rotate on y-axis
	ldy vertexZ,x
	lda vertexZ+HIGH,x
	jsr rotate_single_axis
	sta vertexZ,x
	sty vertexZ+HIGH,x
skip	ora #$a8		;Must not be in the ".endm" line, otherwise MADS loops forever
	sta $d200,x
	.endm

;===============================================================

	.proc main
	ldx #CUBE_SIZE		;Warning! Loop counter equals to cube size
	txa
init_loop
	sta vertexX,x		;Set positive size values as default vertex
	dex
	bpl init_loop

	lda #$ff-CUBE_SIZE	;Inverted cube size
	sta vertexZ+1+HIGH	;Vertex2 Z coordinate high-byte
	sta vertexY+2+HIGH	;Vertex3 Y coordinate high-byte
	sta vertexY+3+HIGH	;Vertex4 Y coordinate high-byte
	sta vertexZ+3+HIGH	;Vertex4 Z coordinate high-byte

	.proc vertex_loop
	dec object
	lda #$0f
	sta $d01d
	sta $22f
	lsr
	and object
	sta object
	cmp #4			;We don't need to rotate all 8 vertexes
	and #3
	tax
	bcs mirrors		;We can use mirroring, right?

	m_rotate_vertex		;Does not change X
	lda #$00		;Do not invert
	.byte $2c		;Skip
mirrors
	lda #$ff		;Invert
positive
	pha			;X=0..7 step 2, A=$00/$ff
	pha
	eor vertexZ+HIGH,x
	adc #DISTANCE		;\
	lsr			; \
	lsr			;  \
	sta storage1		;   Magical Linear Projection
	lsr			;  /
	adc storage1		; /
	adc #$26		;/
	sta storage1

	pla
	eor vertexX+HIGH,x
	jsr calculate_coordinate
	ldy object
	adc #$80
	sta $d000,y

	pla
	eor vertexY+HIGH,x
	jsr calculate_coordinate
	adc #$40
	tay			;Y coordinate

	.proc print
	lda object
	cmp #4
	bcs missles
	lsr
	ora #>(pmbase+$200)
	sta p1+1
	lda #$00
	ror			;$00 or $80
	ldx #7			;$02 / $fd mask
	bne player

missles	tax
	lda #>(pmbase+$100)
	sta p1+1
	sta $d407		;Lower 2 bits are ignored by hardware
	lda #$80
player	sta p1
	lda pm_mask-4,x
	sta $2c0-4,x		;C=1, X=4..7 => sets $2c0..$2c3 to $ff
	pha
	pha
	and (p1),y
	sta (p1),y
	iny
	pla
	eor #$ff
	ora (p1),y
	sta (p1),y
	iny
	pla
	and (p1),y
	sta (p1),y

	.endp			;End of plot

	.print "PROC print:	", print, " - ", print+.len print-1, " (", .len print, " bytes)"

	jmp vertex_loop
	.endp

; Calculate Coordinate
; --------------
; Description:
; Multiplies rotated coordinate with perspective
; value and adds a constant value to move the cube
; in the visible screen area. This routine is used
; for both X and Y coordinates.
;
	.proc calculate_coordinate
	bpl multiply
	eor #$ff		; for negative values invert
	jsr multiply		; multiply
	eor #$ff		; and invert again
	rts
;
; Multiply
; --------
; Description:
; Modified unsigned 8-bit multiplication routine.
; Only high byte of the 16-bit result is used.
; Returns with Y=0 and X unchanged

	.proc multiply
	sta storage2
	lda #8
    	ldy #9
loop	lsr
	ror storage2
	bcc not_set
	adc storage1
not_set	dey
	bne loop
	rts
	.endp
	
	.endp

; Rotate On Single Axis
; ---------------------
; Description:
; Rotates a vertex on a single axis
; to rotate on x-axis inputs should be y and z coordinates
; to rotate on y-axis inputs should be x and z coordinates
; to rotate on z-axis inputs should be x and y coordinates
;
; Input:
; vertexCoordinate1 : signed 16-bit coordinate (x,y or z)
; vertexCoordinate2 : signed 16-bit coordinate (x,y or z)
;
; Formula:
; vertexCoordinate1 -= vertexCoordinate2 / 256
; vertexCoordinate2 += vertexCoordinate1 / 256
; p.s: "/ 256" means getting the high byte
;
; Comment:
; Skate can rotate vertexes by addition and subtraction
; without needing any tables or lame trigonometric stuff. ;)
;

; IN: A=Value for rotatedVertex, Y = Value for rotatedVertex+HIGH
; OUT: A=Value of rotatedVertex, Y = Value of rotatedVertex+HIGH
	.proc rotate_single_axis
	sty rotatedVertex
	tay
	; vertexCoordinate1 -= vertexCoordinate2 / 256
	clc			;Optional, you won't see the difference
	eor #$ff
	bmi skip1
	
	adc vertexX,x
	bcc skip2
	inc vertexX+HIGH,x
	bcs skip2

skip1	adc vertexX,x
	bcs skip2
	dec vertexX+HIGH,x

skip2	sta vertexX,x

	; vertexCoordinate2 += vertexCoordinate1 / 256
	lda vertexX+HIGH,x
	clc
	bpl skip3

	eor #$ff
	adc rotatedVertex
	bcc skip4
	dey
;	bcs skip4
	rts

skip3	adc rotatedVertex
	bcc skip4
	iny

skip4	rts
	.endp


pm_mask	.byte $fd,$f7,$df,$7f
	.endp

	.print "PROC main:	", main, " - ", main+.len main-1, " (", .len main, " bytes)"
