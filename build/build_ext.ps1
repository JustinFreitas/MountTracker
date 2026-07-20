$sourceDir = "C:\code\MountTracker"
$stagingDir = "$sourceDir\build\out\staging"
$outputZip = "$sourceDir\build\out\MountTracker.zip"
$fguExtensionsDir = "C:\Users\justi\AppData\Roaming\SmiteWorks\Fantasy Grounds\extensions"
$destinationExt = "$fguExtensionsDir\MountTracker.ext"

# Clean up any existing staging/outputs
if (Test-Path $stagingDir) { Remove-Item -Recurse -Force $stagingDir }
if (Test-Path $outputZip) { Remove-Item -Force $outputZip }
$null = New-Item -ItemType Directory -Path $stagingDir -ErrorAction SilentlyContinue

# Copy files preserving FGU extension structure
Copy-Item "$sourceDir\extension.xml" -Destination "$stagingDir\"
Copy-Item "$sourceDir\Open Gaming License v1.0a.txt" -Destination "$stagingDir\"

$null = New-Item -ItemType Directory -Path "$stagingDir\campaign" -ErrorAction SilentlyContinue
Copy-Item "$sourceDir\campaign\ct_client.xml" -Destination "$stagingDir\campaign\"
Copy-Item "$sourceDir\campaign\ct_host.xml" -Destination "$stagingDir\campaign\"

$null = New-Item -ItemType Directory -Path "$stagingDir\graphics\icons" -ErrorAction SilentlyContinue
Copy-Item "$sourceDir\graphics\icons\*" -Destination "$stagingDir\graphics\icons\"

$null = New-Item -ItemType Directory -Path "$stagingDir\scripts" -ErrorAction SilentlyContinue
Copy-Item "$sourceDir\scripts\*" -Destination "$stagingDir\scripts\"

# Compress staging directory contents to zip
Write-Host "Compressing extension files..."
Compress-Archive -Path "$stagingDir\*" -DestinationPath $outputZip -Force

# Rename MountTracker.zip to MountTracker.ext and move to FGU extensions directory
if (Test-Path $destinationExt) {
    Write-Host "Removing existing MountTracker.ext from FGU extensions..."
    Remove-Item -Force $destinationExt
}
Write-Host "Installing new MountTracker.ext to FGU..."
Move-Item $outputZip $destinationExt -Force

# Clean up staging
Remove-Item -Recurse -Force $stagingDir

Write-Host "Build and Install completed successfully!"
