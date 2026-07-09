@echo off
chcp 65001 >nul
title 图片编辑工具 - 启动器
color 0A

echo.
echo   ╔══════════════════════════════════════════╗
echo   ║     🖼️  图片编辑工具 - 启动器           ║
echo   ╚══════════════════════════════════════════╝
echo.

set "ROOT_DIR=%~dp0"

:: ============================================
:: 检查 Node.js 环境
:: ============================================
echo   [检查] 正在检查 Node.js 环境...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo   [错误] 未找到 Node.js，请先安装 Node.js
    pause
    exit /b 1
)
echo   [√] Node.js 已就绪

:: ============================================
:: 安装后端依赖
:: ============================================
if not exist "%ROOT_DIR%server\node_modules" (
    echo   [安装] 正在安装后端依赖...
    cd /d "%ROOT_DIR%server"
    call npm install --silent
    if %errorlevel% neq 0 (
        echo   [错误] 后端依赖安装失败
        pause
        exit /b 1
    )
    echo   [√] 后端依赖安装完成
) else (
    echo   [√] 后端依赖已就绪
)

:: ============================================
:: 安装前端依赖
:: ============================================
if not exist "%ROOT_DIR%client\node_modules" (
    echo   [安装] 正在安装前端依赖...
    cd /d "%ROOT_DIR%client"
    call npm install --silent
    if %errorlevel% neq 0 (
        echo   [错误] 前端依赖安装失败
        pause
        exit /b 1
    )
    echo   [√] 前端依赖安装完成
) else (
    echo   [√] 前端依赖已就绪
)

:: ============================================
:: 清理可能占用的端口
:: ============================================
echo   [清理] 正在清理端口...

for /f "tokens=5" %%a in ('netstat -ano ^| find ":5172" ^| find "LISTENING"') do (
    tasklist /fi "pid eq %%a" 2>nul | find "node.exe" >nul && (
        echo   [清理] 终止 PID %%a (端口 5172)
        taskkill /f /pid %%a >nul 2>&1
    )
)
for /f "tokens=5" %%a in ('netstat -ano ^| find ":5173" ^| find "LISTENING"') do (
    tasklist /fi "pid eq %%a" 2>nul | find "node.exe" >nul && (
        echo   [清理] 终止 PID %%a (端口 5173)
        taskkill /f /pid %%a >nul 2>&1
    )
)

timeout /t 2 /nobreak >nul

echo   [√] 端口清理完成

echo.
echo   ╔══════════════════════════════════════════╗
echo   ║          正在启动服务...                ║
echo   ╚══════════════════════════════════════════╝
echo.

:: ============================================
:: 启动后端
:: ============================================
echo   [启动] 后端服务器 (端口 5172)...
start "图片编辑-后端" cmd /c "cd /d "%ROOT_DIR%server" && node index.js"

:: 等待后端就绪
echo   [等待] 等待后端启动...
timeout /t 2 /nobreak >nul

:: ============================================
:: 启动前端
:: ============================================
echo   [启动] 前端开发服务器 (端口 5173)...
start "图片编辑-前端" cmd /c "cd /d "%ROOT_DIR%client" && npx vite --host"

:: 等待前端就绪
echo   [等待] 等待前端启动...
timeout /t 3 /nobreak >nul

:: ============================================
:: 打开浏览器
:: ============================================
echo   [打开] 正在打开浏览器...
start http://localhost:5173

echo.
echo   ╔══════════════════════════════════════════╗
echo   ║  ✅ 启动完成！                         ║
echo   ║                                         ║
echo   ║  后端:  http://localhost:5172          ║
echo   ║  前端:  http://localhost:5173          ║
echo   ║                                         ║
echo   ║  关闭此窗口不影响服务运行              ║
echo   ╚══════════════════════════════════════════╝
echo.
echo   按任意键关闭此启动器窗口（服务继续运行）...
pause >nul