@echo off
cd /d "%~dp0"
echo ===========================
echo    TaskLy Admin Web
 echo ===========================
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found. Install Node.js 22 LTS.
  pause
  exit /b 1
)
if not exist node_modules\next (
  echo Installing dependencies...
  call npm install
  if errorlevel 1 (
    echo npm install failed. Check your internet connection.
    pause
    exit /b 1
  )
)
echo Opening http://localhost:3000
start "" http://localhost:3000
call npm run dev
pause
