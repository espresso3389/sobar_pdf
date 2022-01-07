# Using MSBuild with PowerShell
# https://patrickwbarnes.com/articles/using-msbuild-with-powershell/

Param(
  [Parameter(Mandatory = $true)] [ValidateSet("x64", "x86")] [String] $Arch
)

#
# Find vswhere (installed with recent Visual Studio versions).
#
If ($vsWhere = Get-Command "vswhere.exe" -ErrorAction SilentlyContinue) {
  $vsWhere = $vsWhere.Path
}
ElseIf (Test-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe") {
  $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
}
Else {
  Write-Error "vswhere not found. Aborting." -ErrorAction Stop
}
Write-Host "vswhere found at: $vsWhere" -ForegroundColor Yellow


#
# Get path to Visual Studio installation using vswhere.
#
$vsPath = &$vsWhere -utf8 -latest -property installationPath
If ([string]::IsNullOrEmpty("$vsPath")) {
  Write-Error "Failed to find Visual Studio installation. Aborting." -ErrorAction Stop
}
Write-Host "Using Visual Studio installation at: ${vsPath}" -ForegroundColor Yellow

#
# Load Microsoft.VisualStudio.DevShell.dll for Enter-VsDevShell
#
Import-Module (Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll")

#
#
#
Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=$Arch"
Write-Host "Visual Studio Command Prompt variables for $Arch set." -ForegroundColor Yellow

