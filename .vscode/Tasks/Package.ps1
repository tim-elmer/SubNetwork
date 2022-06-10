$root = $args[0]
$tempRoot = Join-Path -Path $root -ChildPath 'Temp'
$tempDir = Join-Path -Path $tempRoot -ChildPath 'SubNetwork'
$buildPath = Join-Path -Path $root -ChildPath 'Build'
if (-not (Test-Path -Path $tempRoot)) {
    New-Item -Path $tempRoot -ItemType 'Directory'
}
if (Test-Path $tempDir) {
   Remove-Item -Path (Join-Path -Path $tempDir -ChildPath '*') -Recurse
}
else {
    New-Item -Path $tempDir -ItemType 'Directory'
}

$targets = @(
    "$root/Docs",
    "$root/Modules",
    "$root/LICENSE.adoc",
    "$root/README.adoc",
    "$root/SubNetwork.psd1",
    "$root/SubNetwork.psm1"
)

Copy-Item -LiteralPath $targets -Destination $tempDir -Recurse

if (-not (Test-Path $buildPath)) {
    New-Item -Path $buildPath -ItemType 'Directory'
}
Compress-Archive -Path $tempDir -CompressionLevel Optimal -DestinationPath (
    Join-Path -Path $buildPath -ChildPath "SubNetwork-$((Get-Module -ListAvailable $root).Version.ToString()).zip"
)
Remove-Item -Path $tempRoot -Recurse