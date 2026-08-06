<#
.SYNOPSIS
    Install the patterns-and-refactoring skill for Claude Code.

.EXAMPLE
    .\install.ps1
    Installs globally to $HOME\.claude\skills

.EXAMPLE
    .\install.ps1 -Project
    Installs to .\.claude\skills in the current directory
#>
[CmdletBinding()]
param(
    [switch]$Project,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$SkillName = 'patterns-and-refactoring'
$SourceDir = Join-Path $PSScriptRoot "skills\$SkillName"

if (-not (Test-Path $SourceDir)) {
    Write-Error "Skill source not found at $SourceDir"
    exit 1
}

if ($Project) {
    $TargetRoot = Join-Path (Get-Location) '.claude\skills'
    $Scope      = "project ($(Get-Location))"
} else {
    $TargetRoot = Join-Path $HOME '.claude\skills'
    $Scope      = "global ($HOME\.claude)"
}

$TargetDir = Join-Path $TargetRoot $SkillName

if (Test-Path $TargetDir) {
    if (-not $Force) {
        $reply = Read-Host "Skill already installed at $TargetDir. Overwrite? [y/N]"
        if ($reply -notmatch '^[yY]') {
            Write-Host 'Aborted.'
            exit 0
        }
    }
    Remove-Item $TargetDir -Recurse -Force
}

New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
Copy-Item $SourceDir $TargetDir -Recurse -Force

$refCount = (Get-ChildItem (Join-Path $TargetDir 'references') -Filter '*.md' -File).Count

Write-Host "Installed $SkillName - $Scope" -ForegroundColor Green
Write-Host "  $TargetDir"
Write-Host "  SKILL.md + $refCount reference files"
Write-Host ''
Write-Host 'Verify with /skills inside Claude Code.'
Write-Host 'To make invocation mandatory, see CLAUDE.md.snippet.md.'
