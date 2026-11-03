#!/system/bin/sh
# 屏蔽反诈+去广告 - 卸载脚本 (v3: 自动回滚)

MODDIR=${0%/*}

echo "- 回滚 ads_lock 修改..."
if [ -f "$MODDIR/mod/rollback.sh" ]; then
    sh "$MODDIR/mod/rollback.sh"
    rb_rc=$?
    if [ "$rb_rc" -ne 0 ]; then
        KEEP="/data/local/tmp/anti_fraud_ads_rollback_$(date +%s)"
        echo "- 回滚未完全成功，保留备份到: $KEEP"
        mkdir -p "$KEEP" 2>/dev/null
        cp -a "$MODDIR/backup/." "$KEEP/" 2>/dev/null
        echo "- 请按 $KEEP/state.tsv 手动恢复后再删除该目录"
    fi
else
    echo "- 警告: rollback.sh 缺失，无法自动恢复 ads_lock 修改"
fi

echo "- 清除模块 iptables 规则（不会执行 iptables -F）..."
if [ -f "$MODDIR/mod/iptables.sh" ]; then
    sh "$MODDIR/mod/iptables.sh" --cleanup
else
    echo "- 警告: iptables.sh 缺失，未清理规则"
fi

echo "- 停止后台更新进程..."
pkill -f "update_rules.sh" 2>/dev/null

echo "- 卸载 hosts bind mount..."
umount /system/etc/hosts 2>/dev/null
rm -f /data/local/tmp/hosts_block 2>/dev/null

echo "- 恢复冻结应用..."
pm enable com.oplus.thirdkit 2>/dev/null
pm enable com.opos.ads 2>/dev/null

echo "- 完成！"
