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

$gDir = 'E:\hores\assets\sprites\g_hores_run'
function Get-GName([int]$i) { return ("g_hores_run_{0}.png" -f (($i - 1).ToString('0000'))) }
if (!(Test-Path -LiteralPath (Join-Path $gDir (Get-GName 1))) -and (Test-Path -LiteralPath (Join-Path $gDir '1_g_hores_run.png'))) {
  function Get-GName([int]$i) { return ("{0}_g_hores_run.png" -f $i) }
}

$horseRef = 'E:\hores\assets\sprites\horse_run\1_horesrun.png'
if (!(Test-Path -LiteralPath $horseRef)) { throw "Missing reference: $horseRef" }
$refSize = Get-PngSize $horseRef
$targetW = [int]$refSize.Width
$targetH = [int]$refSize.Height

if (!(Test-Path -LiteralPath $gDir)) { throw "Missing dir: $gDir" }

$backupDir = Join-Path $gDir ("_backup_before_match_" + $targetW + "x" + $targetH)
if (!(Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

$files = @()
for ($i = 1; $i -le 20; $i++) {
  $p = Join-Path $gDir (Get-GName $i)
  if (!(Test-Path -LiteralPath $p)) { throw "Missing frame: $p" }
  $files += Get-Item -LiteralPath $p
}
foreach ($f in $files) {
  $b = Join-Path $backupDir $f.Name
  if (!(Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $f.FullName -Destination $b -Force }
}

$changed = 0
$skipped = 0

foreach ($f in $files) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  try {
    if ($img.Width -eq $targetW -and $img.Height -eq $targetH) { $skipped++; continue }

    $scaleW = $targetW / [double]$img.Width
    $scaleH = $targetH / [double]$img.Height
    $scale = [Math]::Min($scaleW, $scaleH)
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

      $tmp = $f.FullName + '.tmp'
      if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
      $bmp.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)

      $img.Dispose(); $img = $null
      Move-Item -LiteralPath $tmp -Destination $f.FullName -Force
      $changed++
    } finally {
      $bmp.Dispose()
    }
  } finally {
    if ($img) { $img.Dispose() }
  }
}

Write-Host ("Done. target={0}x{1} resized={2} skipped={3} backup={4}" -f $targetW, $targetH, $changed, $skipped, $backupDir)
