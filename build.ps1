# Usage: build.ps1 -Arch x64
Param(
  [Parameter(Mandatory = $true)] [ValidateSet("x64", "x86")] [String] $Arch
)

.".\scripts\find_vs.ps1" -Arch $Arch
.".\scripts\git_info.ps1" -Path . -Name Sobar

if ($GITHUB_RUN_NUMBER) {
  $sobarRev = $GITHUB_RUN_NUMBER
}
else {
  $sobarRev = $env:SobarREV
}

$curDir = Get-Location
$tmpDir = "$curDir/.work"
$cacheDir = "$curDir/.cache"
$outDir = "$curDir/.work/$Arch"

$compiler = "${env:VCToolsInstallDir}bin/HostX64/$Arch/cl.exe".Replace("\", "/")

cmake -S . -B "$outDir" -G Ninja -DCMAKE_BUILD_TYPE=Release "-DSOBAR_TARGET_STR=windows-$Arch-static" "-DSOBAR_REVISION=$sobarRev" "-DSOBAR_COMMIT=$env:SobarCOMMIT" "-DSOBAR_TMP_DIR=$tmpDir" "-DSOBAR_CACHE_DIR=$cacheDir" "-DCMAKE_C_COMPILER=$compiler" "-DCMAKE_CXX_COMPILER=$compiler"

cmake --build "$outDir"

$dist = "dist/$Arch"
mkdir "$dist" -Force | Out-Null

# header file
$includeDir = "$dist/include"
mkdir "$includeDir" -Force | Out-Null
Copy-Item -Path "./include/sobar.h" -Destination "$includeDir/sobar.h"
$header = @"
// revision: $sobarRev, commit: $env:SobarCOMMIT
"@
Write-Output $header | Add-Content -Path "$includeDir/sobar.h"

# lib files
$libDir = "$dist/lib/windows/$Arch"
mkdir "$libDir" -Force | Out-Null
Copy-Item -Path "$outDir/src/sobar.dll" -Destination "$libDir/sobar.dll" -Force
Copy-Item -Path "$outDir/src/sobar.lib" -Destination "$libDir/sobar.lib" -Force

Write-Host "Finished."
