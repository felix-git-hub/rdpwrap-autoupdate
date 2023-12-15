@echo off
setLocal EnableExtensions
setlocal EnableDelayedExpansion
:: -----------------------------------------
:: Location of new/updated rdpwrap.ini files
:: -----------------------------------------

:: Define array 定义数组
set rdpwrap_ini_update_github[0]="https://raw.githubusercontent.com/asmtron/rdpwrap/master/res/rdpwrap.ini"
set rdpwrap_ini_update_github[1]="https://raw.githubusercontent.com/sebaxakerhtc/rdpwrap.ini/master/rdpwrap.ini"
set rdpwrap_ini_update_github[2]="https://raw.githubusercontent.com/affinityv/INI-RDPWRAP/master/rdpwrap.ini"
set rdpwrap_ini_update_github[3]="https://raw.githubusercontent.com/DrDrrae/rdpwrap/master/res/rdpwrap.ini"
set rdpwrap_ini_update_github[4]="https://raw.githubusercontent.com/saurav-biswas/rdpwrap-1/master/res/rdpwrap.ini"
:: set rdpwrap_ini_update_github_6="https://raw.githubusercontent.com/....Extra.6...."
:: set rdpwrap_ini_update_github_7="https://raw.githubusercontent.com/....Extra.7...."

:: Get the length of the Array
set length=0
for /F "tokens=* delims=" %%i in ('set rdpwrap_ini_update_github[') do set /A length+=1
echo "We will get ini from" %length% "urls"

set autoupdate_bat="%~dp0autoupdate.bat"
set autoupdate_log="%~dp0autoupdate.log"
set RDPWInst_exe="%~dp0RDPWInst.exe"
set rdpwrap_dll="%~dp0rdpwrap.dll"
set rdpwrap_ini="C:\Program Files\RDP Wrapper\rdpwrap.ini"
set rdpwrap_new_ini="%~dp0rdpwrap_new.ini"
set rdpwrap_ini_check=%rdpwrap_new_ini%
set rdpfolder="C:\Program Files\RDP Wrapper\"

set github_location=1
set retry_network_check=0
set proxyserver="localhost:62090"

:: check for arguments
if /i "%~1"=="-log" (
    echo %autoupdate_bat% output from %date% at %time% > %autoupdate_log%
    call %autoupdate_bat% >> %autoupdate_log%
    goto :finish
)
if /i not "%~1"=="" (
    echo [x] Unknown argument specified: "%~1"
    echo [*] Supported argments/options are:
    echo     -log         =  redirect display output to the file autoupdate.log
    echo     -taskadd     =  add autorun of autoupdate.bat on startup in the schedule task
    echo     -taskremove  =  remove autorun of autoupdate.bat on startup in the schedule task
    goto :finish
)
:: check if admin
::fsutil dirty query %systemdrive% >nul
::if not %errorlevel% == 0 goto :finish



:: ----------------------------------------------------
:: 1) get file version of %windir%\System32\termsrv.dll 这段代码用于获取 Windows 中 termsrv.dll 文件的版本号，并将其存储在变量 %termsrv_dll_ver% 中。
:: ----------------------------------------------------


for /f "usebackq delims=" %%a in (
`powershell -c "Split-Path -Leaf (Get-Item %windir%\System32\termsrv.dll).VersionInfo.ProductVersionRaw"`
) do set "termsrv_dll_ver=%%a"

echo [+] Installed "termsrv.dll" version: %termsrv_dll_ver%.

::
:: --------------------------------------------------------------------
:: Check Current RDP Wrapper is up-to-date or not
:: -------------------------------------------------------------------

if exist %rdpwrap_ini% (
    echo [*] Start searching [%termsrv_dll_ver%] version entry in file %rdpwrap_ini%...
    findstr /c:"[%termsrv_dll_ver%]" %rdpwrap_ini% >nul
    if not errorlevel 1 (
            echo %rdpwrap_ini%
            echo [+] Found "termsrv.dll" version entry [%termsrv_dll_ver%] in file %rdpwrap_ini%.
            echo [*] RDP Wrapper seems to be up-to-date and working...
            call :finish
    ) else (
            echo [-] NOT found "termsrv.dll" version entry [%termsrv_dll_ver%] in file %rdpwrap_ini%^^!
        
    )


) else (
    :: 如果文件 %rdpwrap_ini_check% 不存在，则给出错误提示，并跳转至 :finish 结束程序。
    echo [-] File NOT found: %rdpwrap_ini%.
    call :check_update

)

:: --------------------------------------------------------------------
:: 2) check if installed termsrv.dll version exists in rdpwrap.ini 这段代码的作用是检查 RDP Wrapper 是否需要更新，并进行相应的操作。具体细节如下：
:: --------------------------------------------------------------------
for /l %%i in (0,1,%length%) do (
    set rdpwrap_ini_url=!rdpwrap_ini_update_github[%%i]!
::    call :update
    call :check_update

)

::
:: --------------------------------------------------------------------
:: update ini by git
:: -------------------------------------------------------------------

:check_update
if exist %rdpwrap_ini_check% (
    echo [*] Start searching [%termsrv_dll_ver%] version entry in file %rdpwrap_ini_check%...
    findstr /c:"[%termsrv_dll_ver%]" %rdpwrap_ini_check% >nul
    if not errorlevel 1 (

            echo [+] Found "termsrv.dll" version entry [%termsrv_dll_ver%] in file %rdpwrap_ini_check%.
            echo [*] RDP Wrapper seems to be up-to-date and working...
            :: call :reinstall
            call :copynew
            call :finish

             
    ) else (
            echo [-] NOT found "termsrv.dll" version entry [%termsrv_dll_ver%] in file %rdpwrap_ini_check%^^!
            
            call :update

    )


) else (
    :: if  %rdpwrap_ini_check% does not exsit, then exit 如果文件 %rdpwrap_ini_check% 不存在，则给出错误提示，并跳转至 :finish 结束程序。
    echo [-] File NOT found: %rdpwrap_ini_check%.
    echo [*] we will download the latest file %rdpwrap_new_ini%^^!
    set rdpwrap_ini_check=%rdpwrap_new_ini%
    copy /y NUL %rdpwrap_new_ini% >NUL
    goto :check_update
)
:: Go to finish 最后跳转至 :finish 结束程序。
goto :eof



::
:: --------------------------------------------------------------------
:: Download up-to-date (alternative) version of rdpwrap.ini from GitHub
:: --------------------------------------------------------------------
:update
echo [*] check network connectivity...
:netcheck
ping -n 1 baidu.com>nul
if errorlevel 1 (
    goto waitnetwork
) else (
    goto download
)

:waitnetwork
echo [.] Wait for network connection is available...
ping 127.0.0.1 -n 11>nul
set /a retry_network_check=retry_network_check+1
:: wait for a maximum of 5 minutes
if %retry_network_check% LSS 30 goto netcheck



:download
echo [*] Download latest version of rdpwrap.ini from GitHub...
echo     -^> %rdpwrap_ini_url%
if not "%proxyserver%" == "" (
curl --fail -s -x %proxyserver% -L %rdpwrap_ini_url% -o %rdpwrap_new_ini% 

        )  else   (
curl --fail -s -L %rdpwrap_ini_url% -o %rdpwrap_new_ini% 

        )

if %errorlevel%==0 (
    echo [+] Successfully download from GitHhub latest version to %rdpwrap_new_ini%.
    set rdpwrap_ini_check=%rdpwrap_new_ini%
) else (
    echo [-] FAILED to download from GitHub latest version to %rdpwrap_new_ini%^^!
    echo [*] Please check you internet connection/firewall and try again^^!
)

goto :eof


:: -------------------
:: Restart RDP Wrapper
:: -------------------
:copynew
echo.
echo [*] copyfile...
echo.


@REM IF NOT EXIST "%rdpfolder%" (
@REM     echo 1
@REM     mkdir "%rdpfolder%"
@REM )


if exist %rdpwrap_new_ini% (
    echo.
    net stop termservice

    echo [+] copy %rdpwrap_new_ini% to %rdpwrap_ini%...
    xcopy /y %rdpwrap_new_ini% %rdpwrap_ini%
::xcopy
    net start termservice

) else (
    echo [x] ERROR - File %rdpwrap_new_ini% is missing ^^!
)


goto :eof

:: -------------------
:: Restart RDP Wrapper
:: -------------------
:reinstall
echo.
echo [*] Restart RDP Wrapper with new ini (uninstall and reinstall)...
echo.
%RDPWInst_exe% -u



IF NOT EXIST "%rdpfolder%" (
    echo 1
    mkdir "%rdpfolder%"
)


if exist %rdpwrap_new_ini% (
    echo.
    echo [*] Use latest downloaded rdpwrap.ini from GitHub...
    echo     -^> %rdpwrap_ini_url% 
    echo       -^> %rdpwrap_new_ini%
    echo         -^> %rdpwrap_ini%
    echo [+] copy %rdpwrap_new_ini% to %rdpwrap_ini%...
    xcopy /y %rdpwrap_new_ini% %rdpwrap_ini%
::xcopy

) else (
    echo [x] ERROR - File %rdpwrap_new_ini% is missing ^^!
)
%RDPWInst_exe% -i -o
goto :eof

::
:: -------------------
:: Finish
:: -------------------

:finish
echo "all done"
pause
exit 
