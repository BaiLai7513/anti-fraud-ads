#!/system/bin/sh
# 反检测层 v1.0 — 反制假系统包 (移植自"去广告-特别版" kii_fdkss.sbs.sh)
# 原理: 检测工具伪装成系统应用(com.android.append/bin.mt.plus.termex)探测模块存在,
#       发现后 pm clear+disable+hide 反制 (假包无真实功能, hide无副作用)
# 配套: 检测服务器域名 fdkss.sbs 由 ad_string.sh 用 iptables string 拦截
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

FAKE_PKGS="com.android.append bin.mt.plus.termex"

# 清理伪装APK (检测工具伪装成系统应用)
rm -f /data/adb/modules/*/system/priv-app/zygisk/zygisk.apk 2>/dev/null
rm -f /data/adb/modules/*/system/priv-app/*/termux.apk 2>/dev/null

found=0
for p in $FAKE_PKGS; do
    if pm list packages "$p" 2>/dev/null | grep -qF "package:$p"; then
        found=$((found + 1))
        pm clear "$p" >/dev/null 2>&1
        pm disable "$p" >/dev/null 2>&1
        pm hide "$p" >/dev/null 2>&1
        echo "[$(date)] anti_detect: 反制假系统包 $p (clear+disable+hide)" >> "$LOG"
    fi
done

echo "[$(date)] anti_detect: 检查完成 发现假包=$found" >> "$LOG"