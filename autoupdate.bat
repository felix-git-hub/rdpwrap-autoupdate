@echo off 
:: autoupdate.bat - RDP Wrapper ini auto-update script (UTF-8 friendly)
chcp 65001 >nul
setlocal EnableExtensions
setlocal EnableDelayedExpansion

:: Variables & defaults (overridable by autoupdate.conf)
:: 变量与默认配置（可被 autoupdate.conf 覆盖）
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

:: Admin check & elevation (preserve args)
:: 管理员检测与提权（保留参数）
:: If not running as administrator, attempt to re-launch elevated and exit current instance
:: 如果未以管理员运行，则尝试使用 PowerShell 提升并退出当前实例
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] This script is not running with administrator privileges.
    echo [*] Attempting to restart with elevated permissions. Please approve the UAC prompt to continue.
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    ) else (
        powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs"
    )
    exit /b 0
)

:: Read optional external configuration autoupdate.conf
:: 读取外部配置 autoupdate.conf（可选）
:: Supports KEY=VALUE lines; comments start with #; lines are trimmed (simple)
:: 支持格式: KEY=VALUE，注释以 # 开头，行会被 trim（简单处理）
:: If missing, built-in defaults are used silently
:: 如果文件不存在，则静默使用默认内置配置
set "CONF_FILE=%SCRIPT_DIR%autoupdate.conf"
if exist "%CONF_FILE%" (
    for /f "usebackq tokens=1* delims=" %%A in ("%CONF_FILE%") do (
        set "line=%%A"
        if not "!line!"=="" (
            set "first=!line:~0,1!"
            if not "!first!"=="#" (
                :: Handle possible BOM (UTF-8 BOM appears as ï»¿), remove it
                :: 处理可能的 BOM（UTF-8 BOM 为 ï»¿ 显示形式），移除开头的 BOM 字符串
                set "line2=!line:ï»¿=!"
                for /f "tokens=1* delims==" %%K in ("!line2!") do (
                    set "k=%%K"
                    set "v=%%L"
                    :: Trim leading spaces from k and v (simple)
                    :: 去掉 k、v 前导空格（简单处理）
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

:: Build URL list (array)
:: 构建 URL 列表（数组形式）
set i=0
:collect_urls
call set "temp=%%RDPWRAP_URL_%i%%%"
if defined temp (
    set "rdpwrap_ini_update_github[%i%]=%temp%"
    set /a i+=1
    goto collect_urls
)
set /a length=i-1
echo [*] Found %i% URL(s) (indexes 0 to %length%).

:: Parameter handling - supports -log
:: 参数处理 - 支持 -log, -taskadd, -taskremove
if /i "%~1"=="-log" (
    echo %autoupdate_bat% output from %date% at %time% > "%autoupdate_log%"
    call "%autoupdate_bat%" >> "%autoupdate_log%"
    goto finish
)
if /i not "%~1"=="" (
    echo [x] Unknown argument: "%~1"
    echo [*] Supported arguments:
    echo     -log         = write output to autoupdate.log
    goto finish
)

:: Get termsrv.dll version
:: 获取 termsrv.dll 版本
for /f "usebackq delims=" %%a in (
`powershell -NoProfile -Command "Split-Path -Leaf (Get-Item %windir%\System32\termsrv.dll).VersionInfo.ProductVersionRaw"`
) do set "termsrv_dll_ver=%%a"

if not defined termsrv_dll_ver (
    echo [x] Unable to obtain termsrv.dll version. Aborting.
    goto finish
)

echo [+] Detected termsrv.dll version: %termsrv_dll_ver%.

:: Check if local rdpwrap.ini already contains this version entry
:: 检查本地 rdpwrap.ini 是否已经包含此版本条目
if exist "%rdpwrap_ini%" (
    echo [*] Searching "%rdpwrap_ini%" for entry [%termsrv_dll_ver%].
    findstr /c:"[%termsrv_dll_ver%]" "%rdpwrap_ini%" >nul
    if not errorlevel 1 (
        echo [+] Entry [%termsrv_dll_ver%] found in "%rdpwrap_ini%".
        echo [*] RDP Wrapper appears to match the current system version. Exiting and cleaning up.
        goto finish
    ) else (
        echo [-] Entry [%termsrv_dll_ver%] not found in "%rdpwrap_ini%".
    )
) else (
    echo [-] File not found: "%rdpwrap_ini%". Will try candidate URLs to download and match.
)

:: Iterate candidate URLs: download and check for the version entry
:: 逐个尝试 URL，下载并检测是否包含版本条目
for /l %%i in (0,1,%length%) do (
    set "rdpwrap_ini_url=!rdpwrap_ini_update_github[%%i]!"
    call :check_update
)

goto finish

:: check_update - search candidate or create temp file and download
:: check_update - 若存在候选文件则搜索版本，否则创建临时文件并下载
:check_update
if exist "%rdpwrap_ini_check%" (
    echo [*] Searching "%rdpwrap_ini_check%" for entry [%termsrv_dll_ver%].
    findstr /c:"[%termsrv_dll_ver%]" "%rdpwrap_ini_check%" >nul
    if not errorlevel 1 (
        echo [+] Entry [%termsrv_dll_ver%] found in "%rdpwrap_ini_check%".
        echo [*] Will replace rdpwrap.ini with this file.
        call :copynew
        goto :eof
    ) else (
        echo [-] Entry [%termsrv_dll_ver%] not found in "%rdpwrap_ini_check%".
        call :update
        goto :eof
    )
) else (
    echo [*] Creating "%rdpwrap_new_ini%" and attempting download.
    copy /y NUL "%rdpwrap_new_ini%" >NUL
    set "rdpwrap_ini_check=%rdpwrap_new_ini%"
    call :update
    goto :eof
)
goto :eof

:: update - download current URL to temporary file
:: update - 下载当前 URL 到临时文件
:update
echo [*] Checking network connectivity.
:netcheck
ping -n 1 www.baidu.com >nul
if errorlevel 1 (
    goto waitnetwork
) else (
    goto download
)

:waitnetwork
echo [*] Waiting for network to become available; will retry shortly.
ping 127.0.0.1 -n 11 >nul
set /a retry_network_check=retry_network_check+1
if %retry_network_check% LSS 30 goto netcheck
echo [x] Network unavailable after retries; skipping URL: %rdpwrap_ini_url%
goto :eof

:download
echo [*] Download URL: %rdpwrap_ini_url%
if not "%PROXYSERVER%"=="" (
    curl --fail -s -x %PROXYSERVER% -L "%rdpwrap_ini_url%" -o "%rdpwrap_new_ini%"
) else (
    curl --fail -s -L "%rdpwrap_ini_url%" -o "%rdpwrap_new_ini%"
)

if %errorlevel%==0 (
    echo [+] Download succeeded: "%rdpwrap_new_ini%".
    set "rdpwrap_ini_check=%rdpwrap_new_ini%"
) else (
    echo [-] Download failed: "%rdpwrap_ini_url%".
    echo [*] Please check network or firewall settings.
)
goto :eof

:: copynew - replace rdpwrap.ini with downloaded file and restart TermService
:: copynew - 使用下载的文件覆盖 rdpwrap.ini 并重启 TermService
:copynew
echo [*] Replacing rdpwrap.ini and restarting TermService.
if exist "%rdpwrap_new_ini%" (
    echo [*] Stopping TermService.
    net stop termservice
    echo [*] Copying temporary file to target rdpwrap.ini.
    xcopy /y "%rdpwrap_new_ini%" "%rdpwrap_ini%" >nul
    echo [*] Starting TermService.
    net start termservice
) else (
    echo [x] Error: temporary file not found: "%rdpwrap_new_ini%".
)
goto :eof

:: reinstall - Optional: use RDPWInst.exe to uninstall/install (keeps original logic)
:: reinstall - 可选：使用 RDPWInst.exe 进行卸载/安装（保留原逻辑）
:reinstall
echo [*] Performing uninstall/install using RDPWInst.
"%RDPWInst_exe%" -u

IF NOT EXIST "%rdpfolder%" (
    mkdir "%rdpfolder%"
)

if exist "%rdpwrap_new_ini%" (
    echo [*] Copying "%rdpwrap_new_ini%" to "%rdpwrap_ini%".
    xcopy /y "%rdpwrap_new_ini%" "%rdpwrap_ini%" >nul
) else (
    echo [x] Error: temporary file not found: "%rdpwrap_new_ini%".
)

"%RDPWInst_exe%" -i -o
goto :eof

:: finish - unified exit point (calls cleanup); pause only for interactive sessions
:: finish - 统一结束点（调用 cleanup），根据是否交互式决定是否 pause
:finish
echo [*] Operation complete. Performing cleanup.
call :cleanup

:: If in interactive Console session then pause, otherwise exit after short notice
:: 如果在交互式 Console 会话下则 pause，否则显示短提示后退出
if "%SESSIONNAME%"=="Console" (
    pause
) else (
    echo [*] Non-interactive session: exiting in 10 seconds.
    timeout /t 10 >nul
)

endlocal
exit /b 0

:: cleanup - ensure temporary file rdpwrap_new_ini is removed
:: cleanup - 保证删除临时文件 rdpwrap_new_ini
:cleanup
if exist "%rdpwrap_new_ini%" (
    echo [*] Deleting temporary file "%rdpwrap_new_ini%".
    del /f /q "%rdpwrap_new_ini%" >nul 2>&1
    if exist "%rdpwrap_new_ini%" (
        echo [!] Failed to delete "%rdpwrap_new_ini%". Please remove it manually.
    ) else (
        echo [+] Temporary file removed.
    )
) else (
    :: No temporary file, nothing to do
    :: rem 无临时文件，无需处理
)
goto :eof
