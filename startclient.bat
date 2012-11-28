@echo off

SETLOCAL

set scriptdir=%~dp0
cd "%scriptdir%\workspace\.minecraft"
if NOT %ERRORLEVEL% == 0 (
	echo Could not change directory to workspace\.minecraft dir.
	goto failed
)

start javaw.exe -Xincgc -Xmx512M -Djava.library.path=..\..\archives\mojang\bin\natives -Dfile.encoding=Cp1252 -classpath ..\..\workspace\client-src\bin;..\..\archives\mojang\bin\jinput.jar;..\..\archives\mojang\bin\lwjgl_util.jar;..\..\archives\mojang\bin\lwjgl.jar;..\..\archives\mojang\bin\minecraft.jar;..\..\archives\btw\MINECRAFT-JAR Start

:success
exit /B 0

:failed
pause
exit /B 1
