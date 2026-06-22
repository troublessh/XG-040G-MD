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
- **登录地址**：192.168.1.10
- **默认主题**：argon

## 目录简要说明

| 目录 | 用途 |
|------|------|
| workflows | GitHub Actions CI 配置 |
| Scripts | 自定义脚本（包拉取、后处理、设置） |
| Config | 设备及通用 .config 配置 |

## 源码引用

| 项目 | 来源 |
|------|------|
| ImmortalWrt 源码 | [bingoguo93/immortalwrt](https://github.com/bingoguo93/immortalwrt) (6.18 分支) |
| CI 模板 | [VIKINGYFY/OpenWRT-CI](https://github.com/VIKINGYFY/OpenWRT-CI) |
| argon 主题 | [sbwml/luci-theme-argon](https://github.com/sbwml/luci-theme-argon) |
| ddns-go | [sirpdboy/luci-app-ddns-go](https://github.com/sirpdboy/luci-app-ddns-go) |

## 致谢

- [bingoguo93](https://github.com/bingoguo93) — XG-040G 系列设备适配及源码维护
- [VIKINGYFY](https://github.com/VIKINGYFY) — CI 编译框架
- [ImmortalWrt](https://github.com/immortalwrt) — 上游源码

[![Stargazers over time](https://starchart.cc/VIKINGYFY/OpenWRT-CI.svg?variant=adaptive)](https://starchart.cc/VIKINGYFY/OpenWRT-CI)
