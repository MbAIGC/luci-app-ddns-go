#!/bin/sh
#
# 本地/CI 通用静态检查，不需要 OpenWrt SDK。
#

set -e

cd "$(dirname "$0")/.."

echo "== shell 语法 =="
for f in $(find luci-app-ddns-go/root -type f -name '*' 2>/dev/null); do
	case "$f" in
		*/etc/uci-defaults/*)
			sh -n "$f"
			echo "ok  $f"
			;;
	esac
done

echo "== Lua 语法 =="
LUA_CHECK=""
if command -v luac5.1 >/dev/null 2>&1; then
	LUA_CHECK="luac5.1 -p"
elif command -v luac >/dev/null 2>&1; then
	LUA_CHECK="luac -p"
fi

if [ -n "$LUA_CHECK" ]; then
	for f in $(find luci-app-ddns-go/luasrc -name '*.lua' | sort); do
		$LUA_CHECK "$f"
		echo "ok  $f"
	done
else
	echo "skip: 未安装 luac"
fi

echo "== 模板语法 =="
for f in $(find luci-app-ddns-go/luasrc -name '*.htm' | sort); do
	o=$(grep -o '<%' "$f" | wc -l)
	c=$(grep -o '%>' "$f" | wc -l)
	[ "$o" = "$c" ] || { echo "ERR $f: <% 与 %> 数量不匹配 ($o/$c)" >&2; exit 1; }
	echo "ok  $f ($o 个代码块)"
done

echo "全部检查通过"
