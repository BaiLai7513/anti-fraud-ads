#!/system/bin/sh
# ============================================
# 实际效果检测脚本 — 反诈 + 去广告 + 冻结
# 用法: su -c "sh /data/adb/modules/anti_fraud_ads/check_privacy.sh"
# ============================================

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     实际效果检测 v260701                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""

PASS=0
FAIL=0
WARN=0

pass()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
warn()  { WARN=$((WARN+1)); echo "  ⚠️  $1"; }
check() { echo ""; echo "▸ $1"; echo "  ──────────────────────────"; }

# ===== 1. iptables DROP 规则 =====
check "1. iptables DROP 规则 (反诈IP封锁)"
count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
if [ "$count" -ge 100 ]; then
    pass "DROP 规则: $count 条 (正常)"
else
    fail "DROP 规则: $count 条 (预期 >= 100)"
fi

# ===== 2. iptables REDIRECT 劫持 =====
check "2. iptables REDIRECT 劫持"
redirect_count=$(iptables -t nat -L OUTPUT -n 2>/dev/null | grep -c "REDIRECT.*8848")
if [ "$redirect_count" -ge 1 ]; then
    pass "REDIRECT 规则: $redirect_count 条 -> :8848"
else
    fail "REDIRECT 规则: 0 条"
fi

# ===== 3. 冻结状态 =====
check "3. 系统组件冻结状态"
for pkg in com.oplus.thirdkit com.opos.ads; do
    if pm list packages -d 2>/dev/null | grep -q "$pkg"; then
        pass "$pkg 已冻结"
    else
        fail "$pkg 未冻结"
    fi
done

# ===== 4. hosts 去广告 =====
check "4. hosts 去广告"
for hosts_path in /data/adb/modules/anti-fraud-ads/system/etc/hosts /data/adb/modules/anti_fraud_ads/system/etc/hosts; do
    [ -f "$hosts_path" ] && break
done
if [ -f "$hosts_path" ]; then
    blocked=$(grep -c "0.0.0.0" "$hosts_path" 2>/dev/null || echo 0)
    sys_blocked=$(grep -c "0.0.0.0" /system/etc/hosts 2>/dev/null || echo 0)
    [ "$blocked" -gt 1000 ] && pass "模块 hosts: $blocked 条" || warn "模块 hosts: $blocked 条 (偏少)"
    [ "$sys_blocked" -gt 1000 ] && pass "系统 hosts: 已挂载 $sys_blocked 条" || warn "系统 hosts: $sys_blocked 条 (需重启)"
else
    fail "hosts 文件不存在"
fi

# ===== 5. 秋风规则 =====
check "5. 秋风广告规则 (AWAvenue-Ads-Rule)"
for p in /data/adb/modules/anti-fraud-ads/.awa_last_update /data/adb/modules/anti_fraud_ads/.awa_last_update; do
    [ -f "$p" ] && stamp_file="$p" && break
done
if [ -f "$stamp_file" ]; then
    last=$(cat "$stamp_file" 2>/dev/null)
    diff=$(($(date +%s) - last))
    days=$((diff / 86400))
    pass "上次更新: $(date -d @$last '+%F %T') (${days}d前 | 间隔7天)"
else
    warn "等待首次更新"
fi

# 汇总
echo ""
echo "╔══════════════════════════════════════════╗"
printf "║  检测完成: ✅%s  ❌%s  ⚠️%s" "$PASS" "$FAIL" "$WARN"
echo " ║"
echo "╚══════════════════════════════════════════╝"
[ "$FAIL" -gt 0 ] && echo "" && echo "⚠️  有 $FAIL 项异常，查看日志: cat /data/adb/modules/anti_fraud_ads/module.log"
[ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ] && echo "" && echo "🎉 所有防护正常！"
echo ""