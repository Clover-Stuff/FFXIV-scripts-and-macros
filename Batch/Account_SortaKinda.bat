@ECHO OFF

SET CONFIG=%APPDATA%\XIVLauncher\pluginConfigs\SortaKinda
SET TARGET=%CONFIG%\SORTA_TARGET

net session >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO This script must be run as administrator
    PAUSE
    EXIT /B
)

IF EXIST %TARGET%\ (
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