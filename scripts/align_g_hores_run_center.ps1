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
      if ($bmp.GetPixel($x, $y).A -gt 0) {
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

function Get-GNameFn([string]$dir) {
  if (Test-Path -LiteralPath (Join-Path $dir 'g_hores_run_0000.png')) {
    return { param([int]$i) ("g_hores_run_{0}.png" -f (($i - 1).ToString('0000'))) }
  }
  if (Test-Path -LiteralPath (Join-Path $dir '1_g_hores_run.png')) {
    return { param([int]$i) ("{0}_g_hores_run.png" -f $i) }
  }
  throw "Unknown g_hores_run naming in $dir"
}

$dir = 'E:\hores\assets\sprites\g_hores_run'
if (!(Test-Path -LiteralPath $dir)) { throw "Missing dir: $dir" }
$nameFn = Get-GNameFn $dir

$ref = Join-Path $dir (& $nameFn 1)
if (!(Test-Path -LiteralPath $ref)) { throw "Missing ref: $ref" }
$refImg = [System.Drawing.Image]::FromFile($ref)
try {
  $w = [int]$refImg.Width
  $h = [int]$refImg.Height
} finally {
  $refImg.Dispose()
}

$backupDir = Join-Path $dir ("_backup_before_anchor_align_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backupDir | Out-Null

$cx = ($w - 1) / 2.0
$cy = ($h - 1) / 2.0

$changed = 0
for ($i = 1; $i -le 20; $i++) {
  $file = Join-Path $dir (& $nameFn $i)
  if (!(Test-Path -LiteralPath $file)) { throw "Missing frame: $file" }
  Copy-Item -LiteralPath $file -Destination (Join-Path $backupDir ([IO.Path]::GetFileName($file))) -Force

  $bmpIn = [System.Drawing.Bitmap]::FromFile($file)
  try {
    $b = Get-NonTransparentBounds $bmpIn
    if ($null -eq $b) { continue }

    $bx = $b.MinX + ($b.Width - 1) / 2.0
    $by = $b.MinY + ($b.Height - 1) / 2.0
    $dx = [int][Math]::Round($cx - $bx)
    $dy = [int][Math]::Round($cy - $by)

    $bmpOut = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $g = [System.Drawing.Graphics]::FromImage($bmpOut)
      try {
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($bmpIn, $dx, $dy, $bmpIn.Width, $bmpIn.Height)
      } finally {
        $g.Dispose()
      }

      $tmp = $file + '.tmp'
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
      $bmpOut.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $bmpOut.Dispose()
    }
  } finally {
    $bmpIn.Dispose()
  }

  $tmp = $file + '.tmp'
  if (!(Test-Path -LiteralPath $tmp)) { throw "Missing temp output: $tmp" }
  Copy-Item -LiteralPath $tmp -Destination $file -Force
  Remove-Item -LiteralPath $tmp -Force
  $changed++
}

Write-Host ("Done. aligned_frames={0} backup={1}" -f $changed, $backupDir)
