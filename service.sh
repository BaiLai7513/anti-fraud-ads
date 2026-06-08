#!/system/bin/sh
# 屏蔽反诈+去广告 - 开机自启
MODDIR=${0%/*}
LOG="$MODDIR/module.log"

# 初始化日志
echo "=== $(date) service.sh started ===" >> $LOG

# ===== 阶段1: 等待系统就绪 =====
echo "[$(date)] Phase1: waiting for boot_completed" >> $LOG
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
echo "[$(date)] Phase1: boot_completed OK" >> $LOG

# 等待网络就绪
echo "[$(date)] Phase1: waiting for network" >> $LOG
for i in $(seq 1 12); do
    ping -c 1 -W 3 baidu.com >/dev/null 2>&1 && break
    sleep 5
done
echo "[$(date)] Phase1: network check done (attempt $i)" >> $LOG

# 等待 iptables 读操作就绪
echo "[$(date)] Phase1: waiting for iptables readability" >> $LOG
for i in $(seq 1 20); do
    iptables -L OUTPUT -n >/dev/null 2>&1 && break
    sleep 3
done
echo "[$(date)] Phase1: iptables readable (attempt $i)" >> $LOG

# 等待 iptables 写操作就绪
echo "[$(date)] Phase1: waiting for iptables write capability" >> $LOG
for i in $(seq 1 30); do
    if iptables -A OUTPUT -d 127.0.0.253 -j DROP 2>>$LOG; then
        iptables -D OUTPUT -d 127.0.0.253 -j DROP 2>>$LOG
        break
    fi
    sleep 3
done
echo "[$(date)] Phase1: iptables writable (attempt $i)" >> $LOG

# ===== 阶段1.5: hosts 去广告 bind mount =====
# APatch 对 system/etc/hosts 的 overlay 可能不生效，手动 bind mount
HOSTS_SRC="$MODDIR/system/etc/hosts"
if [ -f "$HOSTS_SRC" ]; then
    mount -o bind "$HOSTS_SRC" /system/etc/hosts 2>>$LOG
    if [ $? -eq 0 ]; then
        echo "[$(date)] hosts: bind mount OK ($(wc -l < /system/etc/hosts) lines)" >> $LOG
    else
        echo "[$(date)] hosts: bind mount FAILED" >> $LOG
    fi
fi

# ===== 阶段2: 渐进式重试加载 iptables =====
echo "[$(date)] Phase2: starting retry loop (max_retry=30)" >> $LOG

retry=0
max_retry=30

while [ $retry -lt $max_retry ]; do
    retry=$((retry + 1))

    count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
    if [ "$count" -ge 100 ]; then
        echo "[$(date)] Phase2: already loaded ($count DROP), skip" >> $LOG
        break
    fi

    echo "[$(date)] Phase2: retry $retry/$max_retry, DROP=$count, loading..." >> $LOG

    nohup sh $MODDIR/mod/iptables.sh >> $LOG 2>&1 &
    ipt_pid=$!

    wait_sec=0
    while [ $wait_sec -lt 25 ]; do
        sleep 2
        wait_sec=$((wait_sec + 2))
        if ! kill -0 $ipt_pid 2>/dev/null; then
            break
        fi
    done

    kill -0 $ipt_pid 2>/dev/null && kill $ipt_pid 2>/dev/null

    count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
    if [ "$count" -ge 100 ]; then
        echo "[$(date)] Phase2: SUCCESS at retry $retry, DROP=$count" >> $LOG
        break
    fi

    echo "[$(date)] Phase2: retry $retry failed, DROP=$count" >> $LOG

    if [ $retry -le 5 ]; then
        sleep $((retry * 5))
    else
        sleep 30
    fi
done

final_count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
if [ "$final_count" -ge 100 ]; then
    echo "[$(date)] service.sh: ALL OK, final DROP=$final_count" >> $LOG
else
    echo "[$(date)] service.sh: FAILED after $retry retries, final DROP=$final_count" >> $LOG
fi

# ===== 阶段3: 冻结隐私监控 + 系统广告应用 =====
echo "[$(date)] Phase3: disabling surveillance apps" >> $LOG

# pm 在开机早期可能尚未就绪，加重试
for pkg in com.oplus.thirdkit com.opos.ads; do
    for i in $(seq 1 10); do
        if pm disable "$pkg" 2>>$LOG; then
            echo "[$(date)] Phase3: $pkg disabled (attempt $i)" >> $LOG
            break
        fi
        sleep 3
    done
done

# ===== 阶段4: chattr +i 锁定广告缓存 (后台) =====
echo "[$(date)] Phase4: locking ad caches (background)" >> $LOG
nohup sh $MODDIR/mod/ads_lock.sh >> $LOG 2>&1 &
echo "[$(date)] Phase4: ads_lock.sh launched (pid=$!)" >> $LOG

# ===== 阶段5: KernelSU/Apatch 适配 (后台) =====
test -f $MODDIR/mod/kernel_su.sh && nohup $MODDIR/mod/kernel_su.sh >/dev/null 2>&1 &
