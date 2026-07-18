param(
    [string]$RepoPath = '.',
    [string]$Model = 'qwen2.5-coder:7b',
    [switch]$Reasoning,
    [switch]$GeneralChat
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } else { (Resolve-Path $RepoPath).Path }

$ollamaExe = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollamaExe) {
    Write-Host 'Ollama was not found on PATH.' -ForegroundColor Yellow
    exit 1
}

Write-Host 'Starting Ollama...' -ForegroundColor Cyan
Start-Process -FilePath $ollamaExe.Source -ArgumentList 'serve' -WindowStyle Hidden -PassThru | Out-Null
Start-Sleep -Seconds 3

$launcher = Join-Path $scriptDir 'aider-local.ps1'
$arguments = @('-File', $launcher, '-RepoPath', $repo)
if ($Reasoning) {
    $arguments += '-Reasoning'
}
if ($GeneralChat) {
    $arguments += '-GeneralChat'
}
if ($Model -and $Model -ne 'qwen2.5-coder:7b') {
    $arguments += '-Model'
    $arguments += $Model
}

Write-Host 'Launching Aider...' -ForegroundColor Cyan
Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $repo
