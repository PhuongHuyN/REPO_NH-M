@echo off
setlocal
rem Usage: 99_run_all.bat [server] [database] [None^|Small^|Large]
set "FV_SERVER=%~1"
if not defined FV_SERVER set "FV_SERVER=localhost"
set "FV_DATABASE=%~2"
if not defined FV_DATABASE set "FV_DATABASE=FreshVendDB"
set "FV_SEED=%~3"
if not defined FV_SEED set "FV_SEED=None"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install-database.ps1" -Server "%FV_SERVER%" -Database "%FV_DATABASE%" -Seed "%FV_SEED%"
exit /b %ERRORLEVEL%
