#!/bin/sh
set -eu

required_files='
luci-app-ipass/Makefile
luci-app-ipass/root/etc/config/ipass
luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
luci-app-ipass/root/usr/share/ipass/defaults.json
luci-app-ipass/root/usr/share/ipass/check.sh
luci-app-ipass/luasrc/controller/ipass.lua
luci-app-ipass/luasrc/model/cbi/ipass/sites.lua
luci-app-ipass/luasrc/view/ipass/status.htm
'

for file in $required_files; do
  if [ ! -f "$file" ]; then
    echo "missing required file: $file" >&2
    exit 1
  fi
done

grep -q 'LUCI_TITLE:=LuCI support for iPass Connectivity Check' luci-app-ipass/Makefile
grep -Eq '^PKG_VERSION:=[0-9]+\.[0-9]+\.[0-9]+$' luci-app-ipass/Makefile
grep -q 'LUCI_PKGARCH:=all' luci-app-ipass/Makefile
grep -q 'LUCI_DEPENDS:=+curl +luci-compat +libuci-lua +luci-lib-jsonc' luci-app-ipass/Makefile
grep -q "config site 'baidu'" luci-app-ipass/root/etc/config/ipass
grep -q "config site 'douyin'" luci-app-ipass/root/etc/config/ipass
grep -q "config site 'chatgpt'" luci-app-ipass/root/etc/config/ipass
grep -q "config site 'douyin'" luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
grep -q "config site 'chatgpt'" luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
grep -q 'ipass-hero' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'ipass-progress-fill' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'ipass-filter-btn' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'data-filter' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'ipass-latency-meter' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'MAX_CONCURRENT_CHECKS' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q 'queuedSites' luci-app-ipass/luasrc/view/ipass/status.htm
grep -q '排队中' luci-app-ipass/luasrc/view/ipass/status.htm

sh -n luci-app-ipass/root/etc/uci-defaults/90_luci-ipass
if [ -f luci-app-ipass/root/usr/share/ipass/check.sh ]; then
  sh -n luci-app-ipass/root/usr/share/ipass/check.sh
fi

echo "static check passed"
