$root = $args[0]
[bool] $doClear = [bool]::Parse($args[1])

Set-Location -Path (Join-Path -Path $root -ChildPath '_Docs-Src')
if ($doClear) {
   Get-ChildItem -Path '../Docs' | Remove-Item -Recurse
}

$targets = Get-ChildItem -Recurse -Path '*' -Filter '*.adoc' -Exclude '_*.adoc' -File

foreach ($target in $targets) {
    $target_path = (Resolve-Path -Path $target.FullName -Relative).Replace('\', '/')
    $destination_path = (Join-Path -Path '../Docs' -ChildPath $target_path).Replace('\', '/')
    wsl asciidoctor-reducer $target_path -o $destination_path
}