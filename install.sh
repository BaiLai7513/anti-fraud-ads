SKIPMOUNT=false
LATESTARTSERVICE=true
POSTFSDATA=false
PROPFILE=false

print_modname() {
  ui_print "*******************************"
  ui_print "     AF_ADS_FUCK v260812       "
  ui_print "  anti-fraud + adblock + lock  "
  ui_print "*******************************"
}

on_install() {
  ui_print "- Extracting module files..."
  unzip -o "$ZIPFILE" -d $MODPATH >&2

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
}