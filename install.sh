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
  ui_print "- Done"
}

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
  set_perm_recursive $MODPATH/mod 0 0 0755 0755
}