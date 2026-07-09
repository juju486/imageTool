@echo off
chcp 65001 >nul
echo ========================================
echo   清理端口 5172 / 5173
echo ========================================
echo.

for /f "tokens=5" %%a in ('netstat -ano ^| find ":5172" ^| find "LISTENING"') do (
    echo 发现 PID %%a 占用端口 5172
    tasklist /fi "pid eq %%a" 2>nul | find "node.exe" >nul && (
        echo 正在终止 node.exe ^(PID %%a^)...
        taskkill /f /pid %%a >nul 2>&1 && echo [√] 已终止
    )
)

for /f "tokens=5" %%a in ('netstat -ano ^| find ":5173" ^| find "LISTENING"') do (
    echo 发现 PID %%a 占用端口 5173
    tasklist /fi "pid eq %%a" 2>nul | find "node.exe" >nul && (
        echo 正在终止 node.exe ^(PID %%a^)...
        taskkill /f /pid %%a >nul 2>&1 && echo [√] 已终止
    )
)

echo.
echo ========================================
echo   清理完成，可以重新启动 start.bat 了
echo ========================================
pause