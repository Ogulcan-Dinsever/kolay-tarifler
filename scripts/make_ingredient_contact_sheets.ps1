Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workDir = Join-Path $scriptDir 'ingredient_image_work'
$outputDir = Join-Path $scriptDir 'ingredient_contact_sheets'
$state = Get-Content -Raw -LiteralPath (Join-Path $scriptDir 'ingredient_state_before.json') | ConvertFrom-Json
$candidateState = Get-Content -Raw -LiteralPath (Join-Path $scriptDir 'ingredient_image_candidates.json') | ConvertFrom-Json
$names = @{}
foreach ($ingredient in $state.ingredients) { $names[$ingredient.id] = $ingredient.name }
$selected = @{}
foreach ($property in $candidateState.items.PSObject.Properties) {
  if ($property.Value.selected -ge 0 -and $property.Value.status -eq 'candidate') {
    $selected[$property.Name] = $true
  }
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$files = @(Get-ChildItem -LiteralPath $workDir -File | Where-Object {
  $_.Extension -in '.jpg', '.jpeg', '.png' -and $selected.ContainsKey($_.BaseName)
} | Sort-Object BaseName)

$ErrorActionPreference = 'Stop'
$columnCount = 5
$rowCount = 4
$cellWidth = 240
$cellHeight = 225
$imageHeight = 180
$perSheet = $columnCount * $rowCount
$font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$smallFont = New-Object System.Drawing.Font('Segoe UI', 9)
$labelBrush = [System.Drawing.Brushes]::Black
$mutedBrush = [System.Drawing.Brushes]::DimGray

for ($start = 0; $start -lt $files.Count; $start += $perSheet) {
  $sheetIndex = [int]($start / $perSheet) + 1
  $bitmapWidth = [int]($columnCount * $cellWidth)
  $bitmapHeight = [int]($rowCount * $cellHeight)
  $bitmap = [System.Drawing.Bitmap]::new($bitmapWidth, $bitmapHeight)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([System.Drawing.Color]::White)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  for ($slot = 0; $slot -lt $perSheet -and ($start + $slot) -lt $files.Count; $slot++) {
    $file = $files[$start + $slot]
    $columnIndex = $slot % $columnCount
    $rowIndex = [int]($slot / $columnCount)
    $x = $columnIndex * $cellWidth
    $y = $rowIndex * $cellHeight
    try {
      $image = [System.Drawing.Image]::FromFile($file.FullName)
      $scale = [Math]::Min(($cellWidth - 10) / $image.Width, ($imageHeight - 10) / $image.Height)
      $drawWidth = [int]($image.Width * $scale)
      $drawHeight = [int]($image.Height * $scale)
      $drawX = $x + [int](($cellWidth - $drawWidth) / 2)
      $drawY = $y + [int](($imageHeight - $drawHeight) / 2)
      $graphics.DrawImage($image, $drawX, $drawY, $drawWidth, $drawHeight)
      $image.Dispose()
    } catch {
      $graphics.DrawString('Görsel açılamadı', $smallFont, [System.Drawing.Brushes]::Red, $x + 8, $y + 70)
    }
    $name = if ($names.ContainsKey($file.BaseName)) { $names[$file.BaseName] } else { $file.BaseName }
    $graphics.DrawString($name, $font, $labelBrush, $x + 6, $y + $imageHeight)
    $graphics.DrawString($file.BaseName, $smallFont, $mutedBrush, $x + 6, $y + $imageHeight + 24)
    $graphics.DrawRectangle([System.Drawing.Pens]::LightGray, $x, $y, $cellWidth - 1, $cellHeight - 1)
  }

  $destination = Join-Path $outputDir ('sheet-{0:D2}.jpg' -f $sheetIndex)
  $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Jpeg)
  $graphics.Dispose()
  $bitmap.Dispose()
  Write-Output $destination
}

$font.Dispose()
$smallFont.Dispose()
