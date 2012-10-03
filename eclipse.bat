@echo off

SETLOCAL

set SCRIPTDIR=%~dp0
cd "%SCRIPTDIR%"
if NOT %ERRORLEVEL% == 0 (
	echo Could not change directory to script directory.
	goto failed
)

PATH=%PATH%;c:\Program Files\Eclipse;%USERPROFILE%\Eclipse;%HOMEDRIVE%%HOMEPATH%\Eclipse
start eclipse.exe -data "%SCRIPTDIR%\workspace"

if NOT %ERRORLEVEL% == 0 (
	echo Failed to start eclipse. You may need to add the Eclipse directory to your system path. 
	echo See https://www.google.com/search?q=windows+how+to+change+system+path for help.
	goto failed
)

:success
exit /B 0

:failed
pause
exit /B 1