Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$outDir = "$repoRoot\build\out"
$zipPath = "$outDir\MountTracker.zip"
$extPath = "$env:APPDATA\SmiteWorks\Fantasy Grounds\extensions\MountTracker.ext"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

$filesToInclude = @(
    "extension.xml",
    "Open Gaming License v1.0a.txt",
    "campaign\ct_client.xml",
    "campaign\ct_host.xml",
    "graphics\icons\letter-c-icon-18-32.png",
    "graphics\icons\letter-d-icon-18-32.png",
    "graphics\icons\letter-u-icon-18-32.png",
    "graphics\icons\mount_icon.png",
    "graphics\icons\white_mount_icon.png",
    "scripts\ct_client_ct_entry.lua",
    "scripts\ct_host_ct_entry.lua",
    "scripts\mounttracker.lua"
)

foreach ($relPath in $filesToInclude) {
    $fullPath = Join-Path $repoRoot $relPath
    if (Test-Path $fullPath) {
        $entryName = $relPath.Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $fullPath, $entryName)
        Write-Host "Added: $entryName"
    } else {
        Write-Warning "File not found: $fullPath"
    }
}

$zip.Dispose()

Copy-Item $zipPath -Destination $extPath -Force
Write-Host "Successfully packaged and copied to: $extPath"

# Verify zip entry paths
$readZip = [System.IO.Compression.ZipFile]::OpenRead($extPath)
Write-Host "`nContents of deployed ${extPath}:"
foreach ($entry in $readZip.Entries) {
    Write-Host "  $($entry.FullName) ($($entry.Length) bytes)"
}
$readZip.Dispose()
