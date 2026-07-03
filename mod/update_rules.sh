#!/system/bin/sh
# 秋风广告规则 — 开机后检测一次，超过7天才更新
MODDIR=${0%/*}
MODDIR="${MODDIR%/*}"
LOG="$MODDIR/module.log"
UPDATE_URL="https://github.boki.moe/https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
HOSTS_FILE="$MODDIR/system/etc/hosts"
TMP_HOSTS="/data/local/tmp/awa_hosts_merged.txt"
STAMP="$MODDIR/.awa_last_update"

echo "[$(date)] update_rules: boot check, 7-day interval" >> $LOG

if [ -f "$STAMP" ]; then
    last=$(cat "$STAMP" 2>/dev/null)
    now=$(date +%s)
    diff=$((now - last))
    if [ -n "$last" ] && [ "$diff" -ge 0 ] && [ "$diff" -lt 604800 ]; then
        remain=$((604800 - diff))
        days=$((remain / 86400))
        hours=$(((remain % 86400) / 3600))
        echo "[$(date)] update_rules: skip, last update was $(date -d @$last '+%F %T'), next in ~${days}d${hours}h" >> $LOG
        exit 0
    fi
fi

for i in $(seq 1 6); do
    ping -c 1 -W 3 baidu.com >/dev/null 2>&1 && break
    sleep 10
done

echo "[$(date)] update_rules: fetching AWAvenue-Ads-Rule" >> $LOG
if curl -sL --connect-timeout 15 --max-time 30 -o /data/local/tmp/awa_new.txt "$UPDATE_URL"; then
    new_lines=$(wc -l < /data/local/tmp/awa_new.txt)
    echo "[$(date)] update_rules: fetched $new_lines lines" >> $LOG
    if [ "$new_lines" -gt 100 ]; then
        cat "$HOSTS_FILE" /data/local/tmp/awa_new.txt | sort -u > "$TMP_HOSTS"
        merged_lines=$(wc -l < "$TMP_HOSTS")
        echo "[$(date)] update_rules: merged $merged_lines lines (base + AWA)" >> $LOG
        cp "$TMP_HOSTS" "$HOSTS_FILE" 2>>$LOG
        mount -o bind "$HOSTS_FILE" /system/etc/hosts 2>>$LOG
        echo "[$(date)] update_rules: re-mounted hosts ($(wc -l < /system/etc/hosts) lines active)" >> $LOG
        date +%s > "$STAMP"
    else
        echo "[$(date)] update_rules: too few lines ($new_lines), skip" >> $LOG
    fi
    rm -f /data/local/tmp/awa_new.txt
else
    echo "[$(date)] update_rules: fetch FAILED" >> $LOG
fi
