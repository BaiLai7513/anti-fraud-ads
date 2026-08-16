#!/system/bin/sh
# 双源云端订阅 — hosts 自动更新 (v3.1 多源fallback)
# 源1: lingeringsound/10007/all 完整版        (hosts 格式, 直用)
# 源2: AWAvenue-Ads-Rule 秋风广告规则     (Adblock 格式, 转换后合并)
# 策略: 开机检测, 默认7天拉一次; hosts 为占位态(<1000行)时立即拉取
# 容错: 每个源带 3 条镜像链(raw -> boki.moe -> jsdelivr)，直连失败自动切换
MODDIR=${0%/*}
MODDIR="${MODDIR%/*}"
LOG="$MODDIR/module.log"

# 源1: 10007完整版 all 三镜像 (v1.3: reward→all 完整版)
ALL_URL="https://raw.githubusercontent.com/lingeringsound/10007/main/all"
ALL_FB1="https://github.boki.moe/https://raw.githubusercontent.com/lingeringsound/10007/main/all"
ALL_FB2="https://cdn.jsdelivr.net/gh/lingeringsound/10007@main/all"
# 源2: AWAvenue 三镜像
AWA_URL="https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
AWA_FB1="https://github.boki.moe/https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt"
AWA_FB2="https://cdn.jsdelivr.net/gh/TG-Twilight/AWAvenue-Ads-Rule@main/AWAvenue-Ads-Rule.txt"

HOSTS_FILE="$MODDIR/system/etc/hosts"
TMP_MERGED="/data/local/tmp/hosts_merged.txt"
STAMP="$MODDIR/.hosts_update_stamp"
STAMP_DAYS=7

# 多源拉取: 依次尝试, 成功即返回
fetch_one() {
    local out="$1"; shift
    for u in "$@"; do
        if curl -sL --connect-timeout 15 --max-time 40 -o "$out" "$u" 2>>$LOG; then
            echo "[$(date)] update_rules: fetched OK from $u" >> $LOG
            return 0
        fi
    done
    return 1
}

echo "[$(date)] update_rules: cloud subscribe check" >> $LOG

# 当前 hosts 行数
CUR_N=$(wc -l < "$HOSTS_FILE" 2>/dev/null || echo 0)

# 7天间隔检查（仅当 hosts 已是完整规则时跳过）
if [ "$CUR_N" -ge 1000 ] && [ -f "$STAMP" ]; then
    last=$(cat "$STAMP" 2>/dev/null)
    now=$(date +%s)
    diff=$((now - last))
    if [ -n "$last" ] && [ "$diff" -ge 0 ] && [ "$diff" -lt $((STAMP_DAYS * 86400)) ]; then
        remain=$(((STAMP_DAYS * 86400) - diff))
        echo "[$(date)] update_rules: skip, next in ~$((remain / 86400))d (hosts=${CUR_N}行)" >> $LOG
        exit 0
    fi
fi

# 等待网络
for i in $(seq 1 6); do
    ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && break
    sleep 10
done

echo "[$(date)] update_rules: fetching cloud rules (all + AWAvenue)" >> $LOG
fetch_ok=false

# 源1: all 完整版 (hosts 格式)
if fetch_one /data/local/tmp/reward_raw.txt "$ALL_URL" "$ALL_FB1" "$ALL_FB2"; then
    n=$(grep -vcE '^#|^[[:space:]]*$' /data/local/tmp/reward_raw.txt)
    echo "[$(date)] update_rules: all fetched ($n 有效行)" >> $LOG
    [ "$n" -gt 100 ] && fetch_ok=true
fi

# 源2: AWAvenue (Adblock -> hosts)
if fetch_one /data/local/tmp/awa_raw.txt "$AWA_URL" "$AWA_FB1" "$AWA_FB2"; then
    sed -n 's/^||\([^/^*]*\)\^$/0.0.0.0 \1/p' /data/local/tmp/awa_raw.txt \
        | grep -vE '^[[:space:]]*$' > /data/local/tmp/awa_hosts.txt
    n=$(wc -l < /data/local/tmp/awa_hosts.txt)
    echo "[$(date)] update_rules: AWAvenue fetched (转换 $n 条)" >> $LOG
    [ "$n" -gt 50 ] && fetch_ok=true
fi

if $fetch_ok; then
    # 合并去重: 基础占位 + all(保留注释) + AWAvenue(已转换) + CN补丁
    # 过滤小米相关条目(OPPO用户不需要)
    # IPv6双写: 所有 0.0.0.0 条目同时输出 :: (防IPv6绕过, v1.2)
    {
        echo "127.0.0.1 localhost"
        echo "::1 localhost"
        echo "::1 ip6-loopback"
        echo "::1 ip6-localhost"
        cat /data/local/tmp/reward_raw.txt 2>/dev/null
        cat /data/local/tmp/awa_hosts.txt 2>/dev/null
        cat "$MODDIR/mod/cn_ad_patch.txt" 2>/dev/null
    } | grep -vE '^[[:space:]]*$' | grep -viE 'miui|xiaomi|(^|\.)mi\.com$|huawei|vivo\.com|samsung|hihonor|flyme|meizu|lenovo' \
      | awk '{ if ($1=="0.0.0.0" && $2!="") { print; print ":: " $2 } else print }' \
      | sort -u > "$TMP_MERGED"
    merged=$(wc -l < "$TMP_MERGED")

    # 国内环境优化: 注释国外大厂广告域名 (v260818, 静态列表安全不误伤)
    # 列表: mod/abroad_domains.txt (google/amazon-adsystem/apple/microsoft/yahoo等246个)
    # 效果: 域名保留在文件中但加#前缀, 不参与解析; 下次更新自动执行
    ABROAD="$MODDIR/mod/abroad_domains.txt"
    if [ -f "$ABROAD" ]; then
        awk 'NR==FNR{a[$0]=1;next} {if($2 in a) print "#"$0; else print $0}' "$ABROAD" "$TMP_MERGED" > "$TMP_MERGED.cn" 2>>$LOG
        mv "$TMP_MERGED.cn" "$TMP_MERGED"
        commented=$(grep -c '^#' "$TMP_MERGED")
        echo "[$(date)] update_rules: 国内优化 注释国外域名行=$commented" >> $LOG
    fi

    echo "[$(date)] update_rules: merged $merged 行" >> $LOG
    cp "$TMP_MERGED" "$HOSTS_FILE" 2>>$LOG
    rm -f /data/local/tmp/reward_raw.txt /data/local/tmp/awa_raw.txt /data/local/tmp/awa_hosts.txt

    # 干净版挂载 hosts（md5 幂等 + 直接 bind 模块文件, 无残留）
    src_md5=$(md5sum "$HOSTS_FILE" 2>/dev/null | awk '{print $1}')
    sys_md5=$(md5sum /system/etc/hosts 2>/dev/null | awk '{print $1}')
    if [ -n "$src_md5" ] && [ "$src_md5" = "$sys_md5" ]; then
        echo "[$(date)] update_rules: hosts already active (md5 match, ${merged}行)" >> $LOG
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
    echo "[$(date)] update_rules: fetch FAILED, keep existing hosts (${CUR_N}行)" >> $LOG
fi