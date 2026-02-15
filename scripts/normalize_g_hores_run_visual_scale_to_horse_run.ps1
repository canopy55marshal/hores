$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function Get-NonTransparentBounds([System.Drawing.Bitmap]$bmp) {
  $w = $bmp.Width
  $h = $bmp.Height

  $minX = $w
  $minY = $h
  $maxX = -1
  $maxY = -1

  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      $a = $bmp.GetPixel($x, $y).A
      if ($a -gt 0) {
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }

  if ($maxX -lt 0 -or $maxY -lt 0) { return $null }

  return @{
    MinX = $minX
    MinY = $minY
    MaxX = $maxX
    MaxY = $maxY
    Width = ($maxX - $minX + 1)
    Height = ($maxY - $minY + 1)
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

function Get-SequenceMedianBounds([string]$dir, [ScriptBlock]$nameFn, [int]$start, [int]$end) {
  $widths = @()
  $heights = @()

  for ($i = $start; $i -le $end; $i++) {
    $file = Join-Path $dir (& $nameFn $i)
    if (!(Test-Path -LiteralPath $file)) { throw "Missing frame: $file" }

    $img = [System.Drawing.Bitmap]::FromFile($file)
    try {
      $b = Get-NonTransparentBounds $img
      if ($null -eq $b) { continue }
      $widths += [int]$b.Width
      $heights += [int]$b.Height
    } finally {
      $img.Dispose()
    }
  }

  if ($widths.Count -eq 0 -or $heights.Count -eq 0) { throw "No visible pixels found in $dir" }

  $widths = $widths | Sort-Object
  $heights = $heights | Sort-Object
  $mw = $widths[[int][Math]::Floor($widths.Count / 2)]
  $mh = $heights[[int][Math]::Floor($heights.Count / 2)]
  return @{ Width = [int]$mw; Height = [int]$mh }
}

$refDir = 'E:\hores\assets\sprites\horse_run'
$gDir = 'E:\hores\assets\sprites\g_hores_run'

$refNameFn = Get-SequenceNameFn $refDir 'horse'
$gNameFn = Get-SequenceNameFn $gDir 'g'

$ref0 = Join-Path $refDir (& $refNameFn 1)
$g0 = Join-Path $gDir (& $gNameFn 1)
if (!(Test-Path -LiteralPath $ref0)) { throw "Missing reference: $ref0" }
if (!(Test-Path -LiteralPath $g0)) { throw "Missing reference: $g0" }

$refSize = [System.Drawing.Image]::FromFile($ref0)
try {
  $targetW = [int]$refSize.Width
  $targetH = [int]$refSize.Height
} finally { $refSize.Dispose() }

$refBounds = Get-SequenceMedianBounds $refDir $refNameFn 1 20
$gBounds = Get-SequenceMedianBounds $gDir $gNameFn 1 20

$scaleW = $refBounds.Width / [double]$gBounds.Width
$scaleH = $refBounds.Height / [double]$gBounds.Height
$scale = [Math]::Min($scaleW, $scaleH)

if ($scale -ge 0.999 -and $scale -le 1.001) {
  Write-Host ("OK: visual scale already aligned. ref={0}x{1} g={2}x{3} scale={4}" -f $refBounds.Width,$refBounds.Height,$gBounds.Width,$gBounds.Height,$scale)
  exit 0
}

Write-Host ("Canvas: {0}x{1}" -f $targetW, $targetH)
Write-Host ("Ref median bounds: {0}x{1}" -f $refBounds.Width, $refBounds.Height)
Write-Host ("G   median bounds: {0}x{1}" -f $gBounds.Width, $gBounds.Height)
Write-Host ("Applying scale: {0}" -f $scale)

$backupDir = Join-Path $gDir ("_backup_before_visual_scale_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backupDir | Out-Null

$changed = 0
for ($i = 1; $i -le 20; $i++) {
  $file = Join-Path $gDir (& $gNameFn $i)
  Copy-Item -LiteralPath $file -Destination (Join-Path $backupDir ([IO.Path]::GetFileName($file))) -Force

  $img = [System.Drawing.Image]::FromFile($file)
  try {
    $newW = [int][Math]::Round($img.Width * $scale)
    $newH = [int][Math]::Round($img.Height * $scale)
    if ($newW -lt 1) { $newW = 1 }
    if ($newH -lt 1) { $newH = 1 }

    $bmp = New-Object System.Drawing.Bitmap $targetW, $targetH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $bmp.SetResolution($img.HorizontalResolution, $img.VerticalResolution)
      $g = [System.Drawing.Graphics]::FromImage($bmp)
      try {
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)

        $x = [int][Math]::Floor(($targetW - $newW) / 2)
        $y = [int][Math]::Floor(($targetH - $newH) / 2)
        $g.DrawImage($img, $x, $y, $newW, $newH)
      } finally {
        $g.Dispose()
      }

      $tmp = $file + '.tmp'
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
      $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
      $changed++
    } finally {
      $bmp.Dispose()
    }
  } finally {
    $img.Dispose()
  }

  if (!(Test-Path -LiteralPath $tmp)) { throw "Missing temp output: $tmp" }
  if (Test-Path -LiteralPath $file) {
    Copy-Item -LiteralPath $tmp -Destination $file -Force
    Remove-Item -LiteralPath $tmp -Force
  } else {
    Move-Item -LiteralPath $tmp -Destination $file -Force
  }
}

Write-Host ("Done. scaled_frames={0} backup={1}" -f $changed, $backupDir)
