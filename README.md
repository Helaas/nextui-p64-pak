# nextui-p64-pak

NextUI emulator pak bundling **parallel-n64** (mupen64plus-libretro) as a libretro core.

Parallel-n64 is an optimized/rewritten Nintendo 64 emulator made specifically for libretro, originally based on Mupen64 Plus. Supports aarch64 dynamic recompilation for best performance on ARM devices.

## Supported Platforms

| Platform | Device | Toolchain |
|----------|--------|-----------|
| tg5040 | Trimui Smart Pro | `ghcr.io/loveretro/tg5040-toolchain:latest` |
| tg5050 | Trimui Smart Pro S | `ghcr.io/loveretro/tg5050-toolchain:latest` |
| my355 | Anbernic MY355 | `ghcr.io/loveretro/my355-toolchain:latest` |

## Building

Requires Docker.

```sh
# Build for all platforms and create .pakz
make package

# Build for a single platform
make tg5040

# Clean build artifacts (preserves cached source)
make clean

# Clean everything including cached source
make distclean
```

## Installation

Extract `P64.pakz` to the root of your SD card. It will create the correct directory structure:

```
Emus/
├── tg5040/P64.pak/
├── tg5050/P64.pak/
└── my355/P64.pak/
```

Place ROMs in a folder tagged `(P64)`:
```
Roms/Nintendo 64 (P64)/Super Mario 64.z64
```

## Core Version

parallel-n64 is pinned to commit [`1da824e`](https://github.com/libretro/parallel-n64/commit/1da824e13e725a7144f3245324f43d59623974f8) (December 4, 2025) for reproducible builds.

## License

MIT
