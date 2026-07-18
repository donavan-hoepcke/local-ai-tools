param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'config.json')
)

if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

return [pscustomobject]@{
    DefaultCodingModel = $config.defaultCodingModel
    DefaultChatModel = $config.defaultChatModel
    DefaultReasoningModel = $config.defaultReasoningModel
    EmbeddingModel = $config.embeddingModel
    OllamaBaseUrl = $config.ollamaBaseUrl
    DefaultRepo = $config.defaultRepo
    UseReasoningByDefault = [bool]$config.useReasoningByDefault
}
