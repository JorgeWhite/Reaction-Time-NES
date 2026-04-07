@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "CC65_BIN=%SCRIPT_DIR%..\cc65\bin"

if not exist "%CC65_BIN%\ca65.exe" (
	echo Could not find ca65 at "%CC65_BIN%\ca65.exe"
	echo Make sure the cc65 folder is next to nes-reaction-test.
	exit /b 1
)

pushd "%SCRIPT_DIR%"
"%CC65_BIN%\ca65.exe" main.asm -o main.o
if errorlevel 1 (
	popd
	exit /b %errorlevel%
)

"%CC65_BIN%\ld65.exe" main.o -o reaction.nes -C linker.cfg
set "BUILD_RC=%errorlevel%"
popd

exit /b %BUILD_RC%