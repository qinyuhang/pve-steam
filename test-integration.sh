#!/bin/bash

# 集成测试脚本 - 在 Docker 中测试 install.sh 和 uninstall.sh

set -e

echo "=== Steam VM Control 集成测试 ==="
echo ""

# 清理之前可能残留的容器
docker rm -f steamvmctl-test-container 2>/dev/null || true

# 构建测试镜像
echo "[1/6] 构建测试镜像..."
docker build -f Dockerfile.test -t steamvmctl-test .
echo "✅ 镜像构建完成"
echo ""

# 启动容器
echo "[2/6] 启动测试容器..."
CONTAINER_ID=$(docker run -d --name steamvmctl-test-container steamvmctl-test)
echo "容器 ID: $CONTAINER_ID"
echo "✅ 容器启动成功"
echo ""

# 等待容器启动
sleep 2

# 运行安装脚本（模拟用户输入）
echo "[3/6] 运行 install.sh..."
docker exec -i $CONTAINER_ID bash -c 'cd /test && { echo "100"; sleep 0.3; echo "8080"; sleep 0.3; } | ./install.sh' || {
    echo "❌ install.sh 执行失败"
    docker logs $CONTAINER_ID 2>/dev/null || true
    docker stop $CONTAINER_ID >/dev/null 2>&1 || true
    docker rm $CONTAINER_ID >/dev/null 2>&1 || true
    exit 1
}
echo ""

# 验证安装结果
echo "[4/6] 验证安装结果..."

# 检查二进制文件
if docker exec $CONTAINER_ID test -x /usr/local/bin/steamvmctl; then
    echo "✅ 二进制文件已安装到 /usr/local/bin/steamvmctl"
else
    echo "❌ 二进制文件未安装"
fi

# 检查服务文件
if docker exec $CONTAINER_ID test -f /etc/systemd/system/steamvmctl.service; then
    echo "✅ 服务文件已创建"
    echo ""
    echo "服务文件内容:"
    docker exec $CONTAINER_ID cat /etc/systemd/system/steamvmctl.service
else
    echo "⚠️ 服务文件未创建（环境中无 systemd，这是正常的）"
fi
echo ""

# 手动启动服务测试
echo "[5/6] 手动启动服务并测试 API..."

# 从服务文件中读取环境变量
VMID=$(docker exec $CONTAINER_ID grep 'Environment="VMID=' /etc/systemd/system/steamvmctl.service 2>/dev/null | head -1 | sed 's/.*VMID=\([^"]*\).*/\1/')
TOKEN=$(docker exec $CONTAINER_ID grep 'Environment="TOKEN=' /etc/systemd/system/steamvmctl.service 2>/dev/null | head -1 | sed 's/.*TOKEN=\([^"]*\).*/\1/')
PORT=$(docker exec $CONTAINER_ID grep 'Environment="PORT=' /etc/systemd/system/steamvmctl.service 2>/dev/null | head -1 | sed 's/.*PORT=\([^"]*\).*/\1/')

if [ -z "$TOKEN" ]; then
    echo "❌ 无法从服务文件读取 TOKEN"
else
    echo "Token: $TOKEN"
    echo "Port: $PORT"
    echo "VMID: $VMID"
    echo ""
    
    # 在后台启动服务
    docker exec -d $CONTAINER_ID bash -c "export VMID=$VMID; export TOKEN=$TOKEN; export PORT=$PORT; /usr/local/bin/steamvmctl"
    
    # 等待服务启动
    sleep 2
    
    # 测试 API
    echo "测试 API 端点:"
    
    # 测试状态接口
    echo -n "  - /status: "
    STATUS_RESPONSE=$(docker exec $CONTAINER_ID curl -s "http://127.0.0.1:$PORT/status?token=$TOKEN" 2>/dev/null || echo "FAILED")
    echo "$STATUS_RESPONSE"
    
    # 测试启动接口
    echo -n "  - /start: "
    START_RESPONSE=$(docker exec $CONTAINER_ID curl -s "http://127.0.0.1:$PORT/start?token=$TOKEN" 2>/dev/null || echo "FAILED")
    echo "$START_RESPONSE"
    
    # 测试停止接口
    echo -n "  - /stop: "
    STOP_RESPONSE=$(docker exec $CONTAINER_ID curl -s "http://127.0.0.1:$PORT/stop?token=$TOKEN" 2>/dev/null || echo "FAILED")
    echo "$STOP_RESPONSE"
    
    # 测试无效 token
    echo -n "  - 无效 token 测试: "
    INVALID_RESPONSE=$(docker exec $CONTAINER_ID curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/status?token=wrong" 2>/dev/null || echo "000")
    if [ "$INVALID_RESPONSE" == "403" ]; then
        echo "✅ 返回 403 Forbidden"
    else
        echo "❌ 期望 403，实际返回 $INVALID_RESPONSE"
    fi
fi
echo ""

# 运行卸载脚本
echo "[6/6] 运行 uninstall.sh..."
docker exec $CONTAINER_ID bash -c 'cd /test && ./uninstall.sh'
echo ""

# 验证卸载
if docker exec $CONTAINER_ID test -f /usr/local/bin/steamvmctl 2>/dev/null; then
    echo "❌ 卸载失败：二进制文件仍存在"
else
    echo "✅ 二进制文件已删除"
fi

if docker exec $CONTAINER_ID test -f /etc/systemd/system/steamvmctl.service 2>/dev/null; then
    echo "❌ 卸载失败：服务文件仍存在"
else
    echo "✅ 服务文件已删除"
fi

echo ""
echo "=== 集成测试完成 ==="

# 清理
if [ -n "$CONTAINER_ID" ]; then
    echo ""
    echo "清理容器..."
    docker stop $CONTAINER_ID >/dev/null 2>&1 || true
    docker rm $CONTAINER_ID >/dev/null 2>&1 || true
    echo "✅ 容器已清理"
fi
