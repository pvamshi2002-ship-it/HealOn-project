$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot 'backend'
$venvPython = Join-Path $repoRoot 'venv\Scripts\python.exe'

if (-not (Test-Path $venvPython)) {
    $venvPython = Join-Path $backendDir '.venv\Scripts\python.exe'
}

if (-not (Test-Path $venvPython)) {
    Write-Error "Python venv not found. Run: cd backend; python -m venv ..\venv; ..\venv\Scripts\pip install -r requirements.txt"
}

$envFile = Join-Path $repoRoot '.env'
$envExample = Join-Path $repoRoot '.env.example'
if (-not (Test-Path $envFile) -and (Test-Path $envExample)) {
    Copy-Item $envExample $envFile
    Write-Host "Created .env from .env.example"
}

    Push-Location $backendDir
try {
    if (-not (Test-Path (Join-Path $repoRoot '.env')) -and (Test-Path $envExample)) {
        Copy-Item $envExample (Join-Path $repoRoot '.env')
        Write-Host "Created .env from .env.example - update Gmail App Password before using OTP email."
    }
    & $venvPython manage.py migrate
    & $venvPython manage.py seed_demo_users
    Write-Host ""
    Write-Host "Backend running at http://127.0.0.1:8000"
    Write-Host "API: http://127.0.0.1:8000/api/"
    Write-Host "Press Ctrl+C to stop."
    Write-Host ""
    & $venvPython manage.py runserver 127.0.0.1:8000
}
finally {
    Pop-Location
}
