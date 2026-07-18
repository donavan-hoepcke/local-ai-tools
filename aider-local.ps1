param(
    [string]$Model,
    [string]$RepoPath = '.',
    [switch]$Reasoning,
    [switch]$GeneralChat,
    [switch]$CurrentRepo,
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'config.json')
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = & (Join-Path $repoRoot 'config-loader.ps1') -ConfigPath $ConfigPath
if (-not $Model) {
    if ($GeneralChat) { $Model = $config.DefaultChatModel } else { $Model = $config.DefaultCodingModel }
}

$missing = @()
if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) { $missing += 'ollama' }
if (-not (Get-Command aider -ErrorAction SilentlyContinue)) { $missing += 'aider' }

if ($missing.Count -gt 0) {
    Write-Host 'Missing required tools:' -ForegroundColor Yellow
    $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
    Write-Host ''
    Write-Host 'Please run the setup script from the repo root:' -ForegroundColor Cyan
    Write-Host '  .\setup-local-ai-cli.ps1' -ForegroundColor Cyan
    exit 1
}

$repo = if ($CurrentRepo -or $RepoPath -eq '.') {
    if (Test-Path '.git') {
        (Get-Location).Path
    }
    else {
        if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } else { (Resolve-Path $RepoPath).Path }
    }
}
else {
    if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } else { (Resolve-Path $RepoPath).Path }
}

if ($GeneralChat) {
    $Model = 'qwen2.5:7b'
}

$ollamaBase = $config.OllamaBaseUrl

try {
    $response = Invoke-WebRequest -Uri "$ollamaBase/api/tags" -Method Get -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -ne 200) {
        throw "Ollama responded with status $($response.StatusCode)"
    }
}
catch {
    Write-Host 'Ollama does not appear to be running locally.' -ForegroundColor Yellow
    Write-Host 'Try starting it with:' -ForegroundColor Yellow
    Write-Host '  ollama serve' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'If you installed Ollama recently, you may need to open a new terminal first.' -ForegroundColor Yellow
    exit 1
}

$aiderArgs = @(
    '--model', "ollama/$Model",
    '--set-env', "OLLAMA_HOST=$ollamaBase",
    '--no-show-model-warnings',
    '--yes-always',
    '--no-gitignore',
    '--no-auto-commits',
    '--no-dirty-commits',
    '--no-browser'
)

if ($Reasoning) {
    $aiderArgs[1] = "ollama/$($config.DefaultReasoningModel)"
}

& aider @aiderArgs $repo
