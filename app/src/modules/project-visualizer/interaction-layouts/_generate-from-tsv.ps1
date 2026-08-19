# Generates interaction-layout *.sdl from _catalog.tsv
$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot
$tsv = Join-Path $dir "_catalog.tsv"
$preserve = @("node", "npm", "pnpm", "vite", "next", "solid", "dub", "rust")

function Escape-Sdl([string]$s) {
    if ($null -eq $s) { return "" }
    return $s.Replace('"', '`"')
}

$rows = Import-Csv -Path $tsv -Delimiter "`t"
$count = 0
foreach ($r in $rows) {
    $id = $r.id.Trim()
    if ($preserve -contains $id) { continue }
    $anchors = ($r.anchors -split '\s+' | Where-Object { $_ -and $_ -ne '.' } | ForEach-Object { "`"$_`"" }) -join " "
    if (-not $anchors) { $anchors = '".git"' }

    $presetBlocks = New-Object System.Collections.Generic.List[string]
    foreach ($p in ($r.presets -split '\|')) {
        if (-not $p) { continue }
        $eq = $p.IndexOf("=")
        if ($eq -lt 1) { continue }
        $presetId = $p.Substring(0, $eq)
        $cmd = $p.Substring($eq + 1)
        $presetBlocks.Add(@"
    preset {
        id "$presetId"
        label "$presetId"
        command "$cmd"
        cwd "$($r.zoneId)"
    }
"@)
    }

    $extractLines = New-Object System.Collections.Generic.List[string]
    if ($r.extract) {
        $colon = $r.extract.IndexOf(":")
        if ($colon -ge 0) {
            $man = $r.extract.Substring(0, $colon)
            $fields = $r.extract.Substring($colon + 1)
            if ($man -and $man -ne ".") {
                if ($fields) {
                    $fquoted = ($fields -split ',' | ForEach-Object { "`"$($_.Trim())`"" }) -join " "
                    $extractLines.Add("        manifest `"$man`" fields $fquoted")
                } else {
                    $extractLines.Add("        manifest `"$man`"")
                }
            }
        }
    }

    $parentLine = ""
    if ($r.parent) { $parentLine = "    parentTool `"$($r.parent)`"`r`n" }

    $extractBlock = ""
    if ($extractLines.Count) {
        $extractBlock = @"

    extract {
$($extractLines -join "`r`n")
    }
"@
    }

    $sdl = @"
// $($r.name) - interaction layout profile (Project Visualizer).
interactionLayout {
    id "$id"
    name "$($r.name)"
    stackRef "$($r.stack)"
    profileVersion "0.1.0"
$parentLine
    summary "$($r.summary)"

    layout zone {
        id "$($r.zoneId)"
        title "$($r.zoneTitle)"
        order 1
        memoryBin "$($r.mem)"
        anchorFiles $anchors
    }

    grammar {
        id "primary"
        shape "$($r.shape)"
        scriptSource "$($r.scriptSrc)"
        notes "$($r.notes)"
    }

$($presetBlocks -join "`r`n")$extractBlock
}
"@
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $dir "$id.sdl"), $sdl.Trim() + "`n", $utf8)
    $count++
}
Write-Host "Wrote $count profiles. TSV rows: $($rows.Count). Preserved: $($preserve -join ', ')."
