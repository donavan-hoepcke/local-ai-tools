param(
    [string]$Model,
    [string]$Prompt = 'Hello. Help me summarize my current work and suggest the next best step.',
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'config.json')
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$config = & (Join-Path $repoRoot 'config-loader.ps1') -ConfigPath $ConfigPath
if (-not $Model) { $Model = $config.DefaultChatModel }

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Host 'Missing required tool: ollama' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Please run the setup script from the repo root:' -ForegroundColor Cyan
    Write-Host '  .\setup-local-ai-cli.ps1' -ForegroundColor Cyan
    exit 1
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
    exit 1
}

Write-Host "Using model: $Model" -ForegroundColor Cyan
Write-Host 'Enter your prompt. Type exit to quit.' -ForegroundColor Green

while ($true) {
    $userInput = Read-Host 'You'
    if ($userInput -eq 'exit') { break }
    if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

    $payload = @{ model = $Model; prompt = $userInput; stream = $false } | ConvertTo-Json -Depth 5
    try {
        $result = Invoke-RestMethod -Uri "$ollamaBase/api/generate" -Method Post -ContentType 'application/json' -Body $payload
        Write-Host "Assistant:" -ForegroundColor Magenta
        Write-Host $result.response
        Write-Host ''
    }
    catch {
        Write-Host 'Chat request failed.' -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }
}
