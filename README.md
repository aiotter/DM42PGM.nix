# Build DM42/DM42n firmware with Nix

This repository provides a Nix build chain for the DM42/DM42n program using the official SwissMicros [Free42](https://github.com/swissmicros/free42) and [DM42PGM](https://github.com/swissmicros/DM42PGM) sources.
The same build chain can also use custom Free42 and DM42PGM forks by overriding their inputs.

## Features

- Nix builds for DM42 and DM42n with replaceable core and frontend sources.
- Hash checks against the official firmware binaries.
- Host tests for custom source trees during firmware builds.
- USB flashing of built firmware or existing program files, with optional fast mode.

## Build from the official sources

With Nix and flakes enabled, run:

```sh
nix build github:aiotter/DM42PGM.nix
```

This produces `.pgm` for DM42 and `.pg5` for DM42n in `result/`.
For DM42-3.26, both files were verified to be byte-for-byte identical to the official binaries.

To verify that both firmware files match the official binaries, run:

```sh
nix flake check github:aiotter/DM42PGM.nix
```

## Build custom firmware

Build DM42n firmware using the [extended Free42 core](https://github.com/aiotter/dm42-free42) and [extended DM42PGM frontend](https://github.com/aiotter/DM42PGM):

```sh
nix build github:aiotter/DM42PGM.nix#dm42n \
  --override-input free42 github:aiotter/dm42-free42 \
  --override-input dm42pgm github:aiotter/DM42PGM
```

This overrides both source inputs for that build without changing `flake.lock`.

Even when sources are overridden with `--override-input`, `nix flake check` builds from the pinned official sources and verifies the firmware hashes.

## Tests in custom source trees

If a Free42 or DM42PGM source tree contains `tests/Makefile`, the firmware build automatically runs it.
Its default target should build and run the tests on the build machine, returning a nonzero status if any test fails.
A test failure fails the firmware build.
Source trees without `tests/Makefile` skip testing.

## Install on a DM42/DM42n

### Load Program from the USB disk

1. Mount your calculator (`SETUP` -> `System` -> `Reset to DMCP menu` -> `Activate USB Disk`).
2. Copy `result/DM42-***.pgm` (DM42) or `result/DM42-***.pg5` (DM42n) to the calculator's USB disk.
3. Unmount the USB disk.
4. Choose `Load Program` on the calculator and select the copied file.

### Direct USB flashing

The custom flasher in `flasher/` is designed for fast build–test cycles.
It rewrites only the calculator's application area, completing a flash in about 40 seconds on the tested DM42n.

Connect one calculator by USB and select `SETUP` -> `System` -> `Bootloader`.
To flash the official firmware:

```sh
nix run github:aiotter/DM42PGM.nix#dm42
# or, for DM42n:
nix run github:aiotter/DM42PGM.nix#dm42n
```

To flash custom firmware using the [extended Free42 core](https://github.com/aiotter/dm42-free42) and [extended DM42PGM frontend](https://github.com/aiotter/DM42PGM):

```sh
nix run github:aiotter/DM42PGM.nix#dm42n \
  --override-input free42 github:aiotter/dm42-free42 \
  --override-input dm42pgm github:aiotter/DM42PGM
```

To flash an existing program file without rebuilding it:

```sh
nix run github:aiotter/DM42PGM.nix#flasher -- path/to/program.pg5
```

Set `FAST=1` to enable fast mode, which took about 20 seconds on the tested DM42n:

```sh
FAST=1 nix run github:aiotter/DM42PGM.nix#flasher -- path/to/program.pg5
```

Fast mode skips the device-requested polling delays, which can cause USB errors and interrupt flashing.
If this happens, retry without `FAST`.

Unlike dfu-util, the flasher follows Load Program's write sequence, marking the program valid only after all data has been written.
This lets the calculator detect an incomplete update if writing is interrupted.

These commands replace only the program; compatible DMCP and QSPI contents must already be installed.
