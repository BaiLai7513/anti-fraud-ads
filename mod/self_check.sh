#!/system/bin/sh
# anti_fraud_ads 开机自检 - 检测实际生效情况并生成日志
# 用法: sh mod/self_check.sh [模块目录]  (开机5min后由 service.sh 自动调用)
# 手动触发: sh /data/adb/modules/anti_fraud_ads/mod/self_check.sh
MODDIR=${1:-${0%/*}}
case "$MODDIR" in
  */mod) MODDIR=${MODDIR%/mod};;
esac
[ -z "$MODDIR" ] && MODDIR=/data/adb/modules/anti_fraud_ads
LOG="$MODDIR/self_check.log"
NOW=$(date '+%Y-%m-%d %H:%M:%S')

{
echo "=================================================="
echo "[$NOW] anti_fraud_ads 自检 (module.prop: $(grep -m1 version= "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2))"
echo "=================================================="

# 1. 环境
ROOT="unknown"
[ -d /data/adb/magisk ] && ROOT="magisk"
[ -x /data/adb/ksud ] && ROOT="ksu"
[ -x /data/adb/apd ] || [ -x /data/adb/ap/bin/apd ] && ROOT="apatch"
echo "[环境] root类型=$ROOT"

# 2. 启用状态
if [ -f "$MODDIR/disable" ]; then echo "[FAIL] 模块被标记禁用(disable)"
elif [ -f "$MODDIR/remove" ]; then echo "[FAIL] 模块被标记删除(remove)"
else echo "[PASS] 模块启用状态正常"
fi

# 3. hosts 实际生效
SRC="$MODDIR/system/etc/hosts"; SYS="/system/etc/hosts"
if [ -f "$SRC" ]; then
  SRC_MD5=$(md5sum "$SRC" 2>/dev/null | awk '{print $1}')
  SRC_N=$(wc -l < "$SRC" 2>/dev/null)
  SYS_MD5=$(md5sum "$SYS" 2>/dev/null | awk '{print $1}')
  SYS_N=$(wc -l < "$SYS" 2>/dev/null)
  echo "[hosts] 模块=${SRC_N}行 md5=${SRC_MD5}"
  echo "[hosts] 系统=${SYS_N}行 md5=${SYS_MD5}"
  if [ "$SRC_MD5" = "$SYS_MD5" ]; then echo "[PASS] hosts 已生效(内容一致)"
  else echo "[FAIL] hosts 未生效(源${SRC_N}行 vs 系统${SYS_N}行)"
  fi
else echo "[FAIL] 模块 hosts 源文件缺失"
fi
grep -q 'anti_fraud_ads/system/etc/hosts' /proc/self/mountinfo 2>/dev/null \
  && echo "[PASS] hosts bind mount 存在" \
  || echo "[WARN] hosts 无独立 bind mount"

# 4. 残留
if [ -e /data/local/tmp/hosts_block ]; then
  echo "[FAIL] 残留: /data/local/tmp/hosts_block"
else
  echo "[PASS] 无 /local/tmp/hosts_block 残留"
fi

# 5. iptables
DROP_N=$(iptables -L OUTPUT -n 2>/dev/null | grep -cE 'DROP|REJECT')
if [ "$DROP_N" -gt 0 ] 2>/dev/null; then
  echo "[PASS] iptables OUTPUT DROP/REJECT=${DROP_N}条"
else
  echo "[FAIL] iptables 无 DROP 规则"
fi

# 6. ads_lock + module.log
MLOG="$MODDIR/module.log"
if [ -f "$MLOG" ]; then
  grep -iE 'lock|锁' "$MLOG" 2>/dev/null | tail -1 | sed 's/^/[ads_lock] /'
  ERR=$(grep -iE 'error|fail|WARN|missing' "$MLOG" 2>/dev/null | grep -vE 'failed=0' | tail -3)
  if [ -n "$ERR" ]; then
    echo "[WARN] module.log 近期错误:"
    echo "$ERR" | sed 's/^/   /'
  else
    echo "[PASS] module.log 无错误"
  fi
else
  echo "[WARN] module.log 不存在"
fi

echo "[module.log 尾部]"
tail -5 "$MLOG" 2>/dev/null | sed 's/^/  /'
echo "[$NOW] 自检完成"
echo "=================================================="
} >> "$LOG" 2>&1
echo "$NOW" > "$MODDIR/self_check.stamp"