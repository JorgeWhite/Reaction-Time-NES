.setcpu "6502"

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
JOY1      = $4016
APUFRAME  = $4017
DMCFREQ   = $4010

STATE_MENU     = $00
STATE_SETTINGS = $01
STATE_WAIT     = $02
STATE_GO       = $03
STATE_RESULT   = $04
STATE_INVALID  = $05
STATE_SUMMARY  = $06

BTN_A    = $01
BTN_B    = $02
BTN_UP   = $10
BTN_DOWN = $20

COLOR_BLUE  = $01
COLOR_GREEN = $2A
COLOR_ALERT = $16

MAX_FRAMES_LO = $4A
MAX_FRAMES_HI = $27

LINE_LEN  = 22
FRAME_LEN = 5
MS_LEN    = 8
AVG_FRAME_LEN = 6

L0_ADDR_LO = $25
L0_ADDR_HI = $21
L1_ADDR_LO = $65
L1_ADDR_HI = $21
L2_ADDR_LO = $A5
L2_ADDR_HI = $21
L3_ADDR_LO = $E5
L3_ADDR_HI = $21
SUM_L2_ADDR_LO = $C5
SUM_L2_ADDR_HI = $21
SUM_L3_ADDR_LO = $25
SUM_L3_ADDR_HI = $22

T_SPACE = 0
T_0     = 1
T_1     = 2
T_2     = 3
T_3     = 4
T_4     = 5
T_5     = 6
T_6     = 7
T_7     = 8
T_8     = 9
T_9     = 10
T_A     = 11
T_E     = 12
T_F     = 13
T_G     = 14
T_I     = 15
T_L     = 16
T_M     = 17
T_O     = 18
T_P     = 19
T_R     = 20
T_S     = 21
T_T     = 22
T_W     = 23
T_Y     = 24
T_COLON = 25
T_DOT   = 26
T_BANG  = 27
T_B     = 28
T_D     = 29
T_N     = 30
T_U     = 31
T_V     = 32
T_DASH  = 33
T_SLASH = 34
T_GT    = 35
T_C     = 36

.segment "HEADER"
  .byte "NES", $1A
  .byte 2       ; 2x 16KB PRG ROM (32KB)
  .byte 0       ; CHR RAM
  .byte $00
  .byte $00
  .res 8, 0

.segment "ZEROPAGE"
nmi_ready:      .res 1
game_state:     .res 1
bg_color:       .res 1

pad_prev:       .res 1
pad_curr:       .res 1
pad_new:        .res 1

render_phase:   .res 1
render_pending: .res 1

menu_cursor:    .res 1
setting_idx:    .res 1
avg_target:     .res 1
trial_count:    .res 1

seed_lo:        .res 1
seed_hi:        .res 1
delay_lo:       .res 1
delay_hi:       .res 1
reaction_lo:    .res 1
reaction_hi:    .res 1
go_latched:     .res 1
sum_lo:         .res 1
sum_hi:         .res 1
midsum_lo:      .res 1
midsum_mid:     .res 1
midsum_hi:      .res 1
avg_lo:         .res 1
avg_hi:         .res 1

val_lo:         .res 1
val_hi:         .res 1

tmp16_lo:       .res 1
tmp16_hi:       .res 1
ms_val_lo:      .res 1
ms_val_mid:     .res 1
ms_val_hi:      .res 1
work_lo:        .res 1
work_mid:       .res 1
work_hi:        .res 1

divisor:        .res 1
digit_temp:     .res 1
digit_tens:     .res 1
digit_ones:     .res 1
rem8:           .res 1
loop_ctr:       .res 1
summary_lock:   .res 1

ptr_lo:         .res 1
ptr_hi:         .res 1
dst_lo:         .res 1
dst_hi:         .res 1

nmi_ptr_lo:     .res 1
nmi_ptr_hi:     .res 1
nmi_len:        .res 1
nmi_addr_lo:    .res 1
nmi_addr_hi:    .res 1

digits8:        .res 8

line0:          .res LINE_LEN
line1:          .res LINE_LEN
line2:          .res LINE_LEN
line3:          .res LINE_LEN

frame_buf:      .res FRAME_LEN
lower_ms_buf:   .res MS_LEN
upper_ms_buf:   .res MS_LEN
avg_frame_buf:  .res AVG_FRAME_LEN
avg_ms_buf:     .res MS_LEN

.segment "CODE"
.proc Reset
  sei
  cld

  ldx #$40
  stx APUFRAME
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx DMCFREQ

  jsr InitState
  jsr WaitVBlank
  jsr WaitVBlank
  jsr LoadChrTiles
  jsr ClearNametable

  jsr EnterMenuState

  lda #%10000000
  sta PPUCTRL
  lda #%00001010
  sta PPUMASK

MainLoop:
  jsr WaitFrame
  jsr AdvanceSeed
  jsr UpdateGame
  jmp MainLoop
.endproc

.proc NMI
  pha
  txa
  pha
  tya
  pha

  jsr PollController
  jsr TickGoTiming

  jsr RenderFrame

  lda #1
  sta nmi_ready

  pla
  tay
  pla
  tax
  pla
  rti
.endproc

.proc IRQ
  rti
.endproc

.proc InitState
  lda #0
  sta nmi_ready
  sta game_state
  sta pad_prev
  sta pad_curr
  sta pad_new
  sta render_phase
  sta render_pending
  sta summary_lock
  sta menu_cursor
  sta trial_count
  sta delay_lo
  sta delay_hi
  sta reaction_lo
  sta reaction_hi
  sta go_latched
  sta sum_lo
  sta sum_hi
  sta midsum_lo
  sta midsum_mid
  sta midsum_hi
  sta avg_lo
  sta avg_hi

  lda #$2B
  sta seed_lo
  lda #$1D
  sta seed_hi

  lda #1
  sta setting_idx
  lda #5
  sta avg_target

  lda #COLOR_BLUE
  sta bg_color
  rts
.endproc

.proc WaitVBlank
@wait:
  bit PPUSTATUS
  bpl @wait
  rts
.endproc

.proc WaitFrame
@wait:
  lda nmi_ready
  beq @wait
  lda #0
  sta nmi_ready
  rts
.endproc

.proc PollController
  lda pad_curr
  sta pad_prev

  lda #1
  sta JOY1
  lda #0
  sta JOY1

  lda #0
  sta pad_curr

  ldx #0
@read_loop:
  lda JOY1
  and #$01
  beq @next
  lda pad_curr
  ora PadMask, x
  sta pad_curr
@next:
  inx
  cpx #8
  bne @read_loop

  lda pad_prev
  eor #$FF
  and pad_curr
  sta pad_new
  rts
.endproc

.proc AdvanceSeed
  lda seed_hi
  lsr a
  sta seed_hi
  lda seed_lo
  ror a
  sta seed_lo
  bcc @done
  lda seed_hi
  eor #$B4
  sta seed_hi
@done:
  rts
.endproc

.proc GenerateDelay
  lda seed_lo
@mod:
  cmp #$B5
  bcc @in_range
  sec
  sbc #$B5
  bcs @mod
@in_range:
  clc
  adc #$78
  sta delay_lo
  lda #0
  adc #0
  sta delay_hi
  rts
.endproc

.proc UpdateGame
  lda summary_lock
  beq @no_lock_tick
  dec summary_lock
@no_lock_tick:

  lda game_state
  cmp #STATE_MENU
  bne @check_settings

@state_menu:
  lda pad_new
  and #(BTN_UP | BTN_DOWN)
  beq @menu_select
  lda menu_cursor
  eor #1
  sta menu_cursor
  jsr BuildMenuLines

@menu_select:
  lda pad_new
  and #BTN_A
  bne @menu_has_a
  rts
@menu_has_a:
  lda menu_cursor
  beq @menu_start
  jsr EnterSettingsState
  rts

@menu_start:
  jsr StartSeries
  rts

@check_settings:
  cmp #STATE_SETTINGS
  bne @check_wait

@state_settings:
  lda pad_new
  and #BTN_UP
  beq @check_down
  jsr CycleSettingUp
  jsr BuildSettingsLines

@check_down:
  lda pad_new
  and #BTN_DOWN
  beq @check_exit_settings
  jsr CycleSettingDown
  jsr BuildSettingsLines

@check_exit_settings:
  lda pad_new
  and #(BTN_A | BTN_B)
  bne @settings_exit
  rts
@settings_exit:
  jsr EnterMenuState
  rts

@check_wait:
  cmp #STATE_WAIT
  bne @check_go

@state_wait:
  lda pad_new
  beq @wait_countdown
  jsr EnterInvalidState
  rts

@wait_countdown:
  lda delay_lo
  ora delay_hi
  beq @wait_to_go

  sec
  lda delay_lo
  sbc #1
  sta delay_lo
  lda delay_hi
  sbc #0
  sta delay_hi

  lda delay_lo
  ora delay_hi
  bne @wait_still_counting

@wait_to_go:
  jsr EnterGoState
  rts
@wait_still_counting:
  rts

@check_go:
  cmp #STATE_GO
  bne @check_result

@state_go:
  lda go_latched
  bne @go_pressed
  rts
@go_pressed:
  jsr FinishTrial
  rts

@check_result:
  cmp #STATE_RESULT
  bne @check_invalid

@state_result:
  lda pad_new
  and #BTN_A
  beq @result_check_b
  jsr StartTrial
  rts

@result_check_b:
  lda pad_new
  and #BTN_B
  bne @result_to_menu
  rts
@result_to_menu:
  jsr EnterMenuState
  rts

@check_invalid:
  cmp #STATE_INVALID
  bne @state_summary

@state_invalid:
  lda pad_new
  and #BTN_A
  beq @invalid_check_b
  jsr StartTrial
  rts

@invalid_check_b:
  lda pad_new
  and #BTN_B
  bne @invalid_to_menu
  rts
@invalid_to_menu:
  jsr EnterMenuState
  rts

@state_summary:
  lda summary_lock
  beq @summary_input_ok
  rts
@summary_input_ok:
  lda pad_new
  and #BTN_A
  beq @summary_check_b
  jsr StartSeries
  rts

@summary_check_b:
  lda pad_new
  and #BTN_B
  bne @summary_to_menu
  rts
@summary_to_menu:
  jsr EnterMenuState
  rts
.endproc

.proc IncrementReaction
  lda reaction_hi
  cmp #MAX_FRAMES_HI
  bcc @inc
  bne @done
  lda reaction_lo
  cmp #MAX_FRAMES_LO
  bcs @done
@inc:
  inc reaction_lo
  bne @done
  inc reaction_hi
@done:
  rts
.endproc

.proc TickGoTiming
  lda game_state
  cmp #STATE_GO
  bne @done

  lda go_latched
  bne @done

  jsr IncrementReaction

  lda pad_new
  beq @done
  lda #1
  sta go_latched
@done:
  rts
.endproc

.proc StartSeries
  lda #0
  sta trial_count
  sta sum_lo
  sta sum_hi
  sta midsum_lo
  sta midsum_mid
  sta midsum_hi
  jsr StartTrial
  rts
.endproc

.proc StartTrial
  lda #STATE_WAIT
  sta game_state
  lda #COLOR_BLUE
  sta bg_color
  lda #0
  sta go_latched
  sta reaction_lo
  sta reaction_hi

  jsr GenerateDelay
  jsr BuildWaitLines
  rts
.endproc

.proc EnterGoState
  lda #STATE_GO
  sta game_state
  lda #COLOR_GREEN
  sta bg_color
  lda #0
  sta go_latched
  sta reaction_lo
  sta reaction_hi

  jsr BuildGoLines
  rts
.endproc

.proc EnterInvalidState
  lda #STATE_INVALID
  sta game_state
  lda #COLOR_ALERT
  sta bg_color

  lda #<StrInvalidTitle
  sta ptr_lo
  lda #>StrInvalidTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrInvalidLine1
  sta ptr_lo
  lda #>StrInvalidLine1
  sta ptr_hi
  jsr SetLine1FromPtr

  lda #<StrBlank
  sta ptr_lo
  lda #>StrBlank
  sta ptr_hi
  jsr SetLine2FromPtr

  lda #<StrRetryMenu
  sta ptr_lo
  lda #>StrRetryMenu
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts
.endproc

.proc EnterMenuState
  lda #STATE_MENU
  sta game_state
  lda #COLOR_BLUE
  sta bg_color
  jsr BuildMenuLines
  rts
.endproc

.proc EnterSettingsState
  lda #STATE_SETTINGS
  sta game_state
  lda #COLOR_BLUE
  sta bg_color
  jsr SettingIndexFromTarget
  jsr BuildSettingsLines
  rts
.endproc

.proc FinishTrial
  lda #0
  sta go_latched

  lda #COLOR_BLUE
  sta bg_color

  lda reaction_lo
  sta tmp16_lo
  lda reaction_hi
  sta tmp16_hi
  jsr BuildNumericBuffersFromTmp16

  jsr AddReactionToSum
  jsr AddMidpointToSum
  inc trial_count

  lda trial_count
  cmp avg_target
  bne @single_result

  jsr ComputeSessionAverages
  jsr EnterSummaryState
  rts

@single_result:
  jsr EnterResultState
  rts
.endproc

.proc AddReactionToSum
  clc
  lda sum_lo
  adc reaction_lo
  sta sum_lo
  lda sum_hi
  adc reaction_hi
  sta sum_hi
  rts
.endproc

.proc AddMidpointToSum
  lda reaction_lo
  sta tmp16_lo
  lda reaction_hi
  sta tmp16_hi

  ; Shift midpoint model by one frame earlier: base uses (n-2) frames.
  lda tmp16_lo
  ora tmp16_hi
  beq @have_base

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi

  lda tmp16_lo
  ora tmp16_hi
  beq @have_base

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi

@have_base:
  jsr MultiplyTmp16By1667

  clc
  lda ms_val_lo
  adc #$41
  sta ms_val_lo
  lda ms_val_mid
  adc #$03
  sta ms_val_mid
  lda ms_val_hi
  adc #$00
  sta ms_val_hi

  clc
  lda midsum_lo
  adc ms_val_lo
  sta midsum_lo
  lda midsum_mid
  adc ms_val_mid
  sta midsum_mid
  lda midsum_hi
  adc ms_val_hi
  sta midsum_hi
  rts
.endproc

.proc ComputeSessionAverages
  jsr ComputeAverageFramesBuffer
  jsr ComputeAverageMidpointMsBuffer
  rts
.endproc

.proc ComputeAverageFramesBuffer
  lda avg_target
  sta divisor

  lda sum_lo
  sta val_lo
  lda sum_hi
  sta val_hi

  jsr Divide16By8Val

  lda val_lo
  sta avg_lo
  lda val_hi
  sta avg_hi

  lda rem8
  sta digit_temp
  lda #0
  sta val_lo
  sta val_hi

  ldx #100
@mul100:
  clc
  lda val_lo
  adc digit_temp
  sta val_lo
  lda val_hi
  adc #0
  sta val_hi
  dex
  bne @mul100

  jsr Divide16By8Val

  lda avg_lo
  sta tmp16_lo
  lda avg_hi
  sta tmp16_hi
  jsr FormatFramesFromTmp16

  lda frame_buf + 2
  sta avg_frame_buf
  lda frame_buf + 3
  sta avg_frame_buf + 1
  lda frame_buf + 4
  sta avg_frame_buf + 2
  lda #T_DOT
  sta avg_frame_buf + 3

  lda val_lo
  jsr ByteToTwoDigitTiles
  lda digit_tens
  sta avg_frame_buf + 4
  lda digit_ones
  sta avg_frame_buf + 5

  lda avg_frame_buf
  cmp #T_0
  bne @done
  lda #T_SPACE
  sta avg_frame_buf
  lda avg_frame_buf + 1
  cmp #T_0
  bne @done
  lda #T_SPACE
  sta avg_frame_buf + 1

@done:
  rts
.endproc

.proc ComputeAverageMidpointMsBuffer
  lda avg_target
  sta divisor

  lda midsum_lo
  sta work_lo
  lda midsum_mid
  sta work_mid
  lda midsum_hi
  sta work_hi

  jsr Divide24By8Work

  jsr ConvertMsValueToDigits
  lda #<avg_ms_buf
  sta dst_lo
  lda #>avg_ms_buf
  sta dst_hi
  jsr DigitsToMsBuffer
  rts
.endproc

.proc CycleSettingUp
  lda setting_idx
  beq @wrap
  dec setting_idx
  jmp @apply
@wrap:
  lda #2
  sta setting_idx
@apply:
  jsr ApplySettingIndex
  rts
.endproc

.proc CycleSettingDown
  lda setting_idx
  cmp #2
  beq @wrap
  inc setting_idx
  jmp @apply
@wrap:
  lda #0
  sta setting_idx
@apply:
  jsr ApplySettingIndex
  rts
.endproc

.proc ApplySettingIndex
  lda setting_idx
  beq @set3
  cmp #1
  beq @set5
  lda #12
  sta avg_target
  rts
@set3:
  lda #3
  sta avg_target
  rts
@set5:
  lda #5
  sta avg_target
  rts
.endproc

.proc SettingIndexFromTarget
  lda avg_target
  cmp #3
  beq @idx0
  cmp #5
  beq @idx1
  lda #2
  sta setting_idx
  rts
@idx0:
  lda #0
  sta setting_idx
  rts
@idx1:
  lda #1
  sta setting_idx
  rts
.endproc

.proc BuildMenuLines
  lda #<StrMenuTitle
  sta ptr_lo
  lda #>StrMenuTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrMenuSubTitle
  sta ptr_lo
  lda #>StrMenuSubTitle
  sta ptr_hi
  jsr SetLine1FromPtr

  lda menu_cursor
  beq @start_selected
  lda #<StrMenuStart
  sta ptr_lo
  lda #>StrMenuStart
  sta ptr_hi
  jsr SetLine2FromPtr
  jmp @line3

@start_selected:
  lda #<StrMenuStartSel
  sta ptr_lo
  lda #>StrMenuStartSel
  sta ptr_hi
  jsr SetLine2FromPtr

@line3:
  lda menu_cursor
  bne @settings_selected
  lda #<StrMenuSettings
  sta ptr_lo
  lda #>StrMenuSettings
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts

@settings_selected:
  lda #<StrMenuSettingsSel
  sta ptr_lo
  lda #>StrMenuSettingsSel
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts
.endproc

.proc BuildSettingsLines
  lda #<StrSettingsTitle
  sta ptr_lo
  lda #>StrSettingsTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrSettingsOpts
  sta ptr_lo
  lda #>StrSettingsOpts
  sta ptr_hi
  jsr SetLine1FromPtr

  lda #<StrSettingsCurrent
  sta ptr_lo
  lda #>StrSettingsCurrent
  sta ptr_hi
  jsr SetLine2FromPtr

  lda #<line2
  sta dst_lo
  lda #>line2
  sta dst_hi
  lda avg_target
  jsr ByteToTwoDigitTiles
  ldy #13
  lda digit_tens
  sta (dst_lo), y
  iny
  lda digit_ones
  sta (dst_lo), y

  lda #<StrSettingsHint
  sta ptr_lo
  lda #>StrSettingsHint
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts
.endproc

.proc BuildWaitLines
  lda #<StrWaitTitle
  sta ptr_lo
  lda #>StrWaitTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrWaitLine1
  sta ptr_lo
  lda #>StrWaitLine1
  sta ptr_hi
  jsr SetLine1FromPtr

  lda #<StrWaitLine2
  sta ptr_lo
  lda #>StrWaitLine2
  sta ptr_hi
  jsr SetLine2FromPtr

  jsr BuildTryLine
  jsr QueueFullRender
  rts
.endproc

.proc BuildGoLines
  lda #<StrGoTitle
  sta ptr_lo
  lda #>StrGoTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrGoLine1
  sta ptr_lo
  lda #>StrGoLine1
  sta ptr_hi
  jsr SetLine1FromPtr

  lda #<StrBlank
  sta ptr_lo
  lda #>StrBlank
  sta ptr_hi
  jsr SetLine2FromPtr

  jsr BuildTryLine
  jsr QueueFullRender
  rts
.endproc

.proc QueueFullRender
  lda #0
  sta render_phase
  lda #1
  sta render_pending
  rts
.endproc

.proc BuildTryLine
  lda #<StrTryTemplate
  sta ptr_lo
  lda #>StrTryTemplate
  sta ptr_hi
  jsr SetLine3FromPtr

  lda trial_count
  clc
  adc #1
  jsr ByteToTwoDigitTiles

  lda #<line3
  sta dst_lo
  lda #>line3
  sta dst_hi

  ldy #10
  lda digit_tens
  sta (dst_lo), y
  iny
  lda digit_ones
  sta (dst_lo), y

  lda avg_target
  jsr ByteToTwoDigitTiles

  ldy #13
  lda digit_tens
  sta (dst_lo), y
  iny
  lda digit_ones
  sta (dst_lo), y
  rts
.endproc

.proc EnterResultState
  lda #STATE_RESULT
  sta game_state
  lda #COLOR_BLUE
  sta bg_color

  lda reaction_lo
  sta tmp16_lo
  lda reaction_hi
  sta tmp16_hi
  jsr BuildNumericBuffersFromTmp16

  lda #<StrResultTitle
  sta ptr_lo
  lda #>StrResultTitle
  sta ptr_hi
  jsr SetLine0FromPtr

  lda #<StrLineFrames
  sta ptr_lo
  lda #>StrLineFrames
  sta ptr_hi
  jsr SetLine1FromPtr
  jsr PlaceFrameInLine1

  lda #<StrLineMs
  sta ptr_lo
  lda #>StrLineMs
  sta ptr_hi
  jsr SetLine2FromPtr
  jsr PlaceMsInLine2

  lda #<StrAgainMenu
  sta ptr_lo
  lda #>StrAgainMenu
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts
.endproc

.proc EnterSummaryState
  lda #STATE_SUMMARY
  sta game_state
  lda #COLOR_BLUE
  sta bg_color
  lda #8
  sta summary_lock

  lda #<StrSummaryLastFrames
  sta ptr_lo
  lda #>StrSummaryLastFrames
  sta ptr_hi
  jsr SetLine0FromPtr
  jsr PlaceFrameInLine0

  lda #<StrLineMs
  sta ptr_lo
  lda #>StrLineMs
  sta ptr_hi
  jsr SetLine1FromPtr
  jsr PlaceMsInLine1

  lda #<StrSummaryAvg
  sta ptr_lo
  lda #>StrSummaryAvg
  sta ptr_hi
  jsr SetLine2FromPtr
  jsr PlaceAvgInLine2

  lda #<StrAgainMenu
  sta ptr_lo
  lda #>StrAgainMenu
  sta ptr_hi
  jsr SetLine3FromPtr
  jsr QueueFullRender
  rts
.endproc

.proc BuildNumericBuffersFromTmp16
  lda tmp16_lo
  sta val_lo
  lda tmp16_hi
  sta val_hi

  jsr FormatFramesFromTmp16

  ; Lower bound uses (n-2) frames, clamped at 0.
  lda val_lo
  sta tmp16_lo
  lda val_hi
  sta tmp16_hi

  lda tmp16_lo
  ora tmp16_hi
  beq @lower_ready

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi

  lda tmp16_lo
  ora tmp16_hi
  beq @lower_ready

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi
@lower_ready:
  jsr MultiplyTmp16By1667
  jsr ConvertMsValueToDigits
  lda #<lower_ms_buf
  sta dst_lo
  lda #>lower_ms_buf
  sta dst_hi
  jsr DigitsToMsBuffer

  ; Upper bound uses (n-1) frames, clamped at 0.
  lda val_lo
  sta tmp16_lo
  lda val_hi
  sta tmp16_hi

  lda tmp16_lo
  ora tmp16_hi
  beq @upper_ready

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi

@upper_ready:
  jsr MultiplyTmp16By1667
  jsr ConvertMsValueToDigits
  lda #<upper_ms_buf
  sta dst_lo
  lda #>upper_ms_buf
  sta dst_hi
  jsr DigitsToMsBuffer
  rts
.endproc

.proc FormatFramesFromTmp16
  ldx #0
@digit_loop:
  lda #0
  sta digit_temp
@subtract:
  jsr FrameValueGeConst
  bcc @store_digit
  jsr FrameValueSubConst
  inc digit_temp
  bne @subtract
@store_digit:
  lda digit_temp
  clc
  adc #T_0
  sta frame_buf, x
  inx
  cpx #FRAME_LEN
  bne @digit_loop
  rts
.endproc

.proc FrameValueGeConst
  lda tmp16_hi
  cmp FrameConstHi, x
  bcc @less
  bne @ge
  lda tmp16_lo
  cmp FrameConstLo, x
  bcc @less
@ge:
  sec
  rts
@less:
  clc
  rts
.endproc

.proc FrameValueSubConst
  sec
  lda tmp16_lo
  sbc FrameConstLo, x
  sta tmp16_lo
  lda tmp16_hi
  sbc FrameConstHi, x
  sta tmp16_hi
  rts
.endproc

.proc MultiplyTmp16By1667
  lda #0
  sta ms_val_lo
  sta ms_val_mid
  sta ms_val_hi

@loop:
  lda tmp16_lo
  ora tmp16_hi
  beq @done

  clc
  lda ms_val_lo
  adc #$83
  sta ms_val_lo
  lda ms_val_mid
  adc #$06
  sta ms_val_mid
  lda ms_val_hi
  adc #$00
  sta ms_val_hi

  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi
  jmp @loop
@done:
  rts
.endproc

.proc ConvertMsValueToDigits
  ldx #0
@next_digit:
  lda #0
  sta digit_temp
@subtract:
  jsr MsValueGeConst
  bcc @store
  jsr MsValueSubConst
  inc digit_temp
  bne @subtract
@store:
  lda digit_temp
  sta digits8, x
  inx
  cpx #8
  bne @next_digit
  rts
.endproc

.proc MsValueGeConst
  lda ms_val_hi
  cmp MsConstHi, x
  bcc @less
  bne @ge
  lda ms_val_mid
  cmp MsConstMid, x
  bcc @less
  bne @ge
  lda ms_val_lo
  cmp MsConstLo, x
  bcc @less
@ge:
  sec
  rts
@less:
  clc
  rts
.endproc

.proc MsValueSubConst
  sec
  lda ms_val_lo
  sbc MsConstLo, x
  sta ms_val_lo
  lda ms_val_mid
  sbc MsConstMid, x
  sta ms_val_mid
  lda ms_val_hi
  sbc MsConstHi, x
  sta ms_val_hi
  rts
.endproc

.proc DigitsToMsBuffer
  ldy #0
@int_part:
  lda digits8 + 1, y
  clc
  adc #T_0
  sta (dst_lo), y
  iny
  cpy #5
  bne @int_part

  lda #T_DOT
  sta (dst_lo), y
  iny

  lda digits8 + 6
  clc
  adc #T_0
  sta (dst_lo), y
  iny

  lda digits8 + 7
  clc
  adc #T_0
  sta (dst_lo), y
  rts
.endproc

.proc ByteToTwoDigitTiles
  ldx #0
@sub10:
  cmp #10
  bcc @done
  sec
  sbc #10
  inx
  bne @sub10
@done:
  tay
  txa
  clc
  adc #T_0
  sta digit_tens
  tya
  clc
  adc #T_0
  sta digit_ones
  rts
.endproc

.proc Divide16By8Val
  lda #0
  sta rem8
  sta tmp16_lo
  sta tmp16_hi
  lda #16
  sta loop_ctr

@loop:
  asl val_lo
  rol val_hi
  rol rem8

  asl tmp16_lo
  rol tmp16_hi

  lda rem8
  cmp divisor
  bcc @next
  sec
  sbc divisor
  sta rem8
  lda tmp16_lo
  ora #$01
  sta tmp16_lo

@next:
  dec loop_ctr
  bne @loop

  lda tmp16_lo
  sta val_lo
  lda tmp16_hi
  sta val_hi
  rts
.endproc

.proc Divide24By8Work
  lda #0
  sta rem8
  sta ms_val_lo
  sta ms_val_mid
  sta ms_val_hi
  lda #24
  sta loop_ctr

@loop:
  asl work_lo
  rol work_mid
  rol work_hi
  rol rem8

  asl ms_val_lo
  rol ms_val_mid
  rol ms_val_hi

  lda rem8
  cmp divisor
  bcc @next
  sec
  sbc divisor
  sta rem8
  lda ms_val_lo
  ora #$01
  sta ms_val_lo

@next:
  dec loop_ctr
  bne @loop
  rts
.endproc

.proc PlaceFrameInLine1
  ldx #0
@loop:
  lda frame_buf, x
  sta line1 + 10, x
  inx
  cpx #FRAME_LEN
  bne @loop
  rts
.endproc

.proc PlaceMsInLine2
  ldx #0
@lower:
  lda lower_ms_buf, x
  sta line2 + 4, x
  inx
  cpx #MS_LEN
  bne @lower

  ldx #0
@upper:
  lda upper_ms_buf, x
  sta line2 + 13, x
  inx
  cpx #MS_LEN
  bne @upper
  rts
.endproc

.proc PlaceFrameInLine0
  ldx #0
@loop:
  lda frame_buf, x
  sta line0 + 11, x
  inx
  cpx #FRAME_LEN
  bne @loop
  rts
.endproc

.proc PlaceMsInLine1
  ldx #0
@lower:
  lda lower_ms_buf, x
  sta line1 + 4, x
  inx
  cpx #MS_LEN
  bne @lower

  ldx #0
@upper:
  lda upper_ms_buf, x
  sta line1 + 13, x
  inx
  cpx #MS_LEN
  bne @upper
  rts
.endproc

.proc PlaceAvgInLine2
  ldx #0
@avgf:
  lda avg_frame_buf, x
  sta line2 + 4, x
  inx
  cpx #AVG_FRAME_LEN
  bne @avgf

  ldx #0
@avgms:
  lda avg_ms_buf, x
  sta line2 + 12, x
  inx
  cpx #MS_LEN
  bne @avgms
  rts
.endproc

.proc CopyAsciiToLine
  ldy #0
  lda #T_SPACE
@fill:
  sta (dst_lo), y
  iny
  cpy #LINE_LEN
  bne @fill

  ldy #0
@copy:
  cpy #LINE_LEN
  beq @done
  lda (ptr_lo), y
  beq @done
  jsr AsciiToTile
  sta (dst_lo), y
  iny
  bne @copy
@done:
  rts
.endproc

.proc SetLine0FromPtr
  lda #<line0
  sta dst_lo
  lda #>line0
  sta dst_hi
  jsr CopyAsciiToLine
  rts
.endproc

.proc SetLine1FromPtr
  lda #<line1
  sta dst_lo
  lda #>line1
  sta dst_hi
  jsr CopyAsciiToLine
  rts
.endproc

.proc SetLine2FromPtr
  lda #<line2
  sta dst_lo
  lda #>line2
  sta dst_hi
  jsr CopyAsciiToLine
  rts
.endproc

.proc SetLine3FromPtr
  lda #<line3
  sta dst_lo
  lda #>line3
  sta dst_hi
  jsr CopyAsciiToLine
  rts
.endproc

.proc AsciiToTile
  cmp #' '
  beq @space
  cmp #':'
  beq @colon
  cmp #'.'
  beq @dot
  cmp #'!'
  beq @bang
  cmp #'-'
  beq @dash
  cmp #'/'
  beq @slash
  cmp #'>'
  beq @gt

  cmp #'0'
  bcc @letters
  cmp #'9' + 1
  bcs @letters
  sec
  sbc #'0'
  clc
  adc #T_0
  rts

@letters:
  cmp #'A'
  bcc @space
  cmp #'Z' + 1
  bcs @space
  sec
  sbc #'A'
  tax
  lda LetterTileMap, x
  rts

@space:
  lda #T_SPACE
  rts
@colon:
  lda #T_COLON
  rts
@dot:
  lda #T_DOT
  rts
@bang:
  lda #T_BANG
  rts
@dash:
  lda #T_DASH
  rts
@slash:
  lda #T_SLASH
  rts
@gt:
  lda #T_GT
  rts
.endproc

.proc RenderFrame
  lda PPUSTATUS
  lda #$3F
  sta PPUADDR
  lda #$00
  sta PPUADDR
  lda bg_color
  sta PPUDATA
  lda #$30
  sta PPUDATA
  lda #$0F
  sta PPUDATA
  sta PPUDATA

  lda #LINE_LEN
  sta nmi_len

  lda render_pending
  beq @select_pair
  lda #0
  sta render_pending
  sta render_phase

@select_pair:
  lda render_phase
  beq @top_pair

@bottom_pair:
  lda #<line2
  sta nmi_ptr_lo
  lda #>line2
  sta nmi_ptr_hi
  lda #L2_ADDR_LO
  sta nmi_addr_lo
  lda #L2_ADDR_HI
  sta nmi_addr_hi
  jsr NmiWriteBufferAt

  lda #<line3
  sta nmi_ptr_lo
  lda #>line3
  sta nmi_ptr_hi
  lda #L3_ADDR_LO
  sta nmi_addr_lo
  lda #L3_ADDR_HI
  sta nmi_addr_hi
  jsr NmiWriteBufferAt

  lda #0
  sta render_phase
  jmp @done

@top_pair:
  lda #<line0
  sta nmi_ptr_lo
  lda #>line0
  sta nmi_ptr_hi
  lda #L0_ADDR_LO
  sta nmi_addr_lo
  lda #L0_ADDR_HI
  sta nmi_addr_hi
  jsr NmiWriteBufferAt

  lda #<line1
  sta nmi_ptr_lo
  lda #>line1
  sta nmi_ptr_hi
  lda #L1_ADDR_LO
  sta nmi_addr_lo
  lda #L1_ADDR_HI
  sta nmi_addr_hi
  jsr NmiWriteBufferAt

  lda #1
  sta render_phase
  jmp @done

@done:

  lda #0
  sta PPUSCROLL
  sta PPUSCROLL
  rts
.endproc

.proc NmiWriteBufferAt
  lda PPUSTATUS
  lda nmi_addr_hi
  sta PPUADDR
  lda nmi_addr_lo
  sta PPUADDR
  ldy #0
@loop:
  cpy nmi_len
  beq @done
  lda (nmi_ptr_lo), y
  sta PPUDATA
  iny
  bne @loop
@done:
  rts
.endproc

.proc LoadChrTiles
  lda PPUSTATUS
  lda #$00
  sta PPUADDR
  sta PPUADDR

  lda #<TileData
  sta ptr_lo
  lda #>TileData
  sta ptr_hi
  lda #<(TileDataEnd - TileData)
  sta tmp16_lo
  lda #>(TileDataEnd - TileData)
  sta tmp16_hi

  ldy #0
@copy:
  lda tmp16_lo
  ora tmp16_hi
  beq @done

  lda (ptr_lo), y
  sta PPUDATA
  iny
  bne @no_page
  inc ptr_hi
@no_page:
  sec
  lda tmp16_lo
  sbc #1
  sta tmp16_lo
  lda tmp16_hi
  sbc #0
  sta tmp16_hi
  jmp @copy
@done:
  rts
.endproc

.proc ClearNametable
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  lda #0
  ldx #4
@page:
  ldy #0
@fill:
  sta PPUDATA
  iny
  bne @fill
  dex
  bne @page
  rts
.endproc

PadMask:
  .byte $01, $02, $04, $08, $10, $20, $40, $80

BlankLineData:
  .res LINE_LEN, T_SPACE

FrameConstHi:
  .byte $27, $03, $00, $00, $00
FrameConstLo:
  .byte $10, $E8, $64, $0A, $01

MsConstHi:
  .byte $98, $0F, $01, $00, $00, $00, $00, $00
MsConstMid:
  .byte $96, $42, $86, $27, $03, $00, $00, $00
MsConstLo:
  .byte $80, $40, $A0, $10, $E8, $64, $0A, $01

LetterTileMap:
  ; A-Z tile lookup. Unsupported letters map to space.
  .byte T_A, T_B, T_C, T_D, T_E, T_F, T_G, T_SPACE, T_I, T_SPACE, T_SPACE, T_L, T_M
  .byte T_N, T_O, T_P, T_SPACE, T_R, T_S, T_T, T_U, T_V, T_W, T_SPACE, T_Y, T_SPACE

StrBlank:
  .byte 0

StrMenuTitle:
  .byte "   REACTION TIME", 0
StrMenuSubTitle:
  .byte "        TEST", 0
StrMenuStartSel:
  .byte " > START TESTS", 0
StrMenuStart:
  .byte "   START TESTS", 0
StrMenuSettingsSel:
  .byte " > SETTINGS", 0
StrMenuSettings:
  .byte "   SETTINGS", 0

StrSettingsTitle:
  .byte "       SETTINGS", 0
StrSettingsOpts:
  .byte "    AVG OF 3/5/12", 0
StrSettingsCurrent:
  .byte "      AVG AO:00", 0
StrSettingsHint:
  .byte "   A SELECT  B MENU", 0

StrWaitTitle:
  .byte "      GET READY", 0
StrWaitLine1:
  .byte "    WAIT FOR GREEN", 0
StrWaitLine2:
  .byte "   DO NOT PRESS BTN", 0

StrGoTitle:
  .byte "        GO!", 0
StrGoLine1:
  .byte "   PRESS ANY BTN", 0

StrTryTemplate:
  .byte "      TRY 00/00", 0

StrResultTitle:
  .byte "     TRIAL RESULT", 0
StrSummaryLastFrames:
  .byte "    LAST F:00000", 0
StrSummaryAvg:
  .byte "AVG 000.00F 00000.00MS", 0
StrLineFrames:
  .byte "   FRAMES:00000", 0
StrLineMs:
  .byte " MS:00000.00-00000.00", 0
StrAgainMenu:
  .byte "   A AGAIN  B MENU", 0

StrInvalidTitle:
  .byte "      TOO SOON!", 0
StrInvalidLine1:
  .byte "    PRESS ON GREEN", 0
StrRetryMenu:
  .byte "   A RETRY  B MENU", 0

TileData:
; tile 0: space
  .byte %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
  .byte %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
; tile 1: 0
  .byte %00111100,%01100110,%01101110,%01110110,%01100110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 2: 1
  .byte %00011000,%00111000,%00011000,%00011000,%00011000,%00011000,%01111110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 3: 2
  .byte %00111100,%01100110,%00000110,%00001100,%00110000,%01100000,%01111110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 4: 3
  .byte %00111100,%01100110,%00000110,%00011100,%00000110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 5: 4
  .byte %00001100,%00011100,%00101100,%01001100,%01111110,%00001100,%00001100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 6: 5
  .byte %01111110,%01100000,%01111100,%00000110,%00000110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 7: 6
  .byte %00111100,%01100000,%01111100,%01100110,%01100110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 8: 7
  .byte %01111110,%00000110,%00001100,%00011000,%00110000,%00110000,%00110000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 9: 8
  .byte %00111100,%01100110,%01100110,%00111100,%01100110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 10: 9
  .byte %00111100,%01100110,%01100110,%00111110,%00000110,%00001100,%00111000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 11: A
  .byte %00111100,%01100110,%01100110,%01111110,%01100110,%01100110,%01100110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 12: E
  .byte %01111110,%01100000,%01100000,%01111100,%01100000,%01100000,%01111110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 13: F
  .byte %01111110,%01100000,%01100000,%01111100,%01100000,%01100000,%01100000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 14: G
  .byte %00111100,%01100110,%01100000,%01101110,%01100110,%01100110,%00111110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 15: I
  .byte %00111100,%00011000,%00011000,%00011000,%00011000,%00011000,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 16: L
  .byte %01100000,%01100000,%01100000,%01100000,%01100000,%01100000,%01111110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 17: M
  .byte %01100011,%01110111,%01111111,%01101011,%01100011,%01100011,%01100011,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 18: O
  .byte %00111100,%01100110,%01100110,%01100110,%01100110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 19: P
  .byte %01111100,%01100110,%01100110,%01111100,%01100000,%01100000,%01100000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 20: R
  .byte %01111100,%01100110,%01100110,%01111100,%01101100,%01100110,%01100110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 21: S
  .byte %00111110,%01100000,%01100000,%00111100,%00000110,%00000110,%01111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 22: T
  .byte %01111110,%00011000,%00011000,%00011000,%00011000,%00011000,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 23: W
  .byte %01100011,%01100011,%01100011,%01101011,%01111111,%01110111,%01100011,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 24: Y
  .byte %01100110,%01100110,%00111100,%00011000,%00011000,%00011000,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 25: :
  .byte %00000000,%00011000,%00011000,%00000000,%00000000,%00011000,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 26: .
  .byte %00000000,%00000000,%00000000,%00000000,%00000000,%00011000,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 27: !
  .byte %00011000,%00011000,%00011000,%00011000,%00011000,%00000000,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 28: B
  .byte %01111100,%01100110,%01100110,%01111100,%01100110,%01100110,%01111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 29: D
  .byte %01111000,%01101100,%01100110,%01100110,%01100110,%01101100,%01111000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 30: N
  .byte %01100110,%01110110,%01111110,%01111110,%01101110,%01100110,%01100110,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 31: U
  .byte %01100110,%01100110,%01100110,%01100110,%01100110,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 32: V
  .byte %01100110,%01100110,%01100110,%01100110,%01100110,%00111100,%00011000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 33: -
  .byte %00000000,%00000000,%00000000,%01111110,%01111110,%00000000,%00000000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 34: /
  .byte %00000110,%00001100,%00011000,%00110000,%01100000,%11000000,%10000000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 35: >
  .byte %01000000,%01100000,%00110000,%00011000,%00110000,%01100000,%01000000,%00000000
  .byte 0,0,0,0,0,0,0,0
; tile 36: C
  .byte %00111100,%01100110,%01100000,%01100000,%01100000,%01100110,%00111100,%00000000
  .byte 0,0,0,0,0,0,0,0
TileDataEnd:

.segment "VECTORS"
  .word NMI
  .word Reset
  .word IRQ
