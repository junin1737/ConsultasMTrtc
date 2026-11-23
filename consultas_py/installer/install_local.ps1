# Instalacao simples (sem Inno Setup): copia a pasta do app para %LOCALAPPDATA%\Programs\Consultas
# e cria atalhos no Menu Iniciar e na Area de Trabalho.
# Uso (na pasta extraida com Consultas.exe):  powershell -ExecutionPolicy Bypass -File install_local.ps1
param(
    [string]$Destino = (Join-Path $env:LOCALAPPDATA "Programs\Consultas"),
    [switch]$SemDesktop
)
$ErrorActionPreference = "Stop"
$src = $PSScriptRoot
if (-not (Test-Path (Join-Path $src "Consultas.exe"))) {
    # quando rodado de installer\ no repositorio, usa dist\Consultas
    $src = Join-Path (Split-Path $PSScriptRoot -Parent) "dist\Consultas"
}
if (-not (Test-Path (Join-Path $src "Consultas.exe"))) { throw "Consultas.exe nao encontrado em $src" }

Get-Process -Name Consultas -ErrorAction SilentlyContinue | Stop-Process -Force
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
Copy-Item -Path (Join-Path $src "*") -Destination $Destino -Recurse -Force

$exe = Join-Path $Destino "Consultas.exe"
$ws = New-Object -ComObject WScript.Shell
function Novo-Atalho($caminho) {
    $s = $ws.CreateShortcut($caminho)
    $s.TargetPath = $exe
    $s.WorkingDirectory = $Destino
    $s.IconLocation = $exe
    $s.Save()
}
$menu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Consultas.lnk"
Novo-Atalho $menu
if (-not $SemDesktop) { Novo-Atalho (Join-Path ([Environment]::GetFolderPath("Desktop")) "Consultas.lnk") }
Write-Host "Instalado em $Destino"
