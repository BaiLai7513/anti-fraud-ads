#!/system/bin/sh
# 模块更新检测脚本 - 对比本地版本 vs GitHub Release
MODDIR="${0%/*}"
[ "$MODDIR" = "." ] && MODDIR="/data/adb/modules/anti_fraud_ads"

LOCAL_VERSION=$(grep "version=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)
LOCAL_CODE=$(grep "versionCode=" "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2)

REPO_OWNER="BaiLai7513"
REPO_NAME="anti-fraud-ads"
API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    Anti-Fraud 模块更新检测          ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "本地版本: $LOCAL_VERSION ($LOCAL_CODE)"
echo ""

ping -c 1 -W 3 baidu.com >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️  无网络连接，无法检测"
    exit 1
fi

RESPONSE=$(curl -sL --connect-timeout 10 --max-time 15 "$API_URL" 2>/dev/null)
if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q "Not Found"; then
    echo "⚠️  无法获取 Release 信息"
    exit 1
fi

REMOTE_TAG=$(echo "$RESPONSE" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')
REMOTE_NAME=$(echo "$RESPONSE" | sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' | head -1)
REMOTE_BODY=$(echo "$RESPONSE" | sed -n 's/.*"body": *"\([^"]*\)".*/\1/p' | head -1)
DOWNLOAD_URL=$(echo "$RESPONSE" | sed -n 's/.*"browser_download_url": *"\([^"]*\)".*/\1/p' | head -1)

echo "最新版本: $REMOTE_TAG"
[ -n "$REMOTE_NAME" ] && echo "名称: $REMOTE_NAME"
echo ""

REMOTE_CODE=$(echo "$REMOTE_TAG" | grep -oE '[0-9]+' | head -1)
if [ "$LOCAL_CODE" -lt "$REMOTE_CODE" ] 2>/dev/null; then
    echo "🔔 有新版本可用！"
    [ -n "$REMOTE_BODY" ] && echo "更新内容: $REMOTE_BODY"
    echo ""
    echo "更新方法：Magisk 刷入新版 zip 即可"
else
    echo "✅ 已是最新版本"
fi
echo ""