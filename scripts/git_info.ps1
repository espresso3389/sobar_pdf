Param(
  [String]$Path,
  [String]$Name
)

Push-Location $Path
$branch, $commit = (git for-each-ref '--format=%(refname) %(objectname)' --sort=-committerdate)[0].Trim().Split(" ")
$rev = ((git log --oneline) | Out-String).length

$commit = $commit.Substring(0, 6)

New-Item -Path @("env:" + $Name + "Commit") -Value $commit -Force
New-Item -Path @("env:" + $Name + "Branch") -Value $branch -Force
New-Item -Path @("env:" + $Name + "Rev") -Value $rev -Force

if ($env:GITHUB_ENV) {
  Write-Output "${Name}COMMIT=$commit" | Add-Content -Path $env:GITHUB_ENV
  Write-Output "${Name}BRANCH=$branch" | Add-Content -Path $env:GITHUB_ENV
  Write-Output "${Name}REV=$rev" | Add-Content -Path $env:GITHUB_ENV
}

Pop-Location
