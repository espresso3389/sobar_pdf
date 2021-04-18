# sobar; simple pdfium wrapper

# Overview

sobar is a simple PDF renderer implementation based on [pdfium](https://pdfium.googlesource.com/pdfium/) targeted for Windows and Linux.

The first motivation for the project is to support Windows and Linux on [flutter_pdf_render](https://github.com/espresso3389/flutter_pdf_render) plugin.

# How to build

If you just need your copy of sobar modules, please just fork the repo. You'll find your copy is building on your "Actions" tab.

## Windows

For Windows, you can build the library using `build.ps1` PowerShell script. It accepts a parameter, either `x64` or `x86` depending on your CPU architecture:

```pwsh
.\build.ps1 x64
```

## Linux

TBD
