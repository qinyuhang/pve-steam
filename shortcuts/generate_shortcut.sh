#!/bin/bash

# 生成 iOS 快捷指令文件
# 用法: ./generate_shortcut.sh <PVE_IP> <PORT> <TOKEN>

set -e

if [ $# -ne 3 ]; then
    echo "用法: $0 <PVE_IP> <PORT> <TOKEN>"
    echo "示例: $0 192.168.1.100 8080 abc123xyz"
    exit 1
fi

PVE_IP=$1
PORT=$2
TOKEN=$3

echo "=== 生成 iOS 快捷指令 ==="
echo "PVE IP: $PVE_IP"
echo "端口: $PORT"
echo "Token: ${TOKEN:0:10}..."
echo ""

# 创建临时目录
TMPDIR=$(mktemp -d)

# 创建快捷指令的 plist 内容
cat > "$TMPDIR/Shortcut.plist" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>WFWorkflowClientVersion</key>
    <string>1092.0.2</string>
    <key>WFWorkflowClientRelease</key>
    <string>4.0</string>
    <key>WFWorkflowMinimumClientVersion</key>
    <integer>900</integer>
    <key>WFWorkflowMinimumClientVersionString</key>
    <string>900</string>
    <key>WFWorkflowIcon</key>
    <dict>
        <key>WFWorkflowIconStartColor</key>
        <integer>4292093695</integer>
        <key>WFWorkflowIconGlyphNumber</key>
        <integer>61602</integer>
    </dict>
    <key>WFWorkflowImportQuestions</key>
    <array/>
    <key>WFWorkflowTypes</key>
    <array>
        <string>NCWidget</string>
        <string>WatchKit</string>
    </array>
    <key>WFWorkflowInputContentItemClasses</key>
    <array>
        <string>WFAppStoreAppContentItem</string>
        <string>WFArticleContentItem</string>
        <string>WFContactContentItem</string>
        <string>WFDateContentItem</string>
        <string>WFEmailAddressContentItem</string>
        <string>WFGenericFileContentItem</string>
        <string>WFImageContentItem</string>
        <string>WFiTunesProductContentItem</string>
        <string>WFLocationContentItem</string>
        <string>WFDCMapsLinkContentItem</string>
        <string>WFAVAssetContentItem</string>
        <string>WFPDFContentItem</string>
        <string>WFPhoneNumberContentItem</string>
        <string>WFRichTextContentItem</string>
        <string>WFSafariWebPageContentItem</string>
        <string>WFStringContentItem</string>
        <string>WFURLContentItem</string>
    </array>
    <key>WFWorkflowActions</key>
    <array>
        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>is.workflow.actions.geturl</string>
            <key>WFWorkflowActionParameters</key>
            <dict>
                <key>WFURLActionURL</key>
                <dict>
                    <key>Value</key>
                    <dict>
                        <key>string</key>
                        <string>__URL__</string>
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFTextTokenString</string>
                </dict>
                <key>WFHTTPMethod</key>
                <string>GET</string>
            </dict>
        </dict>
        <dict>
            <key>WFWorkflowActionIdentifier</key>
            <string>is.workflow.actions.showresult</string>
            <key>WFWorkflowActionParameters</key>
            <dict>
                <key>Text</key>
                <dict>
                    <key>Value</key>
                    <dict>
                        <key>string</key>
                        <string>已发送启动命令！</string>
                    </dict>
                    <key>WFSerializationType</key>
                    <string>WFTextTokenString</string>
                </dict>
            </dict>
        </dict>
    </array>
    <key>WFWorkflowName</key>
    <string>开电脑</string>
</dict>
</plist>
PLISTEOF

# 替换 URL
START_URL="http://$PVE_IP:$PORT/start?token=$TOKEN"
STOP_URL="http://$PVE_IP:$PORT/stop?token=$TOKEN"
STATUS_URL="http://$PVE_IP:$PORT/status?token=$TOKEN"

# 生成开电脑快捷指令
sed "s|__URL__|$START_URL|g" "$TMPDIR/Shortcut.plist" > "$TMPDIR/开电脑.plist"

# 生成关电脑快捷指令  
sed "s|__URL__|$STOP_URL|g" "$TMPDIR/Shortcut.plist" > "$TMPDIR/关电脑.plist"
sed -i '' 's/开电脑/关电脑/g' "$TMPDIR/关电脑.plist" 2>/dev/null || sed -i 's/开电脑/关电脑/g' "$TMPDIR/关电脑.plist"
sed -i '' 's/启动命令/停止命令/g' "$TMPDIR/关电脑.plist" 2>/dev/null || sed -i 's/启动命令/停止命令/g' "$TMPDIR/关电脑.plist"

# 转换为 base64（因为 .shortcut 文件实际上是 plist 的二进制格式）
echo "生成 base64 编码文件..."
echo ""

# 对于真正的 iOS 快捷指令，需要使用 Apple 的格式
# 这里我们生成一个可以直接复制到 iOS 的 URL scheme

echo "=== 生成的快捷指令配置 ==="
echo ""

# 生成 shortcuts:// URL
echo "【开电脑】"
echo "URL Scheme:"
echo "shortcuts://create-shortcut?name=开电脑&actions=%5B%7B%22WFWorkflowActionIdentifier%22%3A%22is.workflow.actions.geturl%22%2C%22WFWorkflowActionParameters%22%3A%7B%22WFURLActionURL%22%3A%7B%22Value%22%3A%7B%22string%22%3A%22$(echo "$START_URL" | sed 's/:/%3A/g; s/\//%2F/g; s/?/%3F/g; s/=/%3D/g; s/&/%26/g')%22%7D%7D%7D%7D%5D"
echo ""

# 生成二维码（如果 qrencode 存在）
if command -v qrencode &> /dev/null; then
    echo "生成二维码..."
    echo "$START_URL" | qrencode -t ANSIUTF8 -o -
    echo ""
fi

# 清理
rm -rf "$TMPDIR"

echo "✅ 完成！"
echo ""
echo "使用方法："
echo "1. 打开 iOS 快捷指令 App"
echo "2. 创建新快捷指令"
echo "3. 添加'获取 URL 内容'操作"
echo "4. URL: $START_URL"
echo "5. 添加到主屏幕"
