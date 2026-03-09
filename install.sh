#!/bin/bash

set -e

# 检测是否需要 sudo
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "=== Steam VM Control 安装脚本 ==="
echo ""

# 生成随机 token
TOKEN=$(openssl rand -hex 32)
echo "生成的 Token: $TOKEN"
echo ""

# 显示当前 VM 列表
echo "当前 PVE 虚拟机列表："
qm list || true
echo ""

# 获取 VM ID
while true; do
    read -p "请输入 VM ID: " VM_ID
    if [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
        break
    else
        echo "VM ID 必须是数字，请重新输入"
    fi
done
echo "VM ID: $VM_ID"
echo ""

# 获取端口
while true; do
    read -p "请输入监听端口 [默认 8080]: " PORT
    PORT=${PORT:-8080}
    if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
        break
    else
        echo "端口必须是 1-65535 之间的数字，请重新输入"
    fi
done
echo "端口: $PORT"
echo ""

echo "开始安装..."
echo ""

# 构建二进制文件
echo "[1/4] 构建二进制文件..."
go build -o steamvmctl main.go
echo "构建完成"
echo ""

# 安装二进制文件
echo "[2/4] 安装二进制文件到 /usr/local/bin/..."
$SUDO mv steamvmctl /usr/local/bin/
$SUDO chmod +x /usr/local/bin/steamvmctl
echo "安装完成"
echo ""

# 生成 systemd 服务文件
echo "[3/4] 生成 systemd 服务文件..."
$SUDO tee /etc/systemd/system/steamvmctl.service > /dev/null <<EOF
[Unit]
Description=Steam VM Control API
After=network.target

[Service]
Environment="VMID=$VM_ID"
Environment="TOKEN=$TOKEN"
Environment="PORT=$PORT"
ExecStart=/usr/local/bin/steamvmctl
Restart=always

[Install]
WantedBy=multi-user.target
EOF
echo "服务文件已创建: /etc/systemd/system/steamvmctl.service"
echo ""

# 启动服务
echo "[4/4] 启动并启用服务..."
if command -v systemctl &> /dev/null; then
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable steamvmctl.service
    $SUDO systemctl restart steamvmctl.service
    echo ""
    
    # 检查服务状态
    sleep 1
    if $SUDO systemctl is-active --quiet steamvmctl.service; then
        echo "✅ 安装成功！服务正在运行"
    else
        echo "⚠️ 服务启动失败，请检查日志: ${SUDO} journalctl -u steamvmctl.service"
    fi
else
    echo "⚠️ 未检测到 systemd，服务未自动启动"
    echo "   请手动运行: VMID=$VM_ID TOKEN=$TOKEN PORT=$PORT /usr/local/bin/steamvmctl"
fi
echo ""

# 显示信息
echo "=== 安装信息 ==="
echo "VM ID: $VM_ID"
echo "端口: $PORT"
echo "Token: $TOKEN"
echo ""
echo "API 端点:"
echo "  - 启动 VM: curl 'http://127.0.0.1:$PORT/start?token=$TOKEN'"
echo "  - 停止 VM: curl 'http://127.0.0.1:$PORT/stop?token=$TOKEN'"
echo "  - 查看状态: curl 'http://127.0.0.1:$PORT/status?token=$TOKEN'"
echo ""
echo "服务管理命令:"
echo "  - 查看状态: ${SUDO} systemctl status steamvmctl.service"
echo "  - 查看日志: ${SUDO} journalctl -u steamvmctl.service -f"
echo "  - 重启服务: ${SUDO} systemctl restart steamvmctl.service"
echo ""
echo "卸载命令: ${SUDO} ./uninstall.sh"
