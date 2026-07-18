param(
    [string]$Model,
    [string]$RepoPath = '.',
    [switch]$Reasoning,
    [switch]$GeneralChat,
    [switch]$CurrentRepo,
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'config.json')
)

$config = & (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'config-loader.ps1') -ConfigPath $ConfigPath
if (-not $Model) {
    if ($GeneralChat) { $Model = $config.DefaultChatModel } else { $Model = $config.DefaultCodingModel }
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
