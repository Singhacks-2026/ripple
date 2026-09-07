# Install the repo's skills into the agents that read a SKILL.md folder:
# Claude Code (.claude\skills), Cursor (.cursor\skills), and Codex (.codex\skills).
#
# PowerShell equivalent of install.sh for Windows, where symlinks committed in
# git check out as tiny text stubs and ln -s is unavailable. This copies each
# skill folder into the three target directories, overwriting any stale copy or
# broken stub. Idempotent: safe to run repeatedly. Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File skills\install.ps1
$ErrorActionPreference = "Stop"

$SkillsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $SkillsDir
$Targets   = @(".claude\skills", ".cursor\skills", ".codex\skills")

$installed = 0
Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
  $skill = $_
  if (-not (Test-Path (Join-Path $skill.FullName "SKILL.md"))) { return }
  foreach ($t in $Targets) {
    $dir = Join-Path $RepoRoot $t
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dest = Join-Path $dir $skill.Name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse -Force -Path $skill.FullName -Destination $dest
    $rel = $dest.Substring($RepoRoot.Length + 1)
    Write-Host "copied  $rel"
  }
  $installed++
}

Write-Host ""
Write-Host "installed $installed skill(s) into: $($Targets -join ', ')"
Write-Host "Cursor also reads .claude\skills and .codex\skills, so it is covered as well."
Write-Host "Skills were copied (not symlinked); re-run this after pulling new changes."
Write-Host "Next: invoke /xrpl-agentic-resources in your agent, or run its refresh once:"
Write-Host "  powershell -ExecutionPolicy Bypass -File skills\xrpl-agentic-resources\scripts\refresh.ps1"
