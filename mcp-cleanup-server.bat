@echo off

SETLOCAL

set scriptdir=%~dp0
cd "%scriptdir%\mcp"
if NOT %ERRORLEVEL% == 0 (
	echo Could not change directory to mcp dir.
	goto failed
)

if NOT EXIST "%scriptdir%\conf\mcp-clean-server.cfg" (
	echo %scriptdir%\conf\mcp-clean-server.cfg is missing.
	goto failed
)

echo cleanup.bat -c "%scriptdir%\conf\mcp-clean-server.cfg"
pause

:success
exit /B 0

:failed
pause
exit /B 1
