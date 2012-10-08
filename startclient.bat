@echo off

SETLOCAL

set scriptdir=%~dp0
cd "%scriptdir%\mcp\jars"
if NOT %ERRORLEVEL% == 0 (
	echo Could not change directory to mcp\jars dir.
	goto failed
)

start javaw.exe -Xincgc -Xmx1024M -Xms1024M -Djava.library.path=..\..\mcp\jars\bin\natives -Dfile.encoding=Cp1252 -classpath ..\..\workspace\client-src\bin;..\..\mcp\jars\bin\jinput.jar;..\..\mcp\jars\bin\lwjgl_util.jar;..\..\mcp\jars\bin\lwjgl.jar;..\..\mcp\jars\bin\minecraft.jar Start

:success
exit /B 0

:failed
pause
exit /B 1
