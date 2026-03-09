#!/bin/bash

set -e

# 检测是否需要 sudo
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "=== Steam VM Control 卸载脚本 ==="
echo ""

# 停止并禁用服务
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet steamvmctl.service 2>/dev/null; then
        echo "[1/3] 停止服务..."
        $SUDO systemctl stop steamvmctl.service
    fi

    if systemctl is-enabled --quiet steamvmctl.service 2>/dev/null; then
        echo "[2/3] 禁用服务..."
        $SUDO systemctl disable steamvmctl.service
    fi
    
    $SUDO systemctl daemon-reload 2>/dev/null || true
else
    echo "[1/3] 未检测到 systemd，跳过服务管理"
fi

# 删除文件
echo "[3/3] 删除文件..."
$SUDO rm -f /etc/systemd/system/steamvmctl.service
$SUDO rm -f /usr/local/bin/steamvmctl

echo ""
echo "✅ 卸载完成！"
