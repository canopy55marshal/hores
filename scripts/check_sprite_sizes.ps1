$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function Get-PngSize([string]$path) {
  $img = [System.Drawing.Image]::FromFile($path)
  try {
    return @{ Width = $img.Width; Height = $img.Height }
  } finally {
    $img.Dispose()
  }
}

function Get-SequenceNameFn([string]$dir, [string]$kind) {
  if ($kind -eq 'g') {
    if (Test-Path -LiteralPath (Join-Path $dir 'g_hores_run_0000.png')) {
      return { param([int]$i) ("g_hores_run_{0}.png" -f (($i - 1).ToString('0000'))) }
    }
    if (Test-Path -LiteralPath (Join-Path $dir '1_g_hores_run.png')) {
      return { param([int]$i) ("{0}_g_hores_run.png" -f $i) }
    }
  }
  if ($kind -eq 'horse') {
    if (Test-Path -LiteralPath (Join-Path $dir '1_horesrun.png')) {
      return { param([int]$i) ("{0}_horesrun.png" -f $i) }
    }
  }
  throw "Unknown or unsupported sequence naming in $dir"
}

function Check-Sequence([string]$dir, [ScriptBlock]$nameFn, [int]$start, [int]$end) {
  $base = $null
  $missing = @()
  $mismatch = @()

  for ($i = $start; $i -le $end; $i++) {
    $name = & $nameFn $i
    $file = Join-Path $dir $name
    if (!(Test-Path -LiteralPath $file)) {
      $missing += $file
      continue
    }
    $s = Get-PngSize $file
    if ($null -eq $base) { $base = $s }
    if ($s.Width -ne $base.Width -or $s.Height -ne $base.Height) {
      $mismatch += "$file => $($s.Width)x$($s.Height) (base $($base.Width)x$($base.Height))"
    }
  }

  [PSCustomObject]@{
    Dir = $dir
    Base = if ($null -eq $base) { $null } else { "$($base.Width)x$($base.Height)" }
    MissingCount = $missing.Count
    MismatchCount = $mismatch.Count
    Missing = $missing
    Mismatch = $mismatch
  }
}

$gDir = 'E:\hores\assets\sprites\g_hores_run'
$hDir = 'E:\hores\assets\sprites\horse_run'
$g = Check-Sequence $gDir (Get-SequenceNameFn $gDir 'g') 1 20
$h = Check-Sequence $hDir (Get-SequenceNameFn $hDir 'horse') 1 20

$all = @($g, $h)
$all | Select-Object Dir, Base, MissingCount, MismatchCount | Format-Table -AutoSize

foreach ($r in $all) {
  if ($r.MissingCount -gt 0) {
    Write-Host ''
    Write-Host "Missing files in $($r.Dir):"
    $r.Missing | ForEach-Object { Write-Host "  $_" }
  }
  if ($r.MismatchCount -gt 0) {
    Write-Host ''
    Write-Host "Mismatched sizes in $($r.Dir):"
    $r.Mismatch | ForEach-Object { Write-Host "  $_" }
  }
}

if ($g.Base -and $h.Base -and $g.Base -ne $h.Base) {
  Write-Host ''
  Write-Host "WARNING: base sizes differ: g_hores_run=$($g.Base) horse_run=$($h.Base)"
  exit 2
}

if ($all | Where-Object { $_.MissingCount -gt 0 -or $_.MismatchCount -gt 0 }) {
  exit 3
}

Write-Host ''
Write-Host 'OK: sprite sequences are complete and consistent.'
