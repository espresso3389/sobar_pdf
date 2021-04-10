@echo off

rem https://pdfium.googlesource.com/pdfium/+/refs/heads/chromium/4147
rem set LAST_KNOWN_GOOD_COMMIT=3e36f68831431bf497babc74075cd69af5fd9823

set SCRIPTS_DIR=%~dp0
set VCPKG_TARGET_TRIPLET=%1
REM x64 or x86
set GN_ARCH=%2
REM static or dll
set STATIC_OR_DLL=%3
REM Release or Debug
set REL_OR_DBG=%4
REM depot_tools directory
set DEPOT_DIR=%5

if /i %STATIC_OR_DLL% == static (
    set IS_SHAREDLIB=false
) else (
   set IS_SHAREDLIB=true
)

if /i %REL_OR_DBG% == Release (
    set IS_DEBUG=false
    set DIR_DEBUG_SUFFIX=
) else (
    set IS_DEBUG=true
    set DIR_DEBUG_SUFFIX=\debug
)

set DEPOT_TOOLS_WIN_TOOLCHAIN=0
set PATH=%DEPOT_DIR%;%PATH:Microsoft\WindowsApps=dummy%

if not exist pdfium\.git\index (
    call gclient.bat config -vvv --unmanaged https://pdfium.googlesource.com/pdfium.git
    if ERRORLEVEL 1 exit /b 1

    call gclient.bat sync -vvv
    if ERRORLEVEL 1 exit /b 1
)

if not exist pdfium\.git\index (
    exit /b 1
)

cd pdfium
set BUILDIR=%cd%\out\%VCPKG_TARGET_TRIPLET%%DIR_DEBUG_SUFFIX%

call git reset --hard
if ERRORLEVEL 1 exit /b 1

REM current working version we know
call git checkout %LAST_KNOWN_GOOD_COMMIT%
if ERRORLEVEL 1 exit /b 1

if not exist %BUILDIR%\obj\pdfium.lib (
    mkdir %BUILDIR% >NUL 2>NUL
    call :generate_argsgn %BUILDIR%\args.gn

    call gn gen %BUILDIR%
    if ERRORLEVEL 1 exit /b 1

    ninja -C %BUILDIR% pdfium
    REM if ERRORLEVEL 1 exit /b 1
    if not exist %BUILDIR%\obj\pdfium.lib exit /b 1
)
exit /b

:generate_argsgn
echo # > %1
echo is_clang = false >> %1
REM echo visual_studio_version = "%VSVER%" >> %1
echo target_cpu = "%GN_ARCH%" >> %1
echo pdf_is_complete_lib = true >> %1
echo pdf_is_standalone = true >> %1
echo is_component_build = %IS_SHAREDLIB% >> %1
echo is_debug = %IS_DEBUG% >> %1
echo enable_iterator_debugging = %IS_DEBUG% >> %1
echo pdf_enable_xfa = false >> %1
echo pdf_enable_v8 = false >> %1

exit /b
