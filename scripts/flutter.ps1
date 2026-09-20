$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $projectRoot '.toolchains'
$env:JAVA_HOME = Join-Path $toolRoot 'jdk-17.0.20.1+1'
$env:ANDROID_HOME = Join-Path $toolRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PUB_CACHE = Join-Path $toolRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $toolRoot 'gradle-cache'

$flutter = Join-Path $toolRoot 'flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    throw '项目内 Flutter 工具链尚未安装。'
}

Push-Location (Join-Path $projectRoot 'mobile')
try {
    & $flutter @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
