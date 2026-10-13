@echo off
set DATABASE_URL=jdbc:postgresql://localhost:55432/taskly
set POSTGRES_PORT=55432
cd /d "%~dp0"
if exist "build\libs\taskly-backend-0.1.0-SNAPSHOT.jar" (
    java -jar build\libs\taskly-backend-0.1.0-SNAPSHOT.jar
) else (
    gradlew.bat bootRun
)
