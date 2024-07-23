@ECHO OFF

SET FF_FOLDER=%USERPROFILE%\Documents\My games\FINAL FANTASY XIV - A Realm Reborn
SET TARGET=%FF_FOLDER%\SYMLINK_TARGET

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
	PAUSE
	EXIT /B
)

FOR /D %%Q IN ("%FF_FOLDER%"\FFXIV_CHR*) DO (
	FOR %%T IN ("%TARGET%"\*.DAT) DO (
		DEL "%%Q\%%~nxT"
		MKLINK "%%Q\%%~nxT" "%%T"
	)
)

PAUSE
EXIT /B