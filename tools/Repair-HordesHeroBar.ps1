<#
.SYNOPSIS
    Removes the slot hover highlight from Hordes of Azeroth's hero bar, which greys every icon.

.DESCRIPTION
    Hordes of Azeroth's engine draws the HIGHLIGHT layer all the time, not only on mouse-over, and an
    addon can't hide it once it exists. So the four lines in HordesOfAzeroth\VanillaBonkHeroBar.lua
    (CreateSlot) that make the slot highlight are taken out. A Hordes update puts them back: run this
    again after updating. Safe to run any number of times; it does nothing when the lines are gone.
    The original is kept next to it as VanillaBonkHeroBar.lua.bak.

.PARAMETER GamePath
    The Hordes of Azeroth folder.

.EXAMPLE
    .\Repair-HordesHeroBar.ps1 -WhatIf

.EXAMPLE
    .\Repair-HordesHeroBar.ps1 -GamePath 'D:\Games\Hordes of Azeroth'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$GamePath = 'C:\Games\Hordes of Azeroth'
)

$file = Join-Path $GamePath 'benilla-config\AddOns\HordesOfAzeroth\VanillaBonkHeroBar.lua'
if (-not (Test-Path $file)) {
    Write-Host "[!] Not found: $file"
    exit 1
}

$text = [IO.File]::ReadAllText($file)
# the four highlight lines, whatever the line endings
$pattern = '(?m)^[ \t]*slot\.highlight = slot:CreateTexture\(nil, "HIGHLIGHT"\)\r?\n' +
           '[ \t]*slot\.highlight:SetTexture\("Interface\\\\Buttons\\\\ButtonHilight-Square"\)\r?\n' +
           '[ \t]*slot\.highlight:SetBlendMode\("ADD"\)\r?\n' +
           '[ \t]*slot\.highlight:SetAllPoints\(slot\)\r?\n'

if ($text -notmatch $pattern) {
    if ($text -match 'slot\.highlight') {
        Write-Host "[warn] slot.highlight is there but not in the expected form; Hordes changed the file. Nothing done."
        exit 1
    }
    Write-Host "[ok] Already repaired: no slot highlight in $file"
    exit 0
}

if (-not $PSCmdlet.ShouldProcess($file, 'remove the slot highlight lines')) {
    Write-Host "WhatIf: would remove the 4 slot highlight lines from $file (backup to .bak)"
    exit 0
}

Copy-Item $file "$file.bak" -Force
$newline = if ($text -match "`r`n") { "`r`n" } else { "`n" }
$text = [regex]::Replace($text, $pattern, "    -- slot highlight removed by Repair-HordesHeroBar.ps1: this engine draws it all the time$newline")
[IO.File]::WriteAllText($file, $text)
Write-Host "[ok] Removed the slot highlight from $file (original saved as .bak). /reload in game to see it."
