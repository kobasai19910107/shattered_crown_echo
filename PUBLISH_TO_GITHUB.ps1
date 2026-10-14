$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$repo = 'https://github.com/kobasai19910107/shattered_crown_echo.git'

function Stop-WithError([string]$message) {
    Write-Host ('ERROR: ' + $message) -ForegroundColor Red
    exit 1
}

Write-Host 'Checking the Web project before GitHub upload...' -ForegroundColor Cyan
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Stop-WithError 'Git for Windows is not installed or is not on PATH.'
}
if (-not (Test-Path -LiteralPath 'project.godot')) {
    Stop-WithError 'project.godot not found. Run this script in the extracted project folder.'
}
if (-not (Test-Path -LiteralPath '.gitignore')) {
    Stop-WithError '.gitignore not found. Aborting to avoid uploading temporary/private files.'
}

# Scan potentially public text files for Windows user paths or credential values.
$patterns = @(
    '(?i)[a-z]:[\/](?:Users|Documents and Settings)[\/][^\/
\s"'']+',
    '(?i)-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----',
    '(?i)(?:client_secret|encryption_key|password|access_token|api_key)\s*[:=]\s*["''](?!["''])[^"'']+["'']'
)
$extensions = @('.gd', '.json', '.cfg', '.md', '.yml', '.yaml', '.godot', '.tscn', '.tres', '.ps1', '.cmd', '.txt', '.ini', '.js', '.html', '.xml', '.gdshader', '.csv', '.tsv')
$bad = @()
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File | Where-Object {
    $_.FullName -notmatch '[\/](?:\.git|\.godot)[\/]' -and
    (($extensions -contains $_.Extension.ToLowerInvariant()) -or $_.Name -eq '.gitignore')
}
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $bad += $file.FullName
            break
        }
    }
}
if ($bad.Count -gt 0) {
    Write-Host 'Potential private information detected. Nothing was uploaded:' -ForegroundColor Red
    $bad | Sort-Object -Unique | ForEach-Object { Write-Host $_ }
    exit 1
}
Write-Host 'Privacy scan passed.' -ForegroundColor Green

if (-not (Test-Path -LiteralPath '.git')) {
    & git init -b main
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'git init failed.' }
}
& git config --local user.name 'kobasai19910107'
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Git user.name setup failed.' }
& git config --local user.email '339870397+kobasai19910107@users.noreply.github.com'
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Git user.email setup failed.' }

$remoteNames = @(& git remote)
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Could not list remotes.' }
if ($remoteNames -contains 'origin') {
    $found = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Could not read origin URL.' }
    if ($found -ne $repo) { Stop-WithError ('Origin points somewhere else: ' + $found) }
} else {
    & git remote add origin $repo
    if ($LASTEXITCODE -ne 0) { Stop-WithError 'Could not add origin.' }
}

Write-Host 'Checking that the remote main branch is empty...'
$remoteMain = @(& git ls-remote --heads origin main)
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Cannot connect to GitHub. Check login and connection.' }
if ($remoteMain.Count -gt 0) {
    Stop-WithError 'The GitHub main branch is not empty. No files uploaded. Stop to prevent overwriting.'
}

& git add --all
if ($LASTEXITCODE -ne 0) { Stop-WithError 'git add failed.' }
$staged = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Could not inspect staged files.' }
if ($staged.Count -eq 0) { Stop-WithError 'There are no files to upload.' }
Write-Host ('Files staged: ' + $staged.Count)

& git commit -m 'Add privacy-checked shattered_crown_echo Web migration candidate'
if ($LASTEXITCODE -ne 0) { Stop-WithError 'git commit failed.' }
& git branch -M main
if ($LASTEXITCODE -ne 0) { Stop-WithError 'Could not set main branch.' }
& git push -u origin main
if ($LASTEXITCODE -ne 0) { Stop-WithError 'GitHub push failed.' }
Write-Host 'SUCCESS: GitHub upload completed.' -ForegroundColor Green
