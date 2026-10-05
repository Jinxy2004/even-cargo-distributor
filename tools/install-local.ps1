param(
    [Parameter(Mandatory = $true)][string]$UserData,
    [string]$SaveName = ''
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $taskRoot 'cargo_distribution_1'
$modRoot = Join-Path $UserData 'mods'
$destination = Join-Path $modRoot 'cargo_distribution_1'
if (-not (Test-Path -LiteralPath $UserData -PathType Container)) { throw 'User-data folder missing.' }
if (Test-Path -LiteralPath $destination) {
    $existing = Get-Content -LiteralPath (Join-Path $destination 'mod.json') -Raw | ConvertFrom-Json
    if ($existing.modId -ne 'cargo_distribution_1') { throw 'Destination has another mod identity.' }
}
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
if ($SaveName) {
    if ([IO.Path]::GetFileName($SaveName) -ne $SaveName) { throw 'SaveName must be a filename.' }
    $saveRoot = Join-Path $UserData 'save'
    $original = Join-Path $saveRoot $SaveName
    $copy = Join-Path $saveRoot 'Cargo Distribution - TEST ONLY.sav'
    if ((Test-Path -LiteralPath $original) -and -not (Test-Path -LiteralPath $copy)) {
        Copy-Item -LiteralPath $original -Destination $copy
        Write-Output "Created separate test copy: $copy"
    }
}
Write-Output "Installed: $destination"
Write-Output 'Restart the game if needed, then enable the mod only on your chosen test save.'
