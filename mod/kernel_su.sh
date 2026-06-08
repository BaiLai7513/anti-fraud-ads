
id="anti_fraud_ads"
Magisk_mod=$(grep -w -q 'lite_modules' /data/adb/magisk/util_functions.sh 2>/dev/null && echo "lite_modules" || echo "modules")
MODPATH="/data/adb/$Magisk_mod/$id"

export PATH="/system/bin:$MODPATH/busybox:$PATH"

source $MODPATH/mod/util_functions.sh

wait_until_login() {
	while [ "$(getprop sys.boot_completed)" != "1" ]; do
		sleep 1
	done
	a="0"
	local test_file="/data/media/0/Android/data"
	while [ ! -e "${test_file}" ]; do
		a="$(($a + 1))"
		test "$a" = "3" && break
		sleep 1m
	done
}


function overlay_system_hosts(){
local modules_host="$(find "${MODPATH}" -iname 'hosts' -type f 2>/dev/null | head -n 1)"
local modules_host_folder="${modules_host%/*}"
local system_hosts="${modules_host/$MODPATH/}"
local system_hosts_folder="${system_hosts%/*}"
umount "${system_host}" >/dev/null 2>&1
mount --bind "${modules_host}" "${system_host}" >/dev/null 2>&1
}

wait_until_login

ping -c 1 -W 10 baidu.com || sleep 3m


if ping -c 1 -W 3 sanme2.lanzoui.com | grep -Eo '0\.0\.0\.0|127\.0\.0\.1' >/dev/null 2>&1 ;then
	Log_10007_dmesg "@10007:Host modtify" "i"
else
	Log_10007_dmesg "@10007:Host does not exist" "e"
	overlay_system_hosts
fi
