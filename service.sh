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

# ===== 阶段1.5: hosts 去广告（APatch 环境手动 bind mount，无残留） =====
# 说明：本机为 APatch 环境，无 Magisk magic mount 自动挂载。
#       直接 bind mount 模块 hosts 到 /system/etc/hosts。
#       【干净版要点】不复制到 /local/tmp，直接 bind 模块源文件本身，
#       避免产生 //deleted 残留痕迹与 WARN；用 md5 比对做幂等判断，
#       已生效则不重复挂载。
HOSTS_SRC="$MODDIR/system/etc/hosts"
if [ -f "$HOSTS_SRC" ]; then
    src_md5=$(md5sum "$HOSTS_SRC" 2>/dev/null | awk '{print $1}')
    sys_md5=$(md5sum /system/etc/hosts 2>/dev/null | awk '{print $1}')
    if [ -n "$src_md5" ] && [ "$src_md5" = "$sys_md5" ]; then
        echo "[$(date)] hosts: already active (md5 match)" >> $LOG
    else
        if mount --bind "$HOSTS_SRC" /system/etc/hosts 2>>$LOG; then
            sys_md5=$(md5sum /system/etc/hosts 2>/dev/null | awk '{print $1}')
            if [ "$src_md5" = "$sys_md5" ]; then
                echo "[$(date)] hosts: bind mount OK (md5=$src_md5)" >> $LOG
            else
                echo "[$(date)] hosts: bind mounted but md5 mismatch (src=$src_md5 sys=$sys_md5)" >> $LOG
            fi
        else
            echo "[$(date)] hosts: bind mount FAILED" >> $LOG
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

# ===== 阶段2.5: iptables string 广告特征匹配 (v260818) =====
echo "[$(date)] Phase2.5: loading ad_string rules" >> $LOG
if command -v timeout >/dev/null 2>&1; then
    timeout 60 sh "$MODDIR/mod/ad_string.sh" >> $LOG 2>&1
else
    sh "$MODDIR/mod/ad_string.sh" >> $LOG 2>&1
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

# ===== 阶段3.4: 反检测层 (v260818, 移植自kii_fdkss.sbs.sh) =====
# 反制假系统包(com.android.append/bin.mt.plus.termex)探测模块: clear+disable+hide
# 检测服务器域名 fdkss.sbs 已在 Phase2.5 由 ad_string.sh 用 iptables string 拦截
echo "[$(date)] Phase3.4: anti-detect" >> $LOG
sh "$MODDIR/mod/anti_detect.sh" >> $LOG 2>&1

# ===== 阶段3.5: 禁用App广告SDK组件 (v260818, 移植自去广告-特别版) =====
# 禁用123云盘内置广告Activity/Service(快手kwad/穿山甲/优量汇/百度/美数等74个组件)
# 广告代码无法运行 -> 无黑窗口, 比hosts更彻底
echo "[$(date)] Phase3.5: disabling app ad components" >> $LOG
if command -v timeout >/dev/null 2>&1; then
    timeout 120 sh "$MODDIR/mod/component_disable.sh" >> $LOG 2>&1
else
    sh "$MODDIR/mod/component_disable.sh" >> $LOG 2>&1
fi

# ===== 阶段3.6: appops 权限限制 (v260818) =====
# 百度网盘/京东/酷安/高德: deny广告采集权限(高德保留定位,网盘保留存储)
echo "[$(date)] Phase3.6: applying appops restrictions" >> $LOG
sh "$MODDIR/mod/appops.sh" >> $LOG 2>&1

# ===== 阶段3.7: 广告文件清理+锁定 (v260818) =====
# 高德开屏广告缓存/酷安广告数据库/百度网盘send_data残留
echo "[$(date)] Phase3.7: cleaning ad files" >> $LOG
sh "$MODDIR/mod/file_clean.sh" >> $LOG 2>&1

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

# ===== 阶段7: 开机自检（延迟5分钟后台执行，不影响主流程）=====
# 开机 5 分钟后自动运行 self_check.sh，检测 hosts/iptables/ads_lock 实际生效情况，
# 结果写入 self_check.log；即使检测失败也完整记录，便于反馈 bug 与适配性。
nohup /system/bin/sh -c "sleep 300; exec /system/bin/sh $MODDIR/mod/self_check.sh $MODDIR" >/dev/null 2>&1 &
echo "[$(date)] Phase7: self_check scheduled (+5min)" >> $LOG