#!/system/bin/sh
# 屏蔽反诈+去广告 - 卸载脚本

echo "- 清除 iptables 规则..."
iptables -F OUTPUT
iptables -t nat -F OUTPUT

echo "- 恢复冻结应用..."
pm enable com.oplus.thirdkit 2>/dev/null
pm enable com.opos.ad 2>/dev/null

echo "- 注意: chattr +i 锁定的文件需手动恢复，或重启后 app 会重新创建"
echo "- 完成！"
