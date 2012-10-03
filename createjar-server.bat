@echo off

VERIFY OTHER 2>nul
SETLOCAL ENABLEDELAYEDEXPANSION
IF NOT ERRORLEVEL 0 (
	echo Failed to enable delayed expansion. Possibly an old version of CMD.exe.
)

REM ====================================
REM Determine and change to script's directory
REM ====================================

set SCRIPTDIR=%~dp0
cd "%SCRIPTDIR%"
if NOT ERRORLEVEL 0 (
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
REM Specify archive directories.
REM ====================================

set MOJANGARCHIVES=archives\mojang
set BTWARCHIVES=archives\btw
set MCPJARS=%SCRIPTDIR%\mcp\jars
set ZIP=%SCRIPTDIR%\bin\7za\7za.exe

if NOT EXIST "%MCPJARS%" (
	echo.
	echo MCP jars directory does not exist.
	echo You may need to install MCP to %SCRIPTDIR%\mcp
	goto failed
)

REM ====================================
REM Read arguments and verify file locatoins.
REM ====================================

set MCVER=%~1
set BTWVER=%~2
set TYPE=%~3

if "%TYPE%" == "" (
	set TYPE=server
)

:getmcver
if "%MCVER%" == "" (
	set /P MCVER=Enter the Minecraft version ^(e.g. 1.3.2^): 
)

if "%MCVER%" == "" (
	goto getmcver
	REM echo Missing ^<mcver^> ^(e.g. 1.3.2^)
	REM goto syntax
)

set MCDIR=%MOJANGARCHIVES%\%MCVER%
set MCSERVER=%MCDIR%\minecraft_server.jar
set MCBIN=%MCDIR%\bin
set MCCLIENT=%MCBIN%\minecraft.jar
set MCRESOURCES=%MCDIR%\resources

if NOT EXIST "%SCRIPTDIR%\%MCDIR%" (
	echo.
	echo Directory does not exist for the version specified:
	echo 	%MCDIR%
	echo.
	set MCVER=
	goto getmcver
)
if "%TYPE%" == "server" (
	if NOT EXIST "%SCRIPTDIR%\%MCSERVER%" (
		echo.
		echo Directory does not exist for the version specified:
		echo 	%MCSERVER%
		echo.
		set MCVER=
		goto getmcver
	)
)
if "%TYPE%" == "client" (
	if NOT EXIST "%SCRIPTDIR%\%MCBIN%" (
		echo.
		echo Directory does not exist for the version specified:
		echo 	%MCBIN%
		echo.
		set MCVER=
		goto getmcver
	)
	if NOT EXIST "%SCRIPTDIR%\%MCCLIENT%" (
		echo.
		echo File does not exist for the version specified:
		echo 	%MCCLIENT%
		echo.
		set MCVER=
		goto getmcver
	)
	if NOT EXIST "%SCRIPTDIR%\%MCRESOURCES%" (
		echo.
		echo Directory does not exist for the version specified:
		echo 	%MCRESOURCES%
		echo.
		set MCVER=
		goto getmcver
	)
)

:getbtwver
if "%BTWVER%" == "" (
	set /P BTWVER=Enter the BTW version ^(e.g. 4.16^): 
)

if "%BTWVER%" == "" (
	goto getbtwver
	REM echo Missing ^<btwver^> ^(e.g. 4.16^)
	REM goto syntax
)

set BTW=%BTWARCHIVES%\%BTWVER%.zip

if NOT EXIST "%SCRIPTDIR%\%BTW%" (
	echo.
	echo File does not exist for the version specified:
	echo 	%BTW%
	echo.
	set BTWVER=
	goto getbtwver
)

REM ====================================
REM Set up directories.
REM ====================================

set TEMPDIR=%SCRIPTDIR%\temp
set JARTEMPDIR=%TEMPDIR%\createjar-%TYPE%

if NOT EXIST "%TEMPDIR%" (
	mkdir "%TEMPDIR%" >NUL
	if NOT EXIST "%TEMPDIR%" (
		echo ERROR: Could not create the temp directory at: %TEMPDIR%
		goto failed
	)
)

if EXIST "%JARTEMPDIR%" (
	rmdir /Q /S "%JARTEMPDIR%" >NUL
	if EXIST "%JARTEMPDIR%" (
		echo ERROR: Could not delete the temp directory at: %JARTEMPDIR%
		goto failed
	)
)

mkdir "%JARTEMPDIR%" >NUL
if NOT EXIST "%JARTEMPDIR%" (
	echo ERROR: Could not create the temp directory at: %JARTEMPDIR%
	goto failed
)

mkdir "%JARTEMPDIR%\btw" >NUL
if NOT EXIST "%JARTEMPDIR%\btw" (
	echo ERROR: Could not create directory within temp directory at: %JARTEMPDIR%\btw
	goto failed
)

REM ====================================
REM Copy fresh files.
REM ====================================

if "%TYPE%" == "server" (
	echo Copying fresh Minecraft server jar...
	copy /V /Y "%MCSERVER%" "%MCPJARS%\" >NUL
	if NOT ERRORLEVEL 0 goto failed
)
if "%TYPE%" == "client" (
	echo Copying fresh Minecraft %TYPE% bin directory...
	xcopy /E /V /Y "%MCBIN%" "%MCPJARS%\bin\" >NUL
	if NOT ERRORLEVEL 0 goto failed
)
REM ====================================
REM Extract BTW.
REM ====================================

echo Extracting BTW zip...
"%ZIP%" x -o"%JARTEMPDIR%\btw" "%SCRIPTDIR%\%BTW%" > "%JARTEMPDIR%\extracting-btw.out" 2>&1
if NOT ERRORLEVEL 0 (
	echo FAILED: See %JARTEMPDIR%\extracting-btw.out
	goto failed
)

if "%TYPE%" == "server" (
	if NOT EXIST "%JARTEMPDIR%\btw\MINECRAFT_SERVER-JAR" (
		echo ERROR: BTW zip does not seem to contain the MINECRAFT_SERVER-JAR directory.
		goto failed
	)
)
if "%TYPE%" == "client" (
	if NOT EXIST "%JARTEMPDIR%\btw\MINECRAFT-JAR" (
		echo ERROR: BTW zip does not seem to contain the MINECRAFT-JAR directory.
		goto failed
	)
)

REM ====================================
REM Copy BTW into Minecraft.
REM ====================================

if "%TYPE%" == "server" (
	echo Adding BTW files to minecraft_server.jar...
	"%ZIP%" a -tzip "%MCPJARS%\minecraft_server.jar" "%JARTEMPDIR%\btw\MINECRAFT_SERVER-JAR\*" > "%JARTEMPDIR%\adding-to-archive.out" 2>&1
	if NOT ERRORLEVEL 0 (
		echo FAILED: See %JARTEMPDIR%\adding-to-archive.out
		goto failed
	)
	
	echo Removing META-INF from minecraft_server.jar...
	"%ZIP%" d -tzip "%MCPJARS%\minecraft_server.jar" META-INF > "%JARTEMPDIR%\removing-meta-inf.out" 2>&1
	if NOT ERRORLEVEL 0 (
		echo FAILED: See %JARTEMPDIR%\removing-meta-inf.out
		goto failed
	)
)
if "%TYPE%" == "client" (
	echo Adding BTW files to minecraft.jar...
	"%ZIP%" a -tzip "%MCPJARS%\minecraft.jar" "%JARTEMPDIR%\btw\MINECRAFT-JAR\*" > "%JARTEMPDIR%\adding-to-archive.out" 2>&1
	if NOT ERRORLEVEL 0 (
		echo FAILED: See %JARTEMPDIR%\adding-to-archive.out
		goto failed
	)

	echo Removing META-INF from minecraft.jar...
	"%ZIP%" d -tzip "%MCPJARS%\bin\minecraft.jar" META-INF > "%JARTEMPDIR%\removing-meta-inf.out" 2>&1
	if NOT ERRORLEVEL 0 (
		echo FAILED: See %JARTEMPDIR%\removing-meta-inf.out
		goto failed
	)
)

rmdir /Q /S "%JARTEMPDIR%" >nul 2>&1

echo SUCCESS
exit /B 0

:syntax
echo Syntax: createjar-server.bat ^<mcver^> ^<btwver^>

:failed
exit /B 1
