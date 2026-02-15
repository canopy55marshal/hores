param(
  [Parameter(Mandatory = $true)][string]$Dir,
  [Parameter(Mandatory = $true)][string]$Pattern,
  [int]$Start = 0,
  [int]$End = 19,
  [int]$PadWidth = 4
)

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

$widths = @()
$heights = @()

for ($i = $Start; $i -le $End; $i++) {
  $token = if ($PadWidth -le 0) { [string]$i } else { $i.ToString(('0' * $PadWidth)) }
  $name = [string]::Format($Pattern, $token)
  $path = Join-Path $Dir $name
  if (!(Test-Path -LiteralPath $path)) { throw "Missing frame: $path" }
  $img = [System.Drawing.Bitmap]::FromFile($path)
  try {
    $b = Get-NonTransparentBounds $img
    if ($null -eq $b) { continue }
    $widths += [int]$b.Width
    $heights += [int]$b.Height
  } finally {
    $img.Dispose()
  }
}

if ($widths.Count -eq 0 -or $heights.Count -eq 0) { throw "No visible pixels found in $Dir" }

$widths = $widths | Sort-Object
$heights = $heights | Sort-Object
$mw = $widths[[int][Math]::Floor($widths.Count / 2)]
$mh = $heights[[int][Math]::Floor($heights.Count / 2)]

[PSCustomObject]@{
  Dir = $Dir
  Start = $Start
  End = $End
  MedianWidth = [int]$mw
  MedianHeight = [int]$mh
}
