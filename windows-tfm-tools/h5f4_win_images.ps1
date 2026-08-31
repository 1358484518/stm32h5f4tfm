# Locate STM32H5F4 TF-M images when Python is not on PATH.
# Prints the same KEY=value lines as h5f4_win_images.py locate.
# Usage: h5f4_win_images.ps1 locate [OutFile]
# OutFile is written as ASCII so cmd.exe for /f can parse it (powershell
# redirected from cmd would otherwise emit UTF-16).
param(
    [string]$Command = "locate",
    [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = [Console]::OutputEncoding

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$cwd = (Get-Location).Path

$requiredSlots = @{
    boot  = "0xc00e000"
    slot0 = "0xc038000"
    slot1 = "0xc090000"
    slot2 = "0xc200000"
    slot3 = "0xc258000"
}

function Emit($info) {
    $lines = @()
    foreach ($k in @("STATUS","ERROR","REPO","BL2","S_SIGNED","S_NS_SIGNED","NS_SIGNED","UPDATE_SH")) {
        $v = ""
        if ($info.ContainsKey($k)) { $v = $info[$k] }
        $lines += ("{0}={1}" -f $k, $v)
    }
    if ($OutFile) {
        Set-Content -LiteralPath $OutFile -Value $lines -Encoding Ascii
    } else {
        $lines | ForEach-Object { Write-Output $_ }
    }
}

function SearchDirs {
    $dirs = @(
        (Join-Path $repoRoot "trusted-firmware-m\build_s\api_ns\bin"),
        (Join-Path $repoRoot "trusted-firmware-m\build_ns\bin"),
        (Join-Path $repoRoot "trusted-firmware-m\build_s\api_ns\image_signing\scripts"),
        $cwd,
        $scriptDir
    )
    $seen = @{}
    $out = @()
    foreach ($d in $dirs) {
        $ap = [IO.Path]::GetFullPath($d)
        if (-not $seen.ContainsKey($ap)) {
            $seen[$ap] = $true
            $out += $ap
        }
    }
    return $out
}

function FirstExisting($dirs, $names) {
    foreach ($d in $dirs) {
        foreach ($name in $names) {
            $p = Join-Path $d $name
            if (Test-Path -LiteralPath $p -PathType Leaf) {
                Write-Output $p
            }
        }
    }
}

function MarkerError($path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $text = [Text.Encoding]::GetEncoding(28591).GetString($bytes)
    $missing = @()
    foreach ($m in @("H5F4BL2", "H5F4SWP2")) {
        if ($text.IndexOf($m) -lt 0) { $missing += $m }
    }
    if ($missing.Count -gt 0) {
        return ("{0} missing {1} (old H573 image or wrong file)" -f $path, ($missing -join ", "))
    }
    return $null
}

$info = @{
    STATUS = "OK"
    ERROR = ""
    BL2 = ""
    S_SIGNED = ""
    S_NS_SIGNED = ""
    NS_SIGNED = ""
    UPDATE_SH = ""
    REPO = $repoRoot
}

$updateSh = Join-Path $repoRoot "trusted-firmware-m\build_s\api_ns\TFM_UPDATE.sh"
if (Test-Path -LiteralPath $updateSh -PathType Leaf) {
    $slots = @{}
    foreach ($line in [IO.File]::ReadAllLines($updateSh)) {
        if ($line -match "^(boot|slot[0-3])=(.+)$") {
            $slots[$Matches[1]] = $Matches[2].Trim()
        }
    }
    $bad = @()
    foreach ($key in $requiredSlots.Keys) {
        $want = $requiredSlots[$key]
        $got = $slots[$key]
        if ($got -ne $want) {
            if (-not $got) { $got = "<missing>" }
            $bad += ("{0}={1} (want {2})" -f $key, $got, $want)
        }
    }
    if ($bad.Count -gt 0) {
        $info.STATUS = "FAIL"
        $info.ERROR = ("{0} flash map is not H5F4: {1}" -f $updateSh, ($bad -join "; "))
        Emit $info
        exit 1
    }
    $info.UPDATE_SH = $updateSh
}

$dirs = SearchDirs
$bl2 = $null
$skipped = @()
foreach ($cand in (FirstExisting $dirs @("bl2.bin", "bl2.hex"))) {
    $err = MarkerError $cand
    if ($err) {
        $skipped += $err
        continue
    }
    $bl2 = $cand
    break
}
if (-not $bl2) {
    $info.STATUS = "FAIL"
    if ($skipped.Count -gt 0) {
        $info.ERROR = ("no H5F4 BL2 (need H5F4BL2 + H5F4SWP2). " + ($skipped[0]))
    } else {
        $info.ERROR = "bl2.bin / bl2.hex not found. Run ./buildtfm.sh first (or copy bl2.bin here)."
    }
    Emit $info
    exit 1
}
$info.BL2 = $bl2

foreach ($cand in (FirstExisting $dirs @("tfm_s_signed.bin", "tfm_s_signed.hex"))) {
    $info.S_SIGNED = $cand
    break
}
foreach ($cand in (FirstExisting $dirs @("tfm_s_ns_signed.bin", "tfm_s_ns_signed.hex"))) {
    $info.S_NS_SIGNED = $cand
    break
}
foreach ($cand in (FirstExisting $dirs @("tfm_ns_signed.bin", "tfm_ns_signed.hex"))) {
    $info.NS_SIGNED = $cand
    break
}

$haveS = [string]::IsNullOrEmpty($info.S_SIGNED) -eq $false -or [string]::IsNullOrEmpty($info.S_NS_SIGNED) -eq $false
$haveNs = [string]::IsNullOrEmpty($info.NS_SIGNED) -eq $false -or [string]::IsNullOrEmpty($info.S_NS_SIGNED) -eq $false
if (-not $haveS) {
    $info.STATUS = "FAIL"
    $info.ERROR = "no S image (tfm_s_signed.bin or tfm_s_ns_signed.bin/.hex)."
    Emit $info
    exit 1
}
if (-not $haveNs) {
    $info.STATUS = "FAIL"
    $info.ERROR = "no NS image (tfm_ns_signed.bin) and no concatenated S+NS image."
    Emit $info
    exit 1
}

Emit $info
exit 0
