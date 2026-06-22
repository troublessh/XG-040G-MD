# OpenWRT-CI

贝尔040G系列，全面升级6.18内核  
详细说明  
https://www.right.com.cn/forum/thread-8453612-1-1.html

## 支持设备

四个固件通用，设备名称只是区分不同功能

| 设备 | WAN口 | USB |
|------|-------|-----|
| XG-040G-MD | LAN4 | ✅ |
| XG-140G-MD | 2.5G | ✅ |
| XG-040G-TF | LAN4 | ❌ |
| XG-140G-TF | 2.5G | ❌ |

## 固件简要说明

- **ImmortalWrt 版本**：25.12（6.18 分支）
- **Linux Kernel**：6.18
- **登录地址**：192.168.1.100
- **默认主题**：aurora

<div align="center">
  <img src="https://raw.githubusercontent.com/eamonxg/assets/master/aurora/preview/theme/multi-device-showcase.png" alt="Aurora Theme" width="100%">
  <br>
  <img src="https://raw.githubusercontent.com/eamonxg/assets/master/aurora/preview/theme/preview-demo.gif" alt="Theme Demo" width="100%">
  <br>
  <img src="https://raw.githubusercontent.com/eamonxg/assets/master/aurora/preview/theme/dark-light-preview.png" alt="Dark and Light" width="49%">
  <img src="https://raw.githubusercontent.com/eamonxg/assets/master/aurora/preview/theme/mobile-preview.png" alt="Mobile" width="49%">
</div>

## 目录简要说明

| 目录 | 用途 |
|------|------|
| workflows | GitHub Actions CI 配置 |
| Scripts | 自定义脚本（包拉取、后处理、设置） |
| Config | 设备及通用 .config 配置 |

## 与上游分支的改动

**MAC 地址**：原版每次启动随机生成 MAC（`openssl rand`），改为以 `GITHUB_RUN_ID` 为种子生成固定 MAC。同一固件内所有 LAN 接口共享同一 MAC，WAN（lan4）为 LAN MAC +1。每次编译 MAC 不同，多台设备同网段不冲突。

**CPU 温度监控**：LuCI 状态菜单新增 CPU Temperature 页面（`files/` overlay 注入），5 秒自动刷新。

**主题**：默认主题从 argon 改为 aurora（基于 Vite + Tailwind CSS，支持深色/浅色切换、移动端适配、PWA 安装）。

**插件调整**

移除：
- openclash、homeproxy、wolplus

新增：
- smartdns、ttyd、zerotier、mwan3、sqm、nlbwmon、diskman、arpbind、syncdial、vlmcsd

保留：
- passwall、ddns-go、autoreboot、samba4、upnp、aurora 主题

**其他**
- 默认登录地址：192.168.1.100
- 默认 WiFi SSID：OpenWrt

## 源码引用

| 项目 | 来源 |
|------|------|
| ImmortalWrt 源码 | [bingoguo93/immortalwrt](https://github.com/bingoguo93/immortalwrt) (6.18 分支) |
| CI 模板 | [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) |
| aurora 主题 | [eamonxg/luci-theme-aurora](https://github.com/eamonxg/luci-theme-aurora) |
| ddns-go | [sirpdboy/luci-app-ddns-go](https://github.com/sirpdboy/luci-app-ddns-go) |

## 致谢

- [bingoguo93](https://github.com/bingoguo93) — XG-040G 系列设备适配及源码维护
- [VIKINGYFY](https://github.com/VIKINGYFY) — CI 编译框架
- [ImmortalWrt](https://github.com/immortalwrt) — 上游源码

[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)
