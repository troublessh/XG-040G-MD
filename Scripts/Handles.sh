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
MAC_FILE=$(find ./ -path "*/etc/uci-defaults/99_fix-airoha-mac" 2>/dev/null)
if [ -f "$MAC_FILE" ]; then
	echo " "

	# 用 GITHUB_RUN_ID 生成唯一 MAC（每次编译不同，同固件内固定）
	RUN_SEED="${GITHUB_RUN_ID:-$(date +%s)}"
	SEED_HEX=$(echo -n "$RUN_SEED" | sha256sum | head -c 12)
	# 设置 locally-administered bit（第二字节最低位=1），避免与真实 OUI 冲突
	B1=$((16#${SEED_HEX:2:2} | 0x02))
	BASE_MAC=$(printf "02:%02x:%s:%s:%s:%s" $B1 ${SEED_HEX:4:2} ${SEED_HEX:6:2} ${SEED_HEX:8:2} ${SEED_HEX:10:2})

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

#PassWall global.lua nil-index 兼容性修复（OpenWrt 25.12）
PW_CANDIDATES=(
	"./luci-app-passwall/luasrc/model/cbi/passwall/client/global.lua"
	"./passwall/luci-app-passwall/luasrc/model/cbi/passwall/client/global.lua"
)
for PW_FILE in "${PW_CANDIDATES[@]}"; do
	if [ -f "$PW_FILE" ]; then
		echo "Applying PassWall Lua compatibility hotfix: $PW_FILE"
		sed -i 's#local dns_shunt_val = s.fields\["dns_shunt"\]:formvalue(section)#local dns_shunt_val = (s.fields["dns_shunt"] and s.fields["dns_shunt"]:formvalue(section)) or ""#g' "$PW_FILE"
		sed -i 's#s.fields\["dns_mode"\]:formvalue(section) == "xray" or s.fields\["smartdns_dns_mode"\]:formvalue(section) == "xray"#((s.fields["dns_mode"] and s.fields["dns_mode"]:formvalue(section)) == "xray") or ((s.fields["smartdns_dns_mode"] and s.fields["smartdns_dns_mode"]:formvalue(section)) == "xray")#g' "$PW_FILE"
		sed -i 's#s.fields\["dns_mode"\]:formvalue(section) == "sing-box" or s.fields\["smartdns_dns_mode"\]:formvalue(section) == "sing-box"#((s.fields["dns_mode"] and s.fields["dns_mode"]:formvalue(section)) == "sing-box") or ((s.fields["smartdns_dns_mode"] and s.fields["smartdns_dns_mode"]:formvalue(section)) == "sing-box")#g' "$PW_FILE"
		cd $PKG_PATH && echo "passwall global.lua fixed!"
		break
	fi
done

#NAND SPI robust-read 补丁（解决 flash 读取稳定性）
NAND_PATCH=$(find ../target/linux/ -type d -name "pending-*" 2>/dev/null | head -1)
if [ -n "$NAND_PATCH" ] && [ ! -f "$NAND_PATCH/600-mtd-spinand-add-skyhigh-robust-read-workaround.patch" ]; then
	echo "RnJvbTogeGlhbmd0YWlsaWFuZwpTdWJqZWN0OiBbUEFUQ0hdIG10ZDogc3BpbmFuZDogYWRkIHNreWhpZ2ggcm9idXN0IHJlYWQgd29ya2Fyb3VuZAoKQWRkIGEgcm9idXN0IHJlYWQgcGFnZSB3YWl0IGZ1bmN0aW9uIHRoYXQgcmV0cmllcyBzdGF0dXMgcmVhZHMKd2l0aCBhIDQwMG1zIHRpbWVvdXQgdG8gaGFuZGxlIHNsb3cgZmxhc2ggcGFnZSByZWFkcyBvbiBBaXJvaGEKRU43NTgxIHBsYXRmb3Jtcy4KCi0tLSBhL2RyaXZlcnMvbXRkL25hbmQvc3BpL2NvcmUuYworKysgYi9kcml2ZXJzL210ZC9uYW5kL3NwaS9jb3JlLmMKQEAgLTYxMiw2ICs2MTIsMzQgQEAgc3RhdGljIGludCBzcGluYW5kX2xvY2tfYmxvY2soc3RydWN0IHNwaW5hbmRfZGV2aWNlICpzcGluYW5kLCB1OCBsb2NrKQoJcmV0dXJuIHNwaW5hbmRfd3JpdGVfcmVnX29wKHNwaW5hbmQsIFJFR19CTE9DS19MT0NLLCBsb2NrKTsKIH0KCitzdGF0aWMgaW50IHNwaW5hbmRfcmVhZF9wYWdlX3dhaXQoc3RydWN0IHNwaW5hbmRfZGV2aWNlICpzcGluYW5kLCB1OCAqcykKK3sKKwl1bnNpZ25lZCBsb25nIHRpbWVvID0gamlmZmllcyArIG1zZWNzX3RvX2ppZmZpZXMoNDAwKTsKKwl1OCBzdGF0dXM7CisJaW50IHJldDsKKworCWRvIHsKKwkJcmV0ID0gc3BpbmFuZF9yZWFkX3N0YXR1cyhzcGluYW5kLCAmc3RhdHVzKTsKKwkJaWYgKHJldCkKKwkJCXJldHVybiByZXQ7CisKKwkJaWYgKHN0YXR1cyAmIFNUQVRVU19CVVNZKQorCQkJY29udGludWU7CisKKwkJcmV0ID0gc3BpbmFuZF9yZWFkX3N0YXR1cyhzcGluYW5kLCAmc3RhdHVzKTsKKwkJaWYgKHJldCkKKwkJCXJldHVybiByZXQ7CisKKwkJaWYgKCEoc3RhdHVzICYgU1RBVFVTX0JVU1kpKQorCQkJYnJlYWs7CisKKwl9IHdoaWxlICh0aW1lX2JlZm9yZShqaWZmaWVzLCB0aW1lbykpOworCisJKnMgPSBzdGF0dXM7CisJcmV0dXJuIDA7Cit9CisK" | base64 -d > "$NAND_PATCH/600-mtd-spinand-add-skyhigh-robust-read-workaround.patch"
	cd $PKG_PATH && echo "NAND robust-read patch applied!"
fi

#添加IPv6 RA Guard LuCI插件
RABLOCK_DIR="./package/base-files/files/usr/lib/lua/luci/controller"
mkdir -p "$RABLOCK_DIR"
cat > "$RABLOCK_DIR/rablock.lua" << 'RABLOCK_LUA'
module("luci.controller.rablock", package.seeall)

function index()
    entry({"admin", "network", "rablock"}, call("action_rablock"), _("IPv6 RA Guard"), 90)
end

function get_all_interfaces()
    local ifaces = {}
    for _, name in ipairs({"eth0", "eth1"}) do
        local state = "down"
        local sh = io.popen("cat /sys/class/net/" .. name .. "/operstate 2>/dev/null")
        if sh then
            local s = sh:read("*a") or ""
            sh:close()
            if s:match("up") then state = "up" end
        end
        ifaces[#ifaces + 1] = { name = name, state = state, group = "物理接口" }
    end
    local handle = io.popen("ls /sys/class/net/br-lan/brif/ 2>/dev/null")
    if handle then
        for port in handle:read("*a"):gmatch("%S+") do
            local state = "down"
            local sh = io.popen("cat /sys/class/net/" .. port .. "/operstate 2>/dev/null")
            if sh then
                local s = sh:read("*a") or ""
                sh:close()
                if s:match("up") then state = "up" end
            end
            ifaces[#ifaces + 1] = { name = port, state = state, group = "桥接端口" }
        end
        handle:close()
    end
    return ifaces
end

function get_active_rule()
    local handle = io.popen("nft -a list chain bridge filter forward 2>/dev/null | grep nd-router-advert")
    if handle then
        local result = handle:read("*a") or ""
        handle:close()
        local port = result:match('iifname%s+"([^"]+)"')
        local handle_num = result:match("handle%s+(%d+)")
        if port then return port, handle_num end
    end
    return nil, nil
end

function action_rablock()
    local http = require "luci.http"

    local action = http.formvalue("action")
    local selected_port = http.formvalue("port")

    if action == "enable" and selected_port and selected_port ~= "" then
        local _, old_handle = get_active_rule()
        if old_handle then
            os.execute("nft delete rule bridge filter forward handle " .. old_handle)
        end
        os.execute("nft add table bridge filter 2>/dev/null")
        os.execute("nft add chain bridge filter forward '{ type filter hook forward priority 0; }' 2>/dev/null")
        os.execute("nft add rule bridge filter forward iifname \"" .. selected_port .. "\" icmpv6 type nd-router-advert drop")
        os.execute("uci set dhcp.lan.ra=server")
        os.execute("uci set dhcp.lan.dhcpv6=server")
        os.execute("uci set dhcp.lan.ra_default=1")
        os.execute("uci commit dhcp")
        os.execute("/etc/init.d/odhcpd restart")
    elseif action == "disable" then
        os.execute("nft flush chain bridge filter forward 2>/dev/null")
        os.execute("nft delete chain bridge filter forward 2>/dev/null")
        os.execute("nft delete table bridge filter 2>/dev/null")
    end

    local active_port, _ = get_active_rule()
    local ifaces = get_all_interfaces()

    http.prepare_content("text/html")
    http.write([[<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>IPv6 RA Guard</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; max-width: 640px; margin: auto; }
.card { background: #f9f9f9; border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin: 20px 0; }
.status { font-size: 18px; margin: 10px 0; }
.on { color: #22c55e; font-weight: bold; }
.off { color: #ef4444; font-weight: bold; }
.up { color: #22c55e; }
.down { color: #999; }
select { padding: 8px 12px; border-radius: 6px; border: 1px solid #ccc; font-size: 14px; margin: 5px 0; min-width: 200px; }
.btn { display: inline-block; padding: 10px 24px; border: none; border-radius: 6px; cursor: pointer; font-size: 14px; margin: 5px; }
.btn-on { background: #22c55e; color: white; }
.btn-off { background: #ef4444; color: white; }
.desc { color: #666; font-size: 13px; margin-top: 10px; }
table { border-collapse: collapse; margin: 10px 0; }
td, th { padding: 6px 14px; text-align: left; border-bottom: 1px solid #eee; }
</style>
</head>
<body>
<h2>IPv6 RA Guard</h2>
<div class="card">
<p class="status">状态：<span class="]] .. (active_port and "on'>已开启 (" .. active_port .. ")" or "off'>已关闭") .. [[</span></p>
<p class="desc">拦截光猫 RA，让 IPv6 流量经过路由器（旁路由模式专用）。</p>
<p class="desc">原理：在 bridge filter forward 链丢弃指定端口的 RA，同时由 odhcpd 发送路由器自己的 RA。</p>

<h3>接口列表</h3>
<table>
<tr><th>端口</th><th>状态</th><th>RA Guard</th></tr>
]])

    local last_group = ""
    for _, p in ipairs(ifaces) do
        if p.group ~= last_group then
            if last_group ~= "" then http.write('</table><h3>' .. p.group .. '</h3><table><tr><th>端口</th><th>状态</th><th>RA Guard</th></tr>') end
            last_group = p.group
        end
        local state_class = p.state == "up" and "up" or "down"
        local state_text = p.state == "up" and "在线 ↑" or "离线 ↓"
        local is_active = active_port == p.name
        http.write('<tr><td>' .. p.name .. '</td><td class="' .. state_class .. '">' .. state_text .. '</td><td>')
        if is_active then http.write('<b>✓ 拦截中</b>') else http.write('-') end
        http.write('</td></tr>\n')
    end

    http.write([[</table>

<h3>操作</h3>
<form method="post">
<select name="port">
<option value="">-- 选择端口 --</option>
]])

    local last_group = ""
    for _, p in ipairs(ifaces) do
        if p.group ~= last_group then
            if last_group ~= "" then http.write('</optgroup>') end
            http.write('<optgroup label="' .. p.group .. '">')
            last_group = p.group
        end
        local selected = (active_port == p.name) and ' selected' or ''
        local label = p.name .. (p.state == "up" and " (在线)" or " (离线)")
        http.write('<option value="' .. p.name .. '"' .. selected .. '>' .. label .. '</option>\n')
    end
    if last_group ~= "" then http.write('</optgroup>') end

    http.write([[</select>
<br>
]])

    if active_port then
        http.write([[<input type="hidden" name="action" value="disable">
<button type="submit" class="btn btn-off">关闭 RA Guard</button>
]])
    else
        http.write([[<input type="hidden" name="action" value="enable">
<button type="submit" class="btn btn-on">开启 RA Guard</button>
]])
    end

    http.write([[</form>
</div>
</body>
</html>]])
end
RABLOCK_LUA
echo "rablock.lua installed"
