# https://pdfium.googlesource.com/pdfium/+/refs/heads/chromium/4147
# $lastKnownGoodCommit = "3e36f68831431bf497babc74075cd69af5fd9823"

param(
  [Parameter(Mandatory = $true)]  [String] $sobarTargetStr,
  [Parameter(Mandatory = $true)] [ValidateSet("x64", "x86")] [String] $Arch,
  [Parameter(Mandatory = $true)] [ValidateSet("static", "dll")] [String] $staticOrDll,
  [Parameter(Mandatory = $true)] [ValidateSet("Release", "Debug")] [String] $relOrDbg,
  [Parameter(Mandatory = $true)] [String] $depotDir,
  [Parameter(Mandatory = $true)] [String] $workDir
)

if ($staticOrDll -ieq "static") {
  $isSharedLib = "false"
}
else {
  $isSharedLib = "true"
}

if ($relOrDbg -ieq "Release") {
  $isDebug = "false"
  $dirDebugSuffix = ""
}
else {
  $isDebug = "true"
  $dirDebugSuffix = "/debug"
}

#
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = 0

# Microsoft\WindowsApps path may contains python.exe and it harms the chromium build process :(
$path = $env:PATH.Replace("Microsoft\WindowsApps", "dummy")
$env:PATH = "$depotDir;$path"

Push-Location -Path $workDir
$workDir = Get-Location
$pdfiumSrcDir = "$workDir/pdfium"
$outDir = "$pdfiumSrcDir/out"
$buildDir = "$outDir/$sobarTargetStr$dirDebugSuffix"

if (!(Test-Path "pdfium/.git/index")) {
  cmd.exe /c gclient.bat config -vvv --unmanaged https://pdfium.googlesource.com/pdfium.git
  if ($LastExitCode) {
    Write-Host "gclient config failed."
    exit $LastExitCode
  }

  cmd.exe /c gclient.bat sync -vvv
  if ($LastExitCode) {
    Write-Host "gclient sync failed."
    exit $LastExitCode
  }
}

if ($lastKnownGoodCommit) {
  cmd.exe /c git reset --hard
  if ($LastExitCode) {
    Write-Host "git reset failed."
    exit $LastExitCode
  }
  cmd.exe /c git checkout $lastKnownGoodCommit
  if ($LastExitCode) {
    Write-Host "git checkout $lastKnownGoodCommit failed."
    exit $LastExitCode
  }
}

if (!(Test-Path "$buildDir/obj/pdfium.lib")) {
  mkdir -Force $buildDir | Out-Null
  $argsGn = @"
is_clang = false
target_cpu = "$Arch"
pdf_is_complete_lib = true
pdf_is_standalone = true
is_component_build = $isSharedLib
is_debug = $isDebug
enable_iterator_debugging = $isDebug
pdf_enable_xfa = false
pdf_enable_v8 = false
"@
  Write-Output $argsGn | Out-File -Encoding ascii -FilePath "$buildDir/args.gn"

  Push-Location $buildDir
  cmd.exe /c gn.bat gen .
  if ($LastExitCode) {
    Write-Host "gn gen failed."
    exit $LastExitCode
  }
  Pop-Location

  ninja -C $buildDir pdfium
  if (!(Test-Path "$buildDir/obj/pdfium.lib")) {
    Write-Host "Building pdfium failed."
    exit $LastExitCode
  }
}

Pop-Location

Write-Host "Generating $outDir/pdfium_commit.h..."
$curDir = Get-Location
."$curDir/../scripts/git_info.ps1" -Path "$pdfiumSrcDir" -Name pdfium
$pdfium_info_header = @"
#define PDFIUM_COMMIT "$env:pdfiumCommit"
"@
Write-Output $pdfium_info_header | Out-File -Encoding ascii -FilePath "$outDir/pdfium_commit.h"

Write-Host "Finished."
