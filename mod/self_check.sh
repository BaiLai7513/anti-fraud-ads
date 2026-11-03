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
  if [ "$SRC_MD5" = "$SYS_MD5" ]; then
    echo "[PASS] hosts 已生效(内容一致)"
    if [ "$SRC_N" -lt 1000 ] 2>/dev/null; then
      echo "[WARN] hosts 为占位态(${SRC_N}行)，云端规则未拉取(检查网络/update_rules.log)"
    else
      echo "[OK]   hosts 云端规则已更新(${SRC_N}行)"
    fi
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

# 7. 共享存储状态（只读检查；模块不应修改 /data/media）
echo "[存储] sm list-volumes all:"
sm list-volumes all 2>&1 | sed 's/^/  /'
echo "[存储] ls -ld /storage/emulated/0 /data/media/0:"
ls -ld /storage/emulated/0 /data/media/0 2>&1 | sed 's/^/  /'
if [ -d /storage/emulated/0 ] 2>/dev/null && [ -r /storage/emulated/0 ] 2>/dev/null; then
  echo "[PASS] 共享存储可访问 (/storage/emulated/0)"
else
  echo "[FAIL] 共享存储不可访问（检查 vold/FUSE；模块不应修改 /data/media）"
fi

# 8. ads_lock 修改记录与备份
STATE="$MODDIR/backup/state.tsv"
if [ -f "$STATE" ]; then
  N=$(wc -l < "$STATE" 2>/dev/null | tr -d ' ')
  echo "[ads_lock] 修改记录: ${N} 条 ($STATE)"
  if [ "$N" -gt 0 ] 2>/dev/null; then
    BAD=$(cut -f2 "$STATE" 2>/dev/null | grep -E '^/data/media/|^/storage/|^/sdcard/' | head -3)
    if [ -n "$BAD" ]; then
      echo "[FAIL] state 含共享存储路径（旧版本残留）:"
      echo "$BAD" | sed 's/^/   /'
    else
      echo "[PASS] state 无共享存储路径"
    fi
    echo "[ads_lock] 回滚命令: sh $MODDIR/mod/rollback.sh"
  fi
else
  echo "[WARN] state.tsv 不存在（未执行过 ads_lock 或旧版本）"
fi
PAYLOAD_N=$(ls -A "$MODDIR/backup/payload" 2>/dev/null | wc -l | tr -d ' ')
SQLITE_N=$(ls -A "$MODDIR/backup/sqlite" 2>/dev/null | wc -l | tr -d ' ')
echo "[ads_lock] 备份文件: payload=${PAYLOAD_N} sqlite=${SQLITE_N}"

# 9. 配置与 immutable 能力
CONFIG="$MODDIR/config.conf"
if [ -f "$CONFIG" ]; then
  echo "[config] $CONFIG"
  grep -E '^AFADS_' "$CONFIG" 2>/dev/null | sed 's/^/  /'
else
  echo "[WARN] config.conf 不存在，使用默认值"
fi
if command -v chattr >/dev/null 2>&1 && command -v lsattr >/dev/null 2>&1; then
  echo "[PASS] chattr/lsattr 可用"
else
  echo "[WARN] chattr/lsattr 不可用，锁定降级为 chmod"
fi

# 10. 旧版本遗留提示（只读）
echo "[提示] 若旧版本曾修改共享存储，可用以下命令检查 immutable 残留:"
echo "       lsattr -d /data/media/0/Android/data/* 2>/dev/null | grep ' i'"

echo "[module.log 尾部]"
tail -5 "$MLOG" 2>/dev/null | sed 's/^/  /'
echo "[$NOW] 自检完成"
echo "=================================================="
} >> "$LOG" 2>&1
echo "$NOW" > "$MODDIR/self_check.stamp"
