@echo off
setlocal EnableExtensions
rem ==========================================================================
rem  Gera dist\Consultas\Consultas.exe (PyInstaller) e o instalador
rem  installer\output\ConsultasSetup.exe (Inno Setup, se o ISCC estiver instalado).
rem  Sem Inno Setup: gera installer\output\Consultas-portable.zip + install_local.ps1.
rem ==========================================================================
cd /d "%~dp0"

set "PY=python"
where python >nul 2>nul || (echo [ERRO] Python nao encontrado no PATH.& exit /b 1)

echo [1/3] Instalando dependencias de build...
%PY% -m pip install -r requirements-build.txt || exit /b 1

echo [2/3] PyInstaller...
rem limpa dist/build com retentativas (antivirus/indexador podem segurar arquivos por instantes)
powershell -NoProfile -Command "for($i=0;$i -lt 6;$i++){ Remove-Item -Recurse -Force dist,build -ErrorAction SilentlyContinue; if(-not((Test-Path dist) -or (Test-Path build))){break}; Start-Sleep 3 }"
%PY% -m PyInstaller --noconfirm --clean --distpath dist --workpath build Consultas.spec || exit /b 1
if not exist "dist\Consultas\Consultas.exe" (echo [ERRO] dist\Consultas\Consultas.exe nao foi gerado.& exit /b 1)
copy /y "installer\install_local.ps1" "dist\Consultas\install_local.ps1" >nul

echo [3/3] Instalador...
set "ISCC="
where iscc >nul 2>nul && set "ISCC=iscc"
if not defined ISCC if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"

if not exist "installer\output" mkdir "installer\output"
if defined ISCC (
    "%ISCC%" "installer\Consultas.iss" || exit /b 1
    echo.
    echo Instalador: %CD%\installer\output\ConsultasSetup.exe
) else (
    echo Inno Setup nao encontrado - gerando pacote portatil.
    powershell -NoProfile -Command "Compress-Archive -Path 'dist\Consultas\*' -DestinationPath 'installer\output\Consultas-portable.zip' -Force" || exit /b 1
    echo Pacote: %CD%\installer\output\Consultas-portable.zip  ^(extraia e execute install_local.ps1^)
)
echo Executavel: %CD%\dist\Consultas\Consultas.exe
endlocal
