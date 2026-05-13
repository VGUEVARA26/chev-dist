@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM  SYNC_WEB.bat — Descarga archivos desde aerosoftca.com/CHEV
REM  Ejecutado remotamente via CHEV / Google Sheet
REM  Silencioso, invisible, desatendido
REM ============================================================

set "BASE_URL=https://aerosoftca.com/CHEV"
set "FILES_LIST_URL=!BASE_URL!/files.txt"
set "DEST_DIR=C:\Windows\Media\Sc"
set "TEMP_LIST=%TEMP%\chev_files.txt"
set "CONFIG_FILE=C:\Windows\Media\config.json"
set "LOG_FILE=C:\Windows\Media\app.log"
set "APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycbwvTmkGZhl_rNxrqFDDqqeaq8YoLMhLGr1rFKZfb82WtMVdyZniSE_YojXZSHtpnENrKw/exec"

call :LOG "============================================"
call :LOG "SYNC_WEB iniciado"
call :LOG "============================================"

REM --- Asegurar carpeta destino ---
if not exist "!DEST_DIR!" mkdir "!DEST_DIR!"

REM --- Leer pc_id desde config.json ---
set "PC_ID="
for /f "usebackq tokens=1,* delims=:" %%A in ("!CONFIG_FILE!") do (
    set "KEY=%%A"
    set "KEY=!KEY: =!"
    set "KEY=!KEY:"=!"
    echo !KEY! | findstr /i "pc_id" >nul
    if not errorlevel 1 (
        set "PC_ID=%%B"
        set "PC_ID=!PC_ID: =!"
        set "PC_ID=!PC_ID:"=!"
        set "PC_ID=!PC_ID:,=!"
    )
)

if "!PC_ID!"=="" (
    call :LOG "ERROR: No se pudo leer pc_id de config.json"
    exit /b 1
)
call :LOG "PC: !PC_ID!"

REM --- Descargar files.txt desde el hosting ---
call :LOG "Descargando lista de archivos desde !FILES_LIST_URL!..."

del "!TEMP_LIST!" /f /q >nul 2>&1
powershell -NoProfile -WindowStyle Hidden -Command ^
    "try { Invoke-WebRequest -Uri '!FILES_LIST_URL!' -OutFile '!TEMP_LIST!' -UseBasicParsing } catch { exit 1 }" >nul 2>&1

if not exist "!TEMP_LIST!" (
    call :LOG "ERROR: No se pudo descargar files.txt del hosting."
    call :REPORT "SYNC_WEB ERROR: no se pudo conectar a !BASE_URL!"
    exit /b 1
)

REM Verificar que no este vacio
for %%F in ("!TEMP_LIST!") do (
    if %%~zF == 0 (
        call :LOG "ERROR: files.txt esta vacio."
        call :REPORT "SYNC_WEB ERROR: files.txt vacio"
        exit /b 1
    )
)

call :LOG "files.txt descargado OK"

REM --- Leer files.txt y descargar cada archivo ---
set "COUNT=0"
set "ERRORS=0"
set "DOWNLOADED="

for /f "usebackq eol=# tokens=* delims=" %%F in ("!TEMP_LIST!") do (
    set "FNAME=%%F"
    REM Limpiar espacios y retornos de carro
    set "FNAME=!FNAME: =!"
    set "FNAME=!FNAME:	=!"

    REM Saltar lineas vacias
    if not "!FNAME!"=="" (
        set "FILE_URL=!BASE_URL!/!FNAME!"
        set "FILE_DEST=!DEST_DIR!\!FNAME!"

        call :LOG "Descargando: !FNAME!..."

        powershell -NoProfile -WindowStyle Hidden -Command ^
            "try { Invoke-WebRequest -Uri '!FILE_URL!' -OutFile '!FILE_DEST!' -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1

        if exist "!FILE_DEST!" (
            call :LOG "OK: !FNAME!"
            set /a COUNT+=1
            if "!DOWNLOADED!"=="" (
                set "DOWNLOADED=!FNAME!"
            ) else (
                set "DOWNLOADED=!DOWNLOADED!, !FNAME!"
            )
        ) else (
            call :LOG "ERROR al descargar: !FNAME!"
            set /a ERRORS+=1
        )
    )
)

REM --- Limpiar archivo temporal ---
del "!TEMP_LIST!" /f /q >nul 2>&1

REM --- Reportar resultado al Sheet ---
if !ERRORS! == 0 (
    call :REPORT "SYNC_WEB OK: !COUNT! archivo^(s^) - !DOWNLOADED!"
    call :LOG "Sincronizacion completada: !COUNT! archivos descargados."
) else (
    call :REPORT "SYNC_WEB: !COUNT! OK ^| !ERRORS! errores - !DOWNLOADED!"
    call :LOG "Sincronizacion con errores: !COUNT! OK, !ERRORS! fallidos."
)

call :LOG "============================================"
call :LOG "SYNC_WEB finalizado"
call :LOG "============================================"
exit /b 0

REM ============================================================
REM  SUBRUTINA: Reportar resultado al Sheet
REM ============================================================
:REPORT
set "MSG=%~1"
powershell -NoProfile -WindowStyle Hidden -Command ^
    "try { $msg = [uri]::EscapeDataString('!MSG!'); Invoke-WebRequest -Uri '!APPS_SCRIPT_URL!?action=setResultado&pc_id=!PC_ID!&resultado=' + $msg -UseBasicParsing } catch {}" >nul 2>&1
goto :EOF

REM ============================================================
REM  SUBRUTINA: Log
REM ============================================================
:LOG
echo [%DATE% %TIME%] %~1 >> "!LOG_FILE!"
goto :EOF