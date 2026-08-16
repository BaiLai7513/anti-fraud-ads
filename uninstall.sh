#!/system/bin/sh
# 屏蔽反诈+去广告 - 卸载脚本 (v2 fixed)

echo "- 清除 iptables 规则..."
iptables -F OUTPUT
iptables -t nat -F OUTPUT

echo "- 停止后台更新进程..."
pkill -f "update_rules.sh" 2>/dev/null

echo "- 卸载 hosts bind mount..."
umount /system/etc/hosts 2>/dev/null
rm -f /data/local/tmp/hosts_block 2>/dev/null

echo "- 恢复冻结应用..."
pm enable com.oplus.thirdkit 2>/dev/null
pm enable com.opos.ads 2>/dev/null

echo "- 恢复123云盘/番茄/抖音/星饭团组件+系统广告服务(组件禁用层)..."
sh /data/adb/modules/anti_fraud_ads/mod/component_disable.sh restore 2>/dev/null

echo "- 注意: chattr +i 锁定的文件需手动恢复，或重启后 app 会重新创建"
echo "- 完成！"