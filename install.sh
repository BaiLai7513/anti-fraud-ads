SKIPMOUNT=false
LATESTARTSERVICE=true
POSTFSDATA=false
PROPFILE=false

print_modname() {
  ui_print "*******************************"
  ui_print "     AF_ADS_FUCK v260817       "
  ui_print "  anti-fraud + adblock + lock  "
  ui_print "*******************************"
}

on_install() {
  ui_print "- Extracting module files..."
  unzip -o "$ZIPFILE" -d $MODPATH >&2

  # 更新模块时保留旧版本的备份/状态/配置（新目录安装不会带走它们）
  OLD_MOD="/data/adb/modules/anti_fraud_ads"
  if [ "$OLD_MOD" != "$MODPATH" ] && [ -d "$OLD_MOD" ]; then
    if [ -d "$OLD_MOD/backup" ]; then
      mkdir -p "$MODPATH/backup" 2>/dev/null
      cp -a "$OLD_MOD/backup/." "$MODPATH/backup/" 2>/dev/null
      ui_print "- Preserved existing ads_lock backup/state"
    fi
    if [ -f "$OLD_MOD/config.conf" ] && [ ! -f "$MODPATH/config.conf" ]; then
      cp -a "$OLD_MOD/config.conf" "$MODPATH/config.conf" 2>/dev/null
      ui_print "- Preserved existing config.conf"
    fi
  fi

  # 初始化备份与修改记录目录；state.tsv 只在不存在时创建，避免清空旧记录
  ui_print "- Initializing ads_lock backup/state..."
  mkdir -p "$MODPATH/backup/payload" "$MODPATH/backup/sqlite" 2>/dev/null
  [ -f "$MODPATH/backup/state.tsv" ] || : > "$MODPATH/backup/state.tsv" 2>/dev/null
  if [ ! -f "$MODPATH/config.conf" ]; then
    cp "$MODPATH/mod/config.default.conf" "$MODPATH/config.conf" 2>/dev/null
  fi

  # APM (APatch) 兼容：框架在 on_install 后会尝试 cp /dev/tmp/service.sh
  # （Magisk 安装器才有的路径，APM 环境不存在导致无意义报错）。
  # 这里主动补一份，让框架的 cp 能找到源，跳过报错。
  if [ ! -f /dev/tmp/service.sh ]; then
    mkdir -p /dev/tmp 2>/dev/null
    cp "$MODPATH/service.sh" /dev/tmp/service.sh 2>/dev/null && \
      ui_print "- APM compat: /dev/tmp/service.sh created"
  fi
  ui_print "- Done"
}

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm_recursive $MODPATH/mod 0 0 0755 0755
  set_perm_recursive $MODPATH/backup 0 0 0700 0600
  if [ -f "$MODPATH/config.conf" ]; then
    set_perm $MODPATH/config.conf 0 0 0600
  fi
}
