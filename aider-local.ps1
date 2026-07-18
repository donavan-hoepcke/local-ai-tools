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

if ($Reasoning) {
    & aider --model ollama/qwen2.5:14b --set-env OLLAMA_HOST=$ollamaBase $repo
}
else {
    & aider --model "ollama/$Model" --set-env OLLAMA_HOST=$ollamaBase $repo
}
