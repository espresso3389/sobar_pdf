# sobar; simple pdfium wrapper

# Overview

sobar is a simple PDF renderer implementation based on [pdfium](https://pdfium.googlesource.com/pdfium/) targeted for Windows and Linux.

The first motivation for the project is to support Windows and Linux on [flutter_pdf_render](https://github.com/espresso3389/flutter_pdf_render) plugin.


# Prerequisites

## Windows

For the following components, see [Checking out and Building Chromium for Windows](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/windows_build_instructions.md#visual-studio).

- [Visual Studio 2019](https://visualstudio.microsoft.com/)
- Debugging Tools for Windows

Use [scoop](https://scoop.sh/) to install additional commands:

```
scoop install cmake ninja git
```

## Linux (Ubuntu 20.04 LTS)

```
sudo apt install git build-essential cmake ninja-build pkg-config
```

## macOS

[Homebrew](https://brew.sh/) is a command-line package manager for macOS.

```
brew install git cmake ninja
```

# How to build

If you just need your copy of sobar modules, please just fork the repo. You'll find your copy is building on your "Actions" tab.

## Windows

For Windows, you can build the library using `build.ps1` PowerShell script. It accepts a parameter, either `x64` or `x86` depending on your CPU architecture:

```pwsh
.\build.ps1 x64
```

## Linux/Android/macOS/iOS

`./build.sh` accepts two parameters. The first one is `ARCH`, which should be one of `x86`, `x64`, `arm`, or `arm64`. The second one is `PLATFORM`, one of `linux`, `android`, `mac`, or `ios`:


```sh
./build.sh x64 linux
```
