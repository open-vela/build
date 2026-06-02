# build 简介

\[ [English](README.md) | 简体中文 \]

`build` 是 openvela 的构建系统支撑仓库，提供一套类 Android 风格的命令行构建环境、CMake 自定义模块、配置检查工具以及 Android 平台集成配置。openvela 工程根目录的 `build.sh` 编译入口依赖本仓库。

## 目录结构

| 目录 / 文件 | 说明 |
| ---- | ---- |
| `envsetup.sh` | 构建环境初始化脚本，`source` 后向当前 Shell 注入 `lunch`、`m`/`mm`/`mmm`、`croot`、`godir` 等一系列构建与导航命令。 |
| `cmake/` | CMake 自定义模块。`nuttx_custom_module.cmake` 在 NuttX 构建基础上扩展 Vela 专属的编译配置（如 OPTEE TA 等）。 |
| `config_check/` | 配置检查工具。`config_checker.py` / `config_check_tool.py` 依据 `config_check_conf.yml` 校验各子系统（kernel、graphics/lvgl、media、bluetooth、quickapp 等）的 Kconfig 配置一致性。 |
| `android/` | openvela 与 Android 集成的构建配置（`vela.mk`、`goldfish64_*.mk`、`gsi64_*.mk` 等产品 makefile，及 `ueventd.vela.rc` 等）。 |

## 构建环境（envsetup.sh）

在工程根目录执行 `source build/envsetup.sh` 后，可使用以下命令：

| 命令 | 说明 |
| ---- | ---- |
| `lunch [vendor]-[board]-[config]` | 选择并锁定编译目标，供后续 `m` 等命令使用；无参数时进入交互式菜单。 |
| `m` | 从工程顶层编译当前选定目标。 |
| `mm` | 编译并安装所有库目标。 |
| `mmm` | 编译当前目录的库目标。 |
| `croot` | 切换到工程根目录（或其子目录）。 |
| `godir <regex>` | 跳转到包含指定文件的目录。 |
| `cgrep` / `kgrep` / `mgrep` | 分别在 C/C++ 源文件、Kconfig 文件、Makefile/CMake 文件中检索。 |
| `pvcc [CONFIG] [VALUE]` | 预览 Kconfig 配置变更的影响（PreView Config Change）。 |
| `hmm` | 显示上述命令的帮助信息。 |

可选环境变量：

| 变量 | 默认值 | 说明 |
| ---- | ---- | ---- |
| `VELA_CMAKE_GENERATOR` | `-GNinja` | CMake 生成器。 |
| `VELA_EXTRA_FLAGS` | `-Wno-cpp` | 额外编译标志。 |
| `NUTTX_DIR_NAME` | `nuttx` | NuttX 目录名（支持自定义）。 |
| `BEAR_MODE` | `0` | 启用 [bear](https://github.com/rizsotto/Bear) 生成 `compile_commands.json`。 |

> 默认构建基于 CMake + Ninja，并在检测到 `ccache` 时自动启用以加速编译。

## 使用方式

openvela 的编译统一通过工程根目录的 `build.sh` 进行，例如：

```bash
./build.sh vendor/openvela/boards/vela/configs/goldfish-arm64-v8a-ap/ --cmake -j8
```

或先 `source build/envsetup.sh` 再使用 `lunch` + `m` 组合进行编译。完整的环境准备与编译步骤，请参见 [快速入门（Ubuntu）](../../../../open-vela/docs/blob/dev-ai-contest-2026/zh-cn/quickstart/openvela_ubuntu_quick_start.md)。

## 许可协议

本仓库遵循 Apache 2.0 许可协议，详见 [LICENSE](./LICENSE)。
