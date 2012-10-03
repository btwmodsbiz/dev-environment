@echo off

VERIFY OTHER 2>nul
SETLOCAL ENABLEDELAYEDEXPANSION
IF NOT %ERRORLEVEL% == 0 (
	echo Failed to enable delayed expansion. Possibly an old version of CMD.exe.
)

set PATH=C:\Program Files\Git\bin;%PATH%

REM ====================================
REM Determine and change to script's directory
REM ====================================

set SCRIPTDIR=%~dp0
cd "%SCRIPTDIR%"
if NOT %ERRORLEVEL% == 0 (
	echo.
	echo Could not change directory to script dir.
	goto failed
)

REM Remove trailing slash.
if NOT "%SCRIPTDIR%" == "\" (
if "%SCRIPTDIR:~-1%" == "\" (
	set SCRIPTDIR=%SCRIPTDIR:~0,-1%
)
)

REM ====================================
REM Verify the environment is set up correctly.
REM ====================================

set MCP=mcp
set MCPCFG=conf\mcp-decompile.cfg
set MCPDECOMPILE=%MCP%\decompile.bat

REM ====================================
REM Verify the environment is set up correctly.
REM ====================================

git --version >nul 2>&1
if NOT %ERRORLEVEL% == 0 (
	echo.
	echo The 'git' command is either not on the PATH or is not installed.
	goto failed
)

if NOT EXIST "%SCRIPTDIR%\%MCPDECOMPILE%" (
	echo.
	echo Could not find the decompile.bat file in the MCP directory.
	echo You may need to install MCP to %SCRIPTDIR%\%MCP%
	goto failed
)

if NOT EXIST "%SCRIPTDIR%\%MCPCFG%" (
	echo.
	echo %MCPCFG% is missing. Cannot continue without its overrides.
	goto failed
)

echo "%SCRIPTDIR%\%MCPDECOMPILE%" -r -c "%SCRIPTDIR%\%MCPCFG%"

echo SHOULD NOT REACH

exit /B 0

:failed
exit /B 1