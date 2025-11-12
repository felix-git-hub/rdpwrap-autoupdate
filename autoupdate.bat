@echo off
:: autoupdate.bat - RDP Wrapper ini auto-update script (UTF-8 friendly)
chcp 65001 >nul
setlocal EnableExtensions
setlocal EnableDelayedExpansion

:: -------------------------
:: Variables and default configuration (can be overridden by autoupdate.conf)
:: -------------------------
set "PROXYSERVER="
set "RDPWRAP_URL_0=https://raw.githubusercontent.com/asmtron/rdpwrap/master/res/rdpwrap.ini"
set "RDPWRAP_URL_1=https://raw.githubusercontent.com/sebaxakerhtc/rdpwrap.ini/master/rdpwrap.ini"
set "RDPWRAP_URL_2=https://raw.githubusercontent.com/affinityv/INI-RDPWRAP/master/rdpwrap.ini"
set "RDPWRAP_URL_3=https://raw.githubusercontent.com/DrDrrae/rdpwrap/master/res/rdpwrap.ini"
set "RDPWRAP_URL_4=https://raw.githubusercontent.com/saurav-biswas/rdpwrap-1/master/res/rdpwrap.ini"

set "SCRIPT_DIR=%~dp0"
set "autoupdate_bat=%SCRIPT_DIR%autoupdate.bat"
set "autoupdate_log=%SCRIPT_DIR%autoupdate.log"
set "RDPWInst_exe=%SCRIPT_DIR%RDPWInst.exe"
set "rdpwrap_dll=%SCRIPT_DIR%rdpwrap.dll"
set "rdpwrap_ini=C:\Program Files\RDP Wrapper\rdpwrap.ini"
set "rdpwrap_new_ini=%SCRIPT_DIR%rdpwrap_new.ini"
set "rdpwrap_ini_check=%rdpwrap_new_ini%"
set "rdpfolder=C:\Program Files\RDP Wrapper\"

set "retry_network_check=0"

:: -------------------------
:: Admin check and elevation
:: -------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Script is not running as administrator.
    echo [*] Attempting to restart with admin privileges. Please confirm UAC prompt.
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b 0
)

:: -------------------------
:: Load external configuration autoupdate.conf (optional)
:: -------------------------
set "CONF_FILE=%SCRIPT_DIR%autoupdate.conf"
if exist "%CONF_FILE%" (
    for /f "usebackq tokens=1* delims=" %%A in ("%CONF_FILE%") do (
        set "line=%%A"
        if not "!line!"=="" (
            set "first=!line:~0,1!"
            if not "!first!"=="#" (
                set "line2=!line:???=!"
                for /f "tokens=1* delims==" %%K in ("!line2!") do (
                    set "k=%%K"
                    set "v=%%L"
                    for /f "tokens=* delims= " %%x in ("!k!") do set "k=%%x"
                    for /f "tokens=* delims= " %%y in ("!v!") do set "v=%%y"
                    if defined k (
                        set "!k!=!v!"
                    )
                )
            )
        )
    )
    echo [*] Loaded configuration file "%CONF_FILE%".
)

:: -------------------------
:: Build URL list
:: -------------------------
set i=0
:collect_urls
call set "temp=%%RDPWRAP_URL_%i%%%"
if defined temp (
    set "rdpwrap_ini_update_github[%i%]=%temp%"
    set /a i+=1
    goto collect_urls
)
set /a length=i-1
echo [*] Found %i% URLs (index 0 to %length%).

:: -------------------------
:: Parameter handling - support -log, -taskadd, -taskremove
:: -------------------------
if /i "%~1"=="-log" (
    echo %autoupdate_bat% output from %date% at %time% > "%autoupdate_log%"
    call "%autoupdate_bat%" >> "%autoupdate_log%"
    goto finish
)
if /i not "%~1"=="" (
    echo [x] Unknown parameter: "%~1"
    echo [*] Supported parameters:
    echo     -log         = Write output to autoupdate.log
    echo     -taskadd     = Add startup task
    echo     -taskremove  = Remove startup task
    goto finish
)

:: -------------------------
:: Get termsrv.dll version
:: -------------------------
for /f "usebackq delims=" %%a in (
`powershell -NoProfile -Command "Split-Path -Leaf (Get-Item %windir%\System32\termsrv.dll).VersionInfo.ProductVersionRaw"` 
) do set "termsrv_dll_ver=%%a"

if not defined termsrv_dll_ver (
    echo [x] Failed to get termsrv.dll version. Exiting.
    goto finish
)

echo [+] Detected termsrv.dll version: %termsrv_dll_ver%.

:: -------------------------
:: Check local rdpwrap.ini for this version
:: -------------------------
if exist "%rdpwrap_ini%" (
    echo [*] Checking "%rdpwrap_ini%" for entry [%termsrv_dll_ver%].
    findstr /c:"[%termsrv_dll_ver%]" "%rdpwrap_ini%" >nul
    if not errorlevel 1 (
        echo [+] Entry [%termsrv_dll_ver%] found. No update needed.
        goto finish
    ) else (
        echo [-] Entry [%termsrv_dll_ver%] not found.
    )
) else (
    echo [-] File "%rdpwrap_ini%" not found. Will try to download from candidate URLs.
)

:: -------------------------
:: Try each URL until matching version is found
:: -------------------------
for /l %%i in (0,1,%length%) do (
    set "rdpwrap_ini_url=!rdpwrap_ini_update_github[%%i]!"
    call :check_update
)

goto finish

:: -------------------------
:check_update
if exist "%rdpwrap_ini_check%" (
    echo [*] Checking "%rdpwrap_ini_check%" for entry [%termsrv_dll_ver%].
    findstr /c:"[%termsrv_dll_ver%]" "%rdpwrap_ini_check%" >nul
    if not errorlevel 1 (
        echo [+] Entry [%termsrv_dll_ver%] found in "%rdpwrap_ini_check%".
        echo [*] Using this file to replace rdpwrap.ini.
        call :copynew
        goto :eof
    ) else (
        echo [-] Entry [%termsrv_dll_ver%] not found in "%rdpwrap_ini_check%".
        call :update
        goto :eof
    )
) else (
    echo [*] Creating "%rdpwrap_new_ini%" and trying to download.
    copy /y NUL "%rdpwrap_new_ini%" >NUL
    set "rdpwrap_ini_check=%rdpwrap_new_ini%"
    call :update
    goto :eof
)
goto :eof

:: -------------------------
:update
echo [*] Checking network connectivity.
ping -n 1 www.baidu.com >nul
if errorlevel 1 (
    goto waitnetwork
) else (
    goto download
)

:waitnetwork
echo [*] Waiting for network to be available...
ping 127.0.0.1 -n 11 >nul
set /a retry_network_check=retry_network_check+1
if %retry_network_check% LSS 30 goto netcheck
echo [x] Network unavailable, skipping URL: %rdpwrap_ini_url%
goto :eof

:download
echo [*] Downloading: %rdpwrap_ini_url%
if not "%PROXYSERVER%"=="" (
    curl --fail -s -x %PROXYSERVER% -L "%rdpwrap_ini_url%" -o "%rdpwrap_new_ini%"
) else (
    curl --fail -s -L "%rdpwrap_ini_url%" -o "%rdpwrap_new_ini%"
)

if %errorlevel%==0 (
    echo [+] Download succeeded: "%rdpwrap_new_ini%".
    set "rdpwrap_ini_check=%rdpwrap_new_ini%"
) else (
    echo [-] Download failed: %rdpwrap_ini_url%.
    echo [*] Check network, firewall, or proxy settings.
)
goto :eof

:: -------------------------
:copynew
echo [*] Replacing rdpwrap.ini and restarting TermService.
if exist "%rdpwrap_new_ini%" (
    echo [*] Stopping TermService...
    powershell -NoProfile -Command "Try { Stop-Service -Name TermService -Force -ErrorAction Stop } Catch { Exit 0 }"

    echo [*] Copying temporary file to rdpwrap.ini...
    xcopy /y "%rdpwrap_new_ini%" "%rdpwrap_ini%" >nul
    echo [*] Starting TermService...
    powershell -NoProfile -Command "Try { Start-Service -Name TermService -ErrorAction Stop } Catch { Exit 0 }"
) else (
    echo [x] Error: temporary file "%rdpwrap_new_ini%" not found.
)
goto :eof

:: -------------------------
:finish
echo [*] Operation completed. Cleaning up...
call :cleanup

if "%SESSIONNAME%"=="Console" (
    pause
) else (
    echo [*] Non-interactive session, exiting in 10 seconds...
    timeout /t 10 >nul
)

endlocal
exit /b 0

:: -------------------------
:cleanup
if exist "%rdpwrap_new_ini%" (
    echo [*] Deleting temporary file "%rdpwrap_new_ini%"...
    del /f /q "%rdpwrap_new_ini%" >nul 2>&1
    if exist "%rdpwrap_new_ini%" (
        echo [!] Failed to delete "%rdpwrap_new_ini%", please remove manually.
    ) else (
        echo [+] Temporary file deleted.
    )
)
goto :eof
