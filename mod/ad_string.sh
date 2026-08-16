#!/system/bin/sh
# iptables string 匹配层 v1.1 — 补充 hosts 无法覆盖的场景
# 原理: iptables -m string 匹配流量内容中的广告域名特征, 直接 DROP
# 优势: 1) 子域通配(hosts需精确写子域)  2) 防 HTTPDNS 绕过(流量内容匹配, 与DNS无关)
# 清单: 123云盘tcpdump实测广告SDK域名(小众, 误伤概率极低) + 高置信度路径特征
# v1.1: 注释移出列表, 避免分词误加为规则
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

# string匹配清单: 纯域名/路径, 禁止注释行混入(避免分词误加规则)
string_list='
zhangyuyidong.cn
adhuanxiao.com
aiyituo.com
aishuttler.com
anythinktech.com
metricslinks.com
statisticslinks.com
gdt.qq.com
pgdt.gtimg.cn
pgdt.ugdtimg.com
sdk.e.qq.com
gw.365you.com
fdkss.sbs
/advertise
/ad_request
/ads-sdk
/splash_ad
/reward_video
'

added=0
failed=0

for s in $string_list; do
    [ -z "$s" ] && continue
    # 先删后加(幂等)
    iptables -D OUTPUT -m string --string "$s" --algo bm --to 65535 -j DROP 2>/dev/null
    if iptables -A OUTPUT -m string --string "$s" --algo bm --to 65535 -j DROP 2>>"$LOG"; then
        added=$((added + 1))
    else
        failed=$((failed + 1))
    fi
done

echo "[$(date)] ad_string: added=$added failed=$failed" >> "$LOG"