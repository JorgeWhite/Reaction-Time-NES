# NES Reaction Test

A frame-based reaction-time game for the Nintendo Entertainment System (NES), written in 6502 assembly with the cc65 toolchain.

This project is designed to feel similar to human benchmark reaction tests, but adapted to NES timing and input behavior.

## What It Is

The ROM runs repeated reaction trials:

1. Screen is blue while waiting a random amount of time.
2. Screen turns green (`GO!`).
3. You press a button as fast as possible.
4. The game shows your result in both frames and a millisecond range.

It also supports session averages (AO3, AO5, AO12), settings, early-press invalid handling, and retry/menu flow.

## Features

- Main menu with Start and Settings.
- Settings menu for session length: average of 3, 5, or 12 trials.
- Random pre-green delay between 120 and 300 frames (about 2 to 5 seconds at 60 Hz).
- Invalid-state detection if any button is pressed before green.
- Per-trial result screen with:
  - frame count
  - ms interval estimate
- Summary screen after the selected number of trials with:
  - last trial result
  - session average in frames and ms

## Controls

- Menu:
  - Up/Down: move cursor
  - A: confirm selection
- Settings:
  - Up/Down: cycle AO3/AO5/AO12
  - A or B: return to menu
- Wait (blue):
  - Any button: invalid (too soon)
- Go (green):
  - Any button: capture reaction
- Result/Invalid/Summary:
  - A: continue/retry/start next series
  - B: return to menu

## Timing Model

The game increments a reaction frame counter once per NMI during the GO state.

To represent quantized frame timing as milliseconds, each trial is shown as an interval using a shifted bucket model:

$$
\text{lower_ms} = \max(0, n - 2) \times 16.67
$$

$$
\text{upper_ms} = \max(0, n - 1) \times 16.67
$$

where $n$ is the captured reaction frame count.

Session-average ms is computed from the average of per-trial midpoints.

## How It Works Internally

- `Reset` initializes hardware and state, uploads CHR tile data, clears nametable, then enters the menu.
- `NMI` handles frame-synchronous work:
  - controller polling
  - GO-state timing tick/latch
  - buffered text rendering
- Main loop waits for each frame (`WaitFrame`), advances PRNG seed, and runs state logic (`UpdateGame`).

State flow:

- `STATE_MENU`
- `STATE_SETTINGS`
- `STATE_WAIT`
- `STATE_GO`
- `STATE_RESULT`
- `STATE_INVALID`
- `STATE_SUMMARY`

Rendering notes:

- Text is maintained in four line buffers.
- NMI writes line pairs (top or bottom) each frame to reduce vblank bandwidth spikes.
- Background palette color signals game phase (blue, green, alert).

## Project Structure

- `main.asm` - game logic, timing, rendering, state machine, text tiles
- `linker.cfg` - memory and segment layout
- `build.bat` - assemble and link steps

Generated build artifacts (ignored by git):

- `main.o`
- `reaction.nes`

## Requirements

- Windows (batch build script)
- cc65 toolchain
- NES emulator (for example: Mesen, FCEUX)

Expected folder layout:

```text
NES/
  cc65/
    bin/
      ca65.exe
      ld65.exe
  nes-reaction-test/
    build.bat
    linker.cfg
    main.asm
```

`build.bat` expects cc65 in `..\cc65\bin` relative to this project folder.

## Build

From the project directory:

```bat
build.bat
```

On success, this produces:

- `main.o`
- `reaction.nes`

## Run

1. Build the ROM.
2. Open `reaction.nes` in your NES emulator.
3. Start tests from the menu.
4. Use Settings to change AO length as needed.

## Troubleshooting

- `Could not find ca65...`
  - Ensure `cc65` is placed as a sibling folder next to this project.
- ROM boots but behavior is wrong in old builds:
  - Rebuild from latest source. Current header/config uses 32KB PRG (`.byte 2` in iNES header).
- Visual issues in emulator:
  - Try a different emulator or reset core settings to default NTSC behavior.

## Notes

- Timing assumes NTSC-like 60 Hz frame cadence.
- Measurements are frame-quantized and presented as an interval, not a single exact millisecond value.