param(
    [string]$Model = 'qwen2.5-coder:7b',
    [string]$RepoPath = '.',
    [switch]$Reasoning,
    [switch]$GeneralChat,
    [switch]$CurrentRepo
)

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

$ollamaBase = 'http://127.0.0.1:11434'

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
    $aiderArgs[1] = 'ollama/qwen2.5:14b'
}

& aider @aiderArgs $repo
