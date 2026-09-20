$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.toolchains'
$env:PUB_CACHE = Join-Path $toolRoot 'pub-cache'
$dart = Join-Path $toolRoot 'flutter\bin\dart.bat'

if (-not (Test-Path -LiteralPath $dart)) {
    throw '项目内 Dart 工具链尚未安装。'
}

Push-Location (Join-Path $projectRoot 'mobile')
try {
    & $dart @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
