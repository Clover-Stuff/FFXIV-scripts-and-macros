@ECHO OFF

REM First, log in to alts to create their config folders.
REM Make a copy of your main SortaKinda config, named the same as TARGET below.
REM Save this script anywhere and run as administrator.
REM All individual character configs for SortaKinda will be replaced with directory junctions.
REM Script has to be run again after adding another character.

SET CONFIG=%APPDATA%\XIVLauncher\pluginConfigs\SortaKinda
SET TARGET=%CONFIG%\SORTA_TARGET

net session >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO This script must be run as administrator
    PAUSE
    EXIT /B
)

IF EXIST "%TARGET%\" (
    ECHO some useful message
) ELSE (
    ECHO %TARGET% does not exist!
    ECHO If you continue, your SortaKinda config will be lost!
    ECHO Directory junctions should still be created.
	PAUSE
	MKDIR %TARGET%
)

FOR /D %%C IN ("%CONFIG%"\*) DO (
	IF "%%~nC" LSS "999" (
		RMDIR /S /Q "%%C"
		MKLINK /J "%%C" %TARGET%
	)
)

PAUSE
EXIT /B