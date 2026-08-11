#!/system/bin/sh
# 秋风广告规则 — 开机后检测一次，超过7天才更新 (v2 fixed)
MODDIR=${0%/*}
MODDIR="${MODDIR%/*}"
LOG="$MODDIR/module.log"
UPDATE_URL="https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
FALLBACK_URL="https://github.boki.moe/https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
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
        echo "[$(date)] update_rules: skip, next in ~${days}d${hours}h" >> $LOG
        exit 0
    fi
fi

# 等待网络
for i in $(seq 1 6); do
    ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && break
    sleep 10
done

echo "[$(date)] update_rules: fetching AWAvenue-Ads-Rule" >> $LOG

fetch_ok=false
for src in "$UPDATE_URL" "$FALLBACK_URL"; do
    echo "[$(date)] update_rules: trying $src" >> $LOG
    if curl -sL --connect-timeout 15 --max-time 30 -o /data/local/tmp/awa_new.txt "$src" 2>>$LOG; then
        new_lines=$(wc -l < /data/local/tmp/awa_new.txt)
        if [ "$new_lines" -gt 100 ]; then
            fetch_ok=true
            break
        fi
    fi
done

if $fetch_ok; then
    # 合并去重
    cat "$HOSTS_FILE" /data/local/tmp/awa_new.txt | sort -u > "$TMP_HOSTS"
    merged_lines=$(wc -l < "$TMP_HOSTS")
    echo "[$(date)] update_rules: merged $merged_lines lines" >> $LOG
    cp "$TMP_HOSTS" "$HOSTS_FILE" 2>>$LOG
    rm -f /data/local/tmp/awa_new.txt

    # 干净版挂载 hosts（同 service.sh：md5 幂等 + 直接 bind 模块文件，无残留）
    src_md5=$(md5sum "$HOSTS_FILE" 2>/dev/null | awk '{print $1}')
    sys_md5=$(md5sum /system/etc/hosts 2>/dev/null | awk '{print $1}')
    if [ -n "$src_md5" ] && [ "$src_md5" = "$sys_md5" ]; then
        echo "[$(date)] update_rules: hosts already active (md5 match)" >> $LOG
    else
        if mount -o bind "$HOSTS_FILE" /system/etc/hosts 2>>$LOG; then
            sys_md5=$(md5sum /system/etc/hosts 2>/dev/null | awk '{print $1}')
            if [ "$src_md5" = "$sys_md5" ]; then
                echo "[$(date)] update_rules: re-mounted hosts OK (md5=$src_md5)" >> $LOG
            else
                echo "[$(date)] update_rules: bind mounted but md5 mismatch" >> $LOG
            fi
        else
            echo "[$(date)] update_rules: bind mount FAILED" >> $LOG
        fi
    fi
    date +%s > "$STAMP"
else
    echo "[$(date)] update_rules: fetch FAILED" >> $LOG
fi