#!/system/bin/sh
# 秋风广告规则 每日自动更新 & 合并
MODDIR=${0%/*}
MODDIR="${MODDIR%/*}"
LOG="$MODDIR/module.log"
UPDATE_URL="https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
HOSTS_FILE="$MODDIR/system/etc/hosts"
TMP_HOSTS="/data/local/tmp/awa_hosts_merged.txt"

echo "[$(date)] update_rules: daemon started, interval=86400s" >> $LOG

while true; do
    # 首次等待网络
    for i in $(seq 1 6); do
        ping -c 1 -W 3 baidu.com >/dev/null 2>&1 && break
        sleep 10
    done

    echo "[$(date)] update_rules: fetching AWAvenue-Ads-Rule" >> $LOG
    if curl -sL --connect-timeout 15 --max-time 30 -o /data/local/tmp/awa_new.txt "$UPDATE_URL"; then
        new_lines=$(wc -l < /data/local/tmp/awa_new.txt)
        echo "[$(date)] update_rules: fetched $new_lines lines" >> $LOG
        if [ "$new_lines" -gt 100 ]; then
            # 合并：原始 hosts + 秋风规则，去重
            cat "$HOSTS_FILE" /data/local/tmp/awa_new.txt | sort -u > "$TMP_HOSTS"
            merged_lines=$(wc -l < "$TMP_HOSTS")
            echo "[$(date)] update_rules: merged $merged_lines lines (base + AWA)" >> $LOG
            # 覆盖模块内 hosts
            cp "$TMP_HOSTS" "$HOSTS_FILE" 2>>$LOG
            # 重新 bind mount
            mount -o bind "$HOSTS_FILE" /system/etc/hosts 2>>$LOG
            echo "[$(date)] update_rules: re-mounted hosts ($(wc -l < /system/etc/hosts) lines active)" >> $LOG
        else
            echo "[$(date)] update_rules: too few lines ($new_lines), skip" >> $LOG
        fi
        rm -f /data/local/tmp/awa_new.txt
    else
        echo "[$(date)] update_rules: fetch FAILED" >> $LOG
    fi

    # 每天更新一次
    sleep 86400
done