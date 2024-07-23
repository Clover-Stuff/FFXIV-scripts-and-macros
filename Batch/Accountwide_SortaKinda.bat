SET CONFIG=%APPDATA%\XIVLauncher\pluginConfigs\SortaKinda
SET TARGET=%CONFIG%\SORTA_TARGET

FOR /D %%C IN ("%CONFIG%"\*) DO (
	IF "%%~nC" LSS "999" (
		RMDIR /S /Q "%%C"
		MKLINK /J "%%C" %TARGET%
	)
)

PAUSE
EXIT /B