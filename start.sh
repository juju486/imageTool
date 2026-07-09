#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

echo
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     🖼️  图片编辑工具 - 启动器           ║"
echo "  ╚══════════════════════════════════════════╝"
echo

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}  [错误] 未找到 Node.js，请先安装 Node.js${NC}"
    exit 1
fi
echo -e "${GREEN}  [✓] Node.js 已就绪${NC}"

if [ ! -d "$ROOT_DIR/server/node_modules" ]; then
    echo "  [安装] 正在安装后端依赖..."
    cd "$ROOT_DIR/server" && npm install --silent
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}  [错误] 后端依赖安装失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}  [✓] 后端依赖安装完成${NC}"
else
    echo -e "${GREEN}  [✓] 后端依赖已就绪${NC}"
fi

if [ ! -d "$ROOT_DIR/client/node_modules" ]; then
    echo "  [安装] 正在安装前端依赖..."
    cd "$ROOT_DIR/client" && npm install --silent
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}  [错误] 前端依赖安装失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}  [✓] 前端依赖安装完成${NC}"
else
    echo -e "${GREEN}  [✓] 前端依赖已就绪${NC}"
fi

echo "  [清理] 正在清理端口..."

kill_port() {
    local port=$1
    local pid=""
    if command -v lsof &> /dev/null; then
        pid=$(lsof -ti:$port 2>/dev/null)
    elif command -v fuser &> /dev/null; then
        pid=$(fuser ${port}/tcp 2>/dev/null)
    elif command -v ss &> /dev/null; then
        pid=$(ss -tlnp "sport = :$port" 2>/dev/null | grep -oP 'pid=\K\d+' | head -1)
    elif command -v netstat &> /dev/null; then
        pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1)
    fi
    if [ -n "$pid" ]; then
        echo "  [清理] 终止 PID $pid (端口 $port)"
        kill -9 $pid 2>/dev/null
    fi
}

kill_port 5172
kill_port 5173
sleep 1

echo -e "${GREEN}  [✓] 端口清理完成${NC}"

echo
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          正在启动服务...                ║"
echo "  ╚══════════════════════════════════════════╝"
echo

echo "  [启动] 后端服务器 (端口 5172)..."
cd "$ROOT_DIR/server"
node index.js &
SERVER_PID=$!

sleep 2

echo "  [启动] 前端开发服务器 (端口 5173)..."
cd "$ROOT_DIR/client"
npx vite --host &
CLIENT_PID=$!

sleep 3

if [[ "$OSTYPE" == "darwin"* ]]; then
    open http://localhost:5173
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open http://localhost:5173
fi

echo
echo "  ╔══════════════════════════════════════════╗"
echo "  ║  ✅ 启动完成！                         ║"
echo "  ║                                         ║"
echo "  ║  后端:  http://localhost:5172          ║"
echo "  ║  前端:  http://localhost:5173          ║"
echo "  ║                                         ║"
echo "  ║  按 Ctrl+C 停止服务                    ║"
echo "  ╚══════════════════════════════════════════╝"
echo

wait $SERVER_PID $CLIENT_PID