param(
    [switch]$SkipGit,
    [switch]$SkipVSCode,
    [switch]$SkipModels,
    [switch]$IncludeReasoningModel,
    [switch]$IncludeEmbeddings,
    [switch]$UseCpuOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-PathContains {
    param([string]$PathToAdd)
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $PathToAdd })) {
        $env:Path = "$env:Path;$PathToAdd"
    }
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName
    )

    Write-Step "Installing $DisplayName"
    try {
        & winget install --id $PackageId -e --silent --accept-source-agreements --accept-package-agreements | Out-Null
        Write-Success "$DisplayName installed or available"
    }
    catch {
        Write-Warn "Could not install $DisplayName automatically. Please install it manually if needed."
    }
}

$setupRoot = Join-Path $HOME 'local-ai-cli'
New-Item -ItemType Directory -Path $setupRoot -Force | Out-Null
$logPath = Join-Path $setupRoot 'setup.log'
Set-Content -Path $logPath -Value ("CLI-first local AI setup started at " + (Get-Date -Format o)) -Force

function Add-Log {
    param([string]$Message)
    Add-Content -Path $logPath -Value ((Get-Date -Format o) + " $Message")
}

Add-Log 'Starting CLI-first local AI setup'

Write-Step 'Checking prerequisites'
$wingetAvailable = Test-Command winget
if (-not $wingetAvailable) {
    Write-Warn 'winget was not found. Some installs will need to be done manually.'
}
else {
    Write-Success 'winget is available'
}

if (-not $SkipGit) {
    Write-Step 'Installing Git'
    if ($wingetAvailable) {
        Install-WingetPackage -PackageId 'Git.Git' -DisplayName 'Git'
    }
}

if (-not (Test-Command git)) {
    Write-Warn 'Git is still not available. Please install it manually if needed.'
}
else {
    Write-Success 'Git is available'
}

Write-Step 'Installing Python 3'
if ($wingetAvailable) {
    Install-WingetPackage -PackageId 'Python.Python.3.12' -DisplayName 'Python 3'
}
else {
    Write-Warn 'Python may need to be installed manually.'
}

$pythonExe = $null
if (Test-Command py) {
    $pythonExe = 'py'
}
elseif (Test-Command python) {
    $pythonExe = 'python'
}

if ($pythonExe) {
    Write-Success 'Python launcher found'
}
else {
    Write-Warn 'Python was not found after install. Open a new terminal and re-run the script if needed.'
}

Write-Step 'Installing Ollama'
if ($wingetAvailable) {
    Install-WingetPackage -PackageId 'Ollama.Ollama' -DisplayName 'Ollama'
}
else {
    Write-Warn 'Install Ollama manually from https://ollama.com/download/windows'
}

if (Test-Command ollama) {
    Write-Success 'Ollama is available'
}
else {
    Write-Warn 'Ollama is not on PATH yet. Open a new terminal and re-run the script if needed.'
}

if (Test-Command ollama) {
    Write-Step 'Starting Ollama'
    try {
        $existing = Get-Process -Name 'ollama' -ErrorAction SilentlyContinue
        if (-not $existing) {
            Start-Process -FilePath 'ollama' -ArgumentList 'serve' -WindowStyle Hidden -PassThru | Out-Null
        }
        Start-Sleep -Seconds 5
        & ollama list | Out-Null
        Write-Success 'Ollama is responding'
    }
    catch {
        Write-Warn 'Ollama may need a moment to start. Try: ollama list'
    }
}

if (-not $SkipModels -and (Test-Command ollama)) {
    Write-Step 'Pulling local models'

    $models = @(
        'qwen2.5-coder:7b',
        'qwen2.5:7b',
        'nomic-embed-text'
    )

    if ($IncludeReasoningModel) {
        $models += 'qwen2.5:14b'
    }

    foreach ($model in $models) {
        Write-Host "Pulling $model" -ForegroundColor DarkCyan
        try {
            & ollama pull $model
            Add-Log "Pulled $model"
        }
        catch {
            Write-Warn "Failed to pull $model"
        }
    }
}

if ($pythonExe) {
    Write-Step 'Installing Aider'
    try {
        if ($pythonExe -eq 'py') {
            & py -3 -m pip install --user --upgrade pip setuptools wheel
            & py -3 -m pip install --user --upgrade --no-build-isolation aider-chat
        }
        else {
            & python -m pip install --user --upgrade pip setuptools wheel
            & python -m pip install --user --upgrade --no-build-isolation aider-chat
        }

        $scriptsPath = $null
        if ($pythonExe -eq 'py') {
            $scriptsPath = (& py -3 -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))")
        }
        else {
            $scriptsPath = (& python -c "import sysconfig; print(sysconfig.get_path('scripts', scheme='nt_user'))")
        }
        $scriptsPath = $scriptsPath.Trim()
        if ($scriptsPath) {
            Ensure-PathContains $scriptsPath
        }

        Write-Success 'Aider installed'
    }
    catch {
        Write-Warn 'Aider could not be installed automatically. You can try: pip install --user --upgrade pip setuptools wheel and then pip install --user --upgrade --no-build-isolation aider-chat'
    }
}

if (-not $SkipVSCode) {
    Write-Step 'Installing VS Code (optional but helpful for inspection)'
    if ($wingetAvailable) {
        Install-WingetPackage -PackageId 'Microsoft.VisualStudioCode' -DisplayName 'Visual Studio Code'
    }
}

$launchScript = Join-Path $setupRoot 'start-aider.ps1'
@"
param(
    [string]$Model = 'qwen2.5-coder:7b',
    [string]$RepoPath = '.',
    [switch]$Reasoning
)

$repoArg = if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } else { (Resolve-Path $RepoPath).Path }

if ($Reasoning) {
    & aider --model ollama/qwen2.5:14b --api-base http://127.0.0.1:11434 $repoArg
}
else {
    & aider --model ollama/$Model --api-base http://127.0.0.1:11434 $repoArg
}
"@ | Set-Content -Path $launchScript -Force

$binDir = Join-Path $HOME 'bin'
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
$binPathEntries = @(
    (Join-Path $binDir 'aider-local.cmd'),
    (Join-Path $binDir 'aider-local.ps1'),
    (Join-Path $binDir 'chat-local.cmd'),
    (Join-Path $binDir 'chat-local.ps1'),
    (Join-Path $binDir 'config-loader.ps1'),
    (Join-Path $binDir 'config.json'),
    (Join-Path $binDir 'setup-local-ai-cli.cmd'),
    (Join-Path $binDir 'setup-local-ai-cli.ps1')
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '.')).Path
foreach ($entry in $binPathEntries) {
    if (Test-Path $entry) {
        Remove-Item $entry -Force
    }
}

Copy-Item (Join-Path $repoRoot 'aider-local.ps1') -Destination (Join-Path $binDir 'aider-local.ps1') -Force
Copy-Item (Join-Path $repoRoot 'aider-local.cmd') -Destination (Join-Path $binDir 'aider-local.cmd') -Force
Copy-Item (Join-Path $repoRoot 'chat-local.ps1') -Destination (Join-Path $binDir 'chat-local.ps1') -Force
Copy-Item (Join-Path $repoRoot 'chat-local.cmd') -Destination (Join-Path $binDir 'chat-local.cmd') -Force
Copy-Item (Join-Path $repoRoot 'config-loader.ps1') -Destination (Join-Path $binDir 'config-loader.ps1') -Force
Copy-Item (Join-Path $repoRoot 'config.json') -Destination (Join-Path $binDir 'config.json') -Force
Copy-Item (Join-Path $repoRoot 'setup-local-ai-cli.ps1') -Destination (Join-Path $binDir 'setup-local-ai-cli.ps1') -Force
Copy-Item (Join-Path $repoRoot 'setup-local-ai-cli.cmd') -Destination (Join-Path $binDir 'setup-local-ai-cli.cmd') -Force

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not ($userPath -split ';' | Where-Object { $_ -eq $binDir })) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $binDir), 'User')
}

$summaryPath = Join-Path $setupRoot 'summary.txt'
@"
CLI-first local AI setup summary
================================
- Ollama endpoint: http://127.0.0.1:11434
- Coding model: qwen2.5-coder:7b
- General chat model: qwen2.5:7b
- Embedding model: nomic-embed-text
- Optional reasoning model: qwen2.5:14b

Launch Aider from any repo:
  powershell -ExecutionPolicy Bypass -File $launchScript

Or run manually:
  aider --model ollama/qwen2.5-coder:7b --api-base http://127.0.0.1:11434 .

Useful commands:
  ollama list
  ollama run qwen2.5-coder:7b
  ollama run qwen2.5:7b
"@ | Set-Content -Path $summaryPath -Force

Write-Step 'Setup complete'
Write-Host "Summary saved to $summaryPath" -ForegroundColor Green
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Green
Write-Host '  1. Open a new PowerShell window so PATH updates are picked up.'
Write-Host '  2. Run: ollama list'
Write-Host '  3. From a repo folder, run: aider --model ollama/qwen2.5-coder:7b --api-base http://127.0.0.1:11434 .'