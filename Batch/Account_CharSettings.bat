@ECHO OFF

REM First, log in to alts to create their config folders.
REM Make a new folder, named the same as TARGET below.
REM Copy in the files that you want to be account wide. 
REM Recommended list:
REM ADDON.DAT COMMON.DAT CONTROL0.DAT CONTROL1.DAT HOTBAR.DAT KEYBIND.DAT LOGFLTR.DAT MACRO.DAT
REM Save this script anywhere and run as administrator.
REM Files in the TARGET folder will be symlinked into all character folders.
REM Script has to be run again after adding another character.

SET FF_FOLDER=%USERPROFILE%\Documents\My games\FINAL FANTASY XIV - A Realm Reborn
SET TARGET=%FF_FOLDER%\SYMLINK_TARGET

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