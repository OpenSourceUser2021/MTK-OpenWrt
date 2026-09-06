#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 任何一步失败立即退出；管道中任一命令失败也视为失败（防止下载失败产生损坏文件）
set -euo pipefail

# 预置openclash内核
# 带重试与产物校验的下载函数：网络抖动时宁可构建失败，也不产出损坏文件
# 用法: fetch <url> <输出文件> <最小字节数>
fetch() {
	local url="$1" out="$2" min_size="$3" tmp attempt=0
	tmp="$(mktemp)"
	while [ "$attempt" -lt 5 ]; do
		attempt=$((attempt + 1))
		echo ">>> [$attempt/5] 下载 $url"
		if wget --timeout=30 --tries=3 -qO "$tmp" "$url" && [ "$(stat -c%s "$tmp")" -ge "$min_size" ]; then
			mkdir -p "$(dirname "$out")"
			mv "$tmp" "$out"
			echo ">>> 完成：$out"
			return 0
		fi
		rm -f "$tmp"
		sleep 3
	done
	echo "!!! 下载失败：$url" >&2
	return 1
}

mkdir -p files/etc/openclash/core
CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
GEOIP_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat"
GEOSITE_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"

# 先下载压缩包到临时文件并校验大小，再解压，避免管道中段失败产生损坏内核
CLASH_TGZ="$(mktemp)"
trap 'rm -f "$CLASH_TGZ"' EXIT
fetch "$CLASH_META_URL" "$CLASH_TGZ" 1048576        # tar.gz 至少 1MB
tar xOzf "$CLASH_TGZ" > files/etc/openclash/core/clash_meta
if [ "$(stat -c%s files/etc/openclash/core/clash_meta)" -lt 10485760 ]; then   # 二进制至少 10MB
	echo "!!! clash_meta 解压结果异常，中止构建" >&2
	exit 1
fi

fetch "$GEOIP_URL" files/etc/openclash/GeoIP.dat 1048576      # 至少 1MB
fetch "$GEOSITE_URL" files/etc/openclash/GeoSite.dat 1048576  # 至少 1MB

# 给内核权限
chmod +x files/etc/openclash/core/clash*

