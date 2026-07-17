#!/system/bin/sh
# 屏蔽反诈+去广告 - 开机自启 (v2 fixed)
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
    ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && break
    sleep 5
done
echo "[$(date)] Phase1: network check done (attempt $i)" >> $LOG

# 等待 iptables 可用（仅验证可读，不做写测试）
echo "[$(date)] Phase1: waiting for iptables" >> $LOG
for i in $(seq 1 20); do
    iptables -L OUTPUT -n >/dev/null 2>&1 && break
    sleep 3
done
echo "[$(date)] Phase1: iptables ready (attempt $i)" >> $LOG

# ===== 阶段1.5: hosts 去广告（多策略） =====
HOSTS_SRC="$MODDIR/system/etc/hosts"
if [ -f "$HOSTS_SRC" ]; then
    sys_lines=$(wc -l < /system/etc/hosts 2>/dev/null)
    if [ "$sys_lines" -gt 100 ]; then
        echo "[$(date)] hosts: overlay already active ($sys_lines lines)" >> $LOG
    else
        # 策略1: 直接 bind mount
        mount -o bind "$HOSTS_SRC" /system/etc/hosts 2>>$LOG
        sleep 1
        new_lines=$(wc -l < /system/etc/hosts 2>/dev/null)
        if [ "$new_lines" -gt 100 ]; then
            echo "[$(date)] hosts: bind mount OK ($new_lines lines)" >> $LOG
        else
            # 策略2: 复制到 /data/local/tmp 再 bind mount（绕过 overlayfs）
            cp "$HOSTS_SRC" /data/local/tmp/hosts_block 2>/dev/null
            mount -o bind /data/local/tmp/hosts_block /system/etc/hosts 2>>$LOG
            sleep 1
            new_lines=$(wc -l < /system/etc/hosts 2>/dev/null)
            if [ "$new_lines" -gt 100 ]; then
                echo "[$(date)] hosts: tmp bind mount OK ($new_lines lines)" >> $LOG
            else
                echo "[$(date)] hosts: ALL STRATEGIES FAILED (current=$new_lines)" >> $LOG
            fi
        fi
    fi
else
    echo "[$(date)] hosts: source file missing!" >> $LOG
fi

# ===== 阶段2: 加载 iptables 规则（同步执行，不用后台） =====
echo "[$(date)] Phase2: loading iptables rules" >> $LOG

# 使用 timeout 防止 iptables 命令卡死
if command -v timeout >/dev/null 2>&1; then
    timeout 120 sh "$MODDIR/mod/iptables.sh" >> $LOG 2>&1
    ipt_rc=$?
else
    sh "$MODDIR/mod/iptables.sh" >> $LOG 2>&1 &
    ipt_pid=$!
    waited=0
    while [ $waited -lt 120 ]; do
        if ! kill -0 "$ipt_pid" 2>/dev/null; then
            wait "$ipt_pid" 2>/dev/null
            ipt_rc=$?
            break
        fi
        sleep 3
        waited=$((waited + 3))
    done
    if kill -0 "$ipt_pid" 2>/dev/null; then
        kill "$ipt_pid" 2>/dev/null
        ipt_rc=124
    fi
fi

count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
echo "[$(date)] Phase2: iptables done (rc=$ipt_rc, DROP=$count)" >> $LOG

# 规则不足时重试一次
if [ "$count" -lt 100 ]; then
    echo "[$(date)] Phase2: DROP < 100, retrying..." >> $LOG
    sleep 10
    timeout 120 sh "$MODDIR/mod/iptables.sh" >> $LOG 2>&1
    count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
    echo "[$(date)] Phase2: retry done (DROP=$count)" >> $LOG
fi

# ===== 阶段3: 冻结隐私监控 + 系统广告应用 =====
echo "[$(date)] Phase3: disabling surveillance apps" >> $LOG

# 等待 package service 就绪（APatch 环境下初始化较慢）
echo "[$(date)] Phase3: waiting for package service" >> $LOG
for i in $(seq 1 30); do
    if pm list packages com.android.settings 2>/dev/null | grep -q settings; then
        echo "[$(date)] Phase3: package service ready (attempt $i)" >> $LOG
        break
    fi
    sleep 2
done

for pkg in com.oplus.thirdkit com.opos.ads; do
    for i in $(seq 1 5); do
        if pm disable "$pkg" 2>>$LOG; then
            echo "[$(date)] Phase3: $pkg disabled (attempt $i)" >> $LOG
            break
        fi
        sleep 3
    done
done

# ===== 阶段4-6: 后台任务（有超时监控） =====
echo "[$(date)] Phase4: launching background tasks" >> $LOG

# ads_lock
sh "$MODDIR/mod/ads_lock.sh" >> $LOG 2>&1 &
ads_pid=$!
echo "[$(date)] Phase4: ads_lock.sh pid=$ads_pid" >> $LOG

# AWAvenue 规则更新
sh "$MODDIR/mod/update_rules.sh" >> $LOG 2>&1 &
awa_pid=$!
echo "[$(date)] Phase6: update_rules.sh pid=$awa_pid" >> $LOG

# 等待后台任务（最多 5 分钟，逐个等待）
for task_pid in $ads_pid $awa_pid; do
    waited=0
    while [ $waited -lt 300 ]; do
        if ! kill -0 "$task_pid" 2>/dev/null; then
            wait "$task_pid" 2>/dev/null
            echo "[$(date)] task pid=$task_pid finished (rc=$?)" >> $LOG
            break
        fi
        sleep 5
        waited=$((waited + 5))
    done
    if kill -0 "$task_pid" 2>/dev/null; then
        echo "[$(date)] task pid=$task_pid TIMEOUT after 300s" >> $LOG
    fi
done

final_count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c DROP)
if [ "$final_count" -ge 100 ]; then
    echo "[$(date)] service.sh: ALL OK, final DROP=$final_count" >> $LOG
else
    echo "[$(date)] service.sh: WARNING, final DROP=$final_count" >> $LOG
fi