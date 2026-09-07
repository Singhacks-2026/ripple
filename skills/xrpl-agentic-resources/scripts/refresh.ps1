# Windows-friendly wrapper for refresh.sh.
#
# On Windows, running `bash scripts/refresh.sh` often resolves to the WSL bash
# launcher, which fails with E_ACCESSDENIED on a normal Git checkout. This finds
# the Git for Windows bash.exe explicitly and runs refresh.sh through it, so the
# same crawl and clone logic works without WSL. Requires Git for Windows (which
# also provides curl). Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File scripts\refresh.ps1
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RefreshSh = Join-Path $ScriptDir "refresh.sh"
if (-not (Test-Path $RefreshSh)) {
  Write-Error "refresh.sh not found next to this script ($RefreshSh)"
  exit 1
}

# Candidate locations for Git for Windows bash.exe, most specific first. Avoid
# System32\bash.exe on purpose: that is the WSL launcher.
$candidates = @(
  (Get-Command "git.exe" -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path (Split-Path -Parent (Split-Path -Parent $_.Source)) "bin\bash.exe" }),
  "$env:ProgramFiles\Git\bin\bash.exe",
  "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
  "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$bash = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $bash) {
  Write-Error "Could not find Git for Windows bash.exe. Install Git for Windows, or run refresh.sh from Git Bash directly."
  exit 1
}

Write-Host "Using $bash"
& $bash $RefreshSh
exit $LASTEXITCODE
