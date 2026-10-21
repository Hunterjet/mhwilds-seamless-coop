@echo off
setlocal
if not exist "%~dp0collect-logs.ps1" (
  echo.
  echo Please extract the whole zip file first: right-click the zip ^> Extract All, then open the extracted folder.
  echo.
  pause
  exit /b 1
)
rem A PowerShell 7 module path would break Windows PowerShell modules.
set "PSModulePath="
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect-logs.ps1" %*
if %errorlevel%==1 (
  echo.
  echo Something went wrong before the collect-logs script could finish. Please send a photo of this window to the developer.
  pause
)
exit /b %errorlevel%
