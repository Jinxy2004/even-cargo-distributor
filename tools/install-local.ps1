# Copies the mod folder into the game's user-data folder.
#   -Staging   copy into staging_area (for validating/publishing from the in-game mod manager)
#   default    copy into mods (to play/test locally)
# Example: .\tools\install-local.ps1 -UserData 'C:\Users\Public\Documents\Steam\RUNE\3493540\local' -Staging
param(
    [Parameter(Mandatory = $true)][string]$UserData,
    [switch]$Staging
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'cargo_distribution_1'
if (-not (Test-Path -LiteralPath $UserData -PathType Container)) { throw 'User-data folder missing.' }
$targetRoot = Join-Path $UserData ($(if ($Staging) { 'staging_area' } else { 'mods' }))
$destination = Join-Path $targetRoot 'cargo_distribution_1'
if (Test-Path -LiteralPath (Join-Path $destination 'mod.json')) {
    $existing = Get-Content -LiteralPath (Join-Path $destination 'mod.json') -Raw | ConvertFrom-Json
    if ($existing.modId -ne 'cargo_distribution_1') { throw 'Destination holds a different mod.' }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
# Mirror: remove files that no longer exist in the source (e.g. renamed scripts).
Get-ChildItem -LiteralPath $destination -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($destination.Length).TrimStart('\')
    if (-not (Test-Path -LiteralPath (Join-Path $source $relative))) { Remove-Item -LiteralPath $_.FullName }
}
Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
Write-Output "Installed: $destination"
Write-Output 'Restart the game to load the new version.'
