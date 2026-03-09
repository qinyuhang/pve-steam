# Steam VM Control

通过 HTTP API 在局域网内一键控制 PVE (Proxmox VE) 上的 Windows/Steam 虚拟机。

## 背景

家里的 NAS 上跑 Windows 玩游戏，但每次启动都要：
1. 登录 PVE Web 面板
2. 输入 2FA 验证码  
3. 找到 VM 点击启动

太麻烦了！本项目让你躺在沙发上用手机一键启动 VM。

## 功能

- 🚀 HTTP API 控制 VM 启动/停止/状态查询
- 🔒 Token 认证保护
- 🔄 Systemd 服务自动保活
- 📱 手机浏览器/快捷指令直接操作

## 安装

### 一键安装（推荐）

在 **PVE 节点**上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/qinyuhang/pve-steam/main/install.sh | bash
```

安装过程中会提示输入：
- **VM ID**: 要控制的虚拟机 ID（可通过 `qm list` 查看）
- **Port**: 服务监听端口（默认 8080）

安装完成后会显示 Token 和 API 地址，**请保存好 Token**！

### 本地安装

```bash
git clone https://github.com/qinyuhang/pve-steam.git
cd pve-steam
./install.sh
```

## 使用

### API 端点

假设 PVE 节点 IP 是 `192.168.1.100`，服务运行在 `8080` 端口，Token 为 `abc123`：

| 操作 | 请求 |
|------|------|
| 查询状态 | `curl http://192.168.1.100:8080/status?token=abc123` |
| 启动 VM | `curl http://192.168.1.100:8080/start?token=abc123` |
| 停止 VM | `curl http://192.168.1.100:8080/stop?token=abc123` |

### 手机快捷方式

iOS/Android 创建桌面快捷方式，URL 设为：
```
http://192.168.1.100:8080/start?token=你的token
```

躺在沙发上点一下，电脑就开了！🛋️

### iOS 快捷指令（进阶）

可以配合 iOS 快捷指令实现：
- 语音控制："嘿 Siri，开电脑"
- 自动化：连上家里 WiFi 时弹出快捷按钮

快捷指令配置文件在 `shortcuts/` 目录：
- `import.html` - 网页配置工具，填入 IP/Token 即可生成配置
- `generate_shortcut.sh` - 自动生成脚本
- `README.md` - 详细教程

## 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/qinyuhang/pve-steam/main/uninstall.sh | bash
```

或本地执行：
```bash
./uninstall.sh
```

## 服务管理

```bash
# 查看状态
sudo systemctl status steamvmctl

# 查看日志
sudo journalctl -u steamvmctl -f

# 重启服务
sudo systemctl restart steamvmctl

# 停止服务
sudo systemctl stop steamvmctl
```

## 外网访问（可选）

> 谁家好人半路上开电脑？

如果你确实有外网访问需求，建议配合反向代理 + HTTPS：

```nginx
location /vm/ {
    auth_basic "VM Control";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://127.0.0.1:8080/;
}
```

**⚠️ 注意**：直接暴露到公网风险自负，务必做好防护！

## 开发

```bash
# 本地运行测试
go test -v ./...

# 构建
go build -o steamvmctl main.go

# 集成测试（需要 Docker）
./test-integration.sh
```

## 安全提示

- 本项目设计用于**可信局域网环境**
- Token 是唯一的认证方式，请妥善保管
- 建议设置防火墙规则，限制只有特定 IP 能访问
