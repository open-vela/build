# build Overview

\[ English | [简体中文](README_zh-cn.md) \]

`build` is the build-system support repository for openvela. It provides an Android-style command-line build environment, custom CMake modules, configuration check tools, and Android platform integration configs. The `build.sh` entry point at the openvela project root relies on this repository.

## Directory Structure

| Directory / File | Description |
| ---- | ---- |
| `envsetup.sh` | Build environment initialization script. After `source`-ing it, a set of build and navigation commands such as `lunch`, `m`/`mm`/`mmm`, `croot`, and `godir` are injected into the current shell. |
| `cmake/` | Custom CMake modules. `nuttx_custom_module.cmake` extends the NuttX build with Vela-specific build configuration (e.g., OPTEE TA). |
| `config_check/` | Configuration check tools. `config_checker.py` / `config_check_tool.py` validate Kconfig consistency across subsystems (kernel, graphics/lvgl, media, bluetooth, quickapp, etc.) based on `config_check_conf.yml`. |
| `android/` | Build configs for openvela–Android integration (`vela.mk`, `goldfish64_*.mk`, `gsi64_*.mk` product makefiles, `ueventd.vela.rc`, etc.). |

## Build Environment (envsetup.sh)

After running `source build/envsetup.sh` at the project root, the following commands become available:

| Command | Description |
| ---- | ---- |
| `lunch [vendor]-[board]-[config]` | Select and lock the build target for subsequent commands like `m`; without arguments it opens an interactive menu. |
| `m` | Build the selected target from the top of the tree. |
| `mm` | Build and install all library targets. |
| `mmm` | Build the library targets in the current directory. |
| `croot` | Change directory to the top of the tree (or a subdirectory). |
| `godir <regex>` | Jump to the directory containing the matching file. |
| `cgrep` / `kgrep` / `mgrep` | Grep across C/C++ sources, Kconfig files, and Makefile/CMake files respectively. |
| `pvcc [CONFIG] [VALUE]` | Preview the impact of a Kconfig change (PreView Config Change). |
| `hmm` | Show help for the commands above. |

Optional environment variables:

| Variable | Default | Description |
| ---- | ---- | ---- |
| `VELA_CMAKE_GENERATOR` | `-GNinja` | CMake generator. |
| `VELA_EXTRA_FLAGS` | `-Wno-cpp` | Extra compile flags. |
| `NUTTX_DIR_NAME` | `nuttx` | NuttX directory name (customizable). |
| `BEAR_MODE` | `0` | Enable [bear](https://github.com/rizsotto/Bear) to generate `compile_commands.json`. |

> The default build uses CMake + Ninja, and automatically enables `ccache` when detected to speed up compilation.

## Usage

openvela is compiled through the `build.sh` entry point at the project root, for example:

```bash
./build.sh vendor/openvela/boards/vela/configs/goldfish-arm64-v8a-ap/ --cmake -j8
```

Alternatively, `source build/envsetup.sh` and use the `lunch` + `m` combination. For the complete environment setup and build steps, see [Quick Start (Ubuntu)](../../../../open-vela/docs/blob/dev-ai-contest-2026/en/quickstart/openvela_ubuntu_quick_start.md).

## License

This repository is licensed under Apache 2.0. See [LICENSE](./LICENSE) for details.
