# Runs the GUT suite headless. Usage: powershell -File tests/run_tests.ps1 [-Godot <path>]
# Fails if any test fails OR any script fails to parse (GUT alone skips broken
# test scripts and still reports success).
param([string]$Godot = "$PSScriptRoot\..\..\Godot_v4.7.2-stable_win64.exe")
$project = Resolve-Path "$PSScriptRoot\.."
& $Godot --headless --path $project --import | Out-Null
$output = & $Godot --headless --path $project -s addons/gut/gut_cmdln.gd 2>&1 | ForEach-Object { "$_" }
$output
$gutExit = $LASTEXITCODE
if ($output -match 'SCRIPT ERROR|Parse Error|Failed to load script') {
    Write-Host "Script errors found - failing the run." -ForegroundColor Red
    exit 1
}
exit $gutExit
