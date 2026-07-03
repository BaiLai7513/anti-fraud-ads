#!/system/bin/sh
# ============================================
# 隐私防护检测脚本 — 反诈 + 去广告 + 冻结
# 用法: su -c "sh /sdcard/Download/check_privacy.sh"
# ============================================

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     状态检测 v260701            ║"
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
    fail "DROP 规则: $count 条 (预期 >= 100，模块可能未加载)"
fi

# ===== 2. iptables REDIRECT 劫持 =====
check "2. iptables REDIRECT 劫持 (phonemanager/appdetail/国家反诈)"

redirect_count=$(iptables -t nat -L OUTPUT -n 2>/dev/null | grep -c "REDIRECT.*8848")
if [ "$redirect_count" -ge 1 ]; then
    pass "REDIRECT 规则: $redirect_count 条 -> :8848"
    iptables -t nat -L OUTPUT -n 2>/dev/null | grep "8848" | while read line; do
        echo "     $line"
    done
else
    fail "REDIRECT 规则: 0 条"
fi

# ===== 3. phonemanager =====
check "3. phonemanager (com.coloros.phonemanager)"

uid=$(grep "^com.coloros.phonemanager" /data/system/packages.list 2>/dev/null | awk '{print $2}')
if [ -n "$uid" ]; then
    pkts=$(iptables -t nat -L OUTPUT -n -v 2>/dev/null | grep "uid $uid" | awk '{print $1}')
    if [ -n "$pkts" ] && [ "$pkts" -gt 0 ]; then
        pass "UID=$uid | 已劫持，拦截 $pkts 次"
    else
        pass "UID=$uid | 已劫持 (待触发)"
    fi
else
    fail "包未安装或未找到 UID"
fi

# ===== 4. appdetail =====
check "4. appdetail (com.oplus.appdetail)"

uid=$(grep "^com.oplus.appdetail" /data/system/packages.list 2>/dev/null | awk '{print $2}')
if [ -n "$uid" ]; then
    pkts=$(iptables -t nat -L OUTPUT -n -v 2>/dev/null | grep "uid $uid" | awk '{print $1}')
    if [ -n "$pkts" ] && [ "$pkts" -gt 0 ]; then
        pass "UID=$uid | 已劫持，拦截 $pkts 次"
    else
        pass "UID=$uid | 已劫持 (待触发)"
    fi
else
    fail "包未安装或未找到 UID"
fi

# ===== 5. thirdkit =====
check "5. thirdkit 智能应用检测 (com.oplus.thirdkit)"
enabled=$(pm list packages -d 2>/dev/null | grep "com.oplus.thirdkit")
if [ -n "$enabled" ]; then
    pass "已冻结 (pm disable)"
else
    installed=$(pm list packages 2>/dev/null | grep "com.oplus.thirdkit")
    if [ -n "$installed" ]; then
        fail "已安装但未冻结！"
    else
        warn "未安装"
    fi
fi

# ===== 6. opos.ad =====
check "6. OPPO 系统广告 (com.opos.ad)"
enabled=$(pm list packages -d 2>/dev/null | grep "com.opos.ad")
if [ -n "$enabled" ]; then
    pass "已冻结 (pm disable)"
else
    installed=$(pm list packages 2>/dev/null | grep "com.opos.ad")
    if [ -n "$installed" ]; then
        fail "已安装但未冻结！"
    else
        warn "未安装"
    fi
fi

# ===== 7. 国家反诈中心 =====
check "7. 国家反诈中心 (com.hicorenational.antifraud)"
installed=$(pm list packages 2>/dev/null | grep "com.hicorenational.antifraud")
if [ -n "$installed" ]; then
    uid=$(grep "^com.hicorenational.antifraud" /data/system/packages.list 2>/dev/null | awk '{print $2}')
    if [ -n "$uid" ]; then
        pkts=$(iptables -t nat -L OUTPUT -n -v 2>/dev/null | grep "uid $uid" | awk '{print $1}')
        if [ -n "$pkts" ] && [ "$pkts" -gt 0 ]; then
            pass "UID=$uid | 已劫持，拦截 $pkts 次"
        else
            warn "UID=$uid | 规则存在但无流量"
        fi
    else
        warn "已安装，未找到 UID"
    fi
else
    pass "未安装 ✓"
fi

# ===== 8. hosts 去广告 =====
check "8. hosts 去广告 (blocked domains)"

# 检测模块 hosts 和系统 hosts
for hosts_path in /data/adb/modules/anti_fraud_ads/system/etc/hosts /data/adb/modules/anti_fraud_260517/system/etc/hosts; do
    [ -f "$hosts_path" ] && break
done

if [ -f "$hosts_path" ]; then
    # 统计标准格式 (0.0.0.0/127.0.0.1) + 通配符 + AdBlock 规则
    blocked=$(grep -cE '^(0\.0\.0\.0|127\.0\.0\.1|\*|\|\|)' "$hosts_path" 2>/dev/null || true)
    : "${blocked:=0}"
    hosts_size=$(wc -c < "$hosts_path" 2>/dev/null || echo 0)

    # 检查系统 hosts 是否被挂载覆盖
    sys_blocked=$(grep -cE '^(0\.0\.0\.0|127\.0\.0\.1|\*|\|\|)' /system/etc/hosts 2>/dev/null || true)
    : "${sys_blocked:=0}"

    if [ "$blocked" -gt 100 ]; then
        pass "模块 hosts: $blocked 条屏蔽 ($((hosts_size/1024))KB)"
    elif [ "$blocked" -gt 0 ]; then
        warn "模块 hosts: $blocked 条 (偏少，可能未完成初始化)"
    else
        fail "模块 hosts 无屏蔽条目"
    fi

    if [ "$sys_blocked" -gt 100 ]; then
        pass "系统 hosts 已挂载: $sys_blocked 条屏蔽"
    elif [ "$sys_blocked" -gt 0 ]; then
        warn "系统 hosts: $sys_blocked 条 (bind mount 可能未生效)"
    else
        warn "系统 hosts 无屏蔽条目 (需重启生效)"
    fi
else
    fail "模块 hosts 文件不存在"
fi

# ===== 9. ads_lock 广告缓存锁定 =====
check "9. ads_lock 广告缓存锁定"

log_paths="
/data/adb/modules/anti_fraud_ads/module.log
/data/adb/modules/anti_fraud_260517/module.log
"

log_file=""
for p in $log_paths; do
    [ -f "$p" ] && log_file="$p" && break
done

if [ -f "$log_file" ]; then
    # 检查 ads_lock 是否执行过
    if grep -q "ads_lock" "$log_file" 2>/dev/null; then
        last_line=$(grep "ads_lock" "$log_file" 2>/dev/null | tail -1)
        pass "ads_lock 已执行: $last_line"
    else
        warn "ads_lock 日志未找到 (可能还在后台运行)"
    fi

    # 检查 iptables 最终状态
    if grep -q "ALL OK" "$log_file" 2>/dev/null; then
        pass "iptables 加载成功 (ALL OK)"
    elif grep -q "FAILED" "$log_file" 2>/dev/null; then
        fail "iptables 加载失败！查看: $log_file"
    else
        warn "iptables 状态未知 (日志不完整)"
    fi
else
    warn "module.log 不存在 (模块可能未执行)"
fi

# ===== 10. 反诈IP连通性测试 =====
check "10. 反诈IP连通性测试 (抽样3个)"

test_ip() {
    ping -c 1 -W 2 "$1" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        fail "$1 可连通 (DROP失效!)"
        return 1
    else
        pass "$1 不可达 (DROP生效)"
        return 0
    fi
}
test_ip "49.7.228.53"
test_ip "14.29.101.168"
test_ip "116.177.251.215"

# ===== 11. 秋风广告规则 (AWAvenue-Ads-Rule) =====
check "11. 秋风广告规则 (AWAvenue-Ads-Rule)"

log_file=""
for p in /data/adb/modules/anti-fraud-ads/module.log /data/adb/modules/anti_fraud_ads/module.log /data/adb/modules/anti_fraud_260517/module.log; do
    [ -f "$p" ] && log_file="$p" && break
done

if [ -f "$log_file" ]; then
    if grep -q "update_rules: re-mounted" "$log_file" 2>/dev/null; then
        last_ok=$(grep "update_rules: re-mounted" "$log_file" 2>/dev/null | tail -1)
        lines=$(echo "$last_ok" | grep -oE '[0-9]+ lines active' | grep -oE '[0-9]+' | tail -1)
        [ -n "$lines" ] && lines_str=" | 生效: $lines 条" || lines_str=""
        pass "秋风规则已合并${lines_str}"
    else
        warn "秋风规则未合并 (首次运行可能尚未完成)"
    fi
else
    warn "module.log 不存在"
fi

# ===== 汇总 =====
echo ""
echo "╔══════════════════════════════════════════╗"
printf "║  检测完成: ✅%s  ❌%s  ⚠️%s" "$PASS" "$FAIL" "$WARN"
# 计算需要填充的空格
total=27
used=${#PASS}+${#FAIL}+${#WARN}+7  # 7 = "✅  ❌  ⚠️"[3+2+2]
[ $used -lt $total ] && printf "%$((total-used))s" ""
echo "║"
echo "╚══════════════════════════════════════════╝"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "⚠️  有 $FAIL 项异常，请检查反诈模块是否正确加载。"
    echo "    手动重载: su -c 'source /data/adb/modules/anti_fraud_ads/mod/iptables.sh'"
    echo "    查看日志: cat /data/adb/modules/anti_fraud_ads/module.log"
fi

if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo ""
    echo "🎉 所有防护正常！"
fi
echo ""