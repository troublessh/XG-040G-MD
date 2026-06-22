#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复Airoha MAC地址：用编译种子生成唯一固定MAC（每台设备不同，重启不变）
MAC_FILE=$(find ./package/ -type f -name "99_fix-airoha-mac" 2>/dev/null)
if [ -f "$MAC_FILE" ]; then
	echo " "

	# 用 GITHUB_RUN_ID 生成唯一 MAC（每次编译不同，同固件内固定）
	RUN_SEED="${GITHUB_RUN_ID:-$(date +%s)}"
	SEED_HEX=$(echo -n "$RUN_SEED" | sha256sum | head -c 12)
	# 设置 locally-administered bit（第二字节最低位=1），避免与真实 OUI 冲突
	B1="0x${SEED_HEX:2:2}"
	B1=$(printf '%02x' $(( 16#$B1 | 0x02 )))
	BASE_MAC="02:${B1}:${SEED_HEX:4:2}:${SEED_HEX:6:2}:${SEED_HEX:8:2}:${SEED_HEX:10:2}"

	cat > "$MAC_FILE" << MACFIX
#!/bin/sh

. /lib/functions.sh

# 编译时生成的固定 MAC（同固件内所有设备相同，不同固件不同）
BASE_MAC="$BASE_MAC"

# LAN 接口共享同一 MAC，WAN (lan4) = BASE_MAC +1
mac_base=\$(echo "\$BASE_MAC" | tr -d ':')
mac_dec=\$((16#\$mac_base))

printf -v mac_lan "%012x" \$((mac_dec))
printf -v mac_wan "%012x" \$((mac_dec + 1))

format_mac() {
    echo "\$1" | sed 's/\\(..\\)/\\1:/g; s/:$//' | tr 'a-f' 'A-F'
}

config_load network

found_br=0
handle_br_lan() {
    local section="\$1"
    local name
    config_get name "\$section" name
    if [ "\$name" = "br-lan" ]; then
        uci set network."\$section".macaddr="\$(format_mac \$mac_lan)"
        found_br=1
    fi
}
config_foreach handle_br_lan device

for iface in eth0 eth1 lan2 lan3 lan4; do
    if ! ip link show dev "\$iface" >/dev/null 2>&1; then
        continue
    fi
    section_name="\${iface}_mac_fix"
    uci set network."\$section_name"=device
    uci set network."\$section_name".name="\$iface"
    if [ "\$iface" = "lan4" ]; then
        uci set network."\$section_name".macaddr="\$(format_mac \$mac_wan)"
    else
        uci set network."\$section_name".macaddr="\$(format_mac \$mac_lan)"
    fi
done

uci commit network
/etc/init.d/network reload

exit 0
MACFIX

	chmod +x "$MAC_FILE"
	cd $PKG_PATH && echo "airoha-mac fixed: LAN=$BASE_MAC, WAN=+1"
fi
