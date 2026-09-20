# 项目介绍

屏蔽 ColorOS 反诈 + 去广告 + 隐私防护 Magisk / KernelSU / APatch 模块

> 本模块仅用于保护个人隐私，请勿用于非法用途。

## v260828新版调整说明

**调整原因：拦截广告能力过弱。**

- 经实测，原先依赖 hosts 云端订阅的方案，实际拦截广告能力过弱，因此本版**去除 hosts 订阅去广告**：
  - 移除 `mod/update_rules.sh` 云端订阅拉取逻辑（不再开机自动拉取/合并云端规则）；
  - 仅保留**少部分基础 host**（`system/etc/hosts`，国内广告 SDK 精准拦截）与**其他增强去广告能力**（iptables 定向拦截、广告缓存 / SQLite 锁定、广告组件冻结等）。
- **需要 hosts 订阅的用户，请下载旧版本**；也可以改用 `AdGuard for root` 这类 Magisk 模块（也可选择其他同类模块，通常有更多定向优化）。

## hosts 订阅推荐（国内）

> 以下规则仅推荐给需要 hosts 订阅的用户，搭配 `AdGuard for root` 等模块使用；本模块不再内置订阅。

- 实测拦截率约 96%（测试站点：<https://paileactivist.github.io/toolz/adblock.html>）

1. **10007 去广完整订阅规则**
   `https://raw.githubusercontent.com/lingeringsound/10007/main/all`
2. **秋风广告规则**
   `https://raw.githubusercontent.com/TG-Twilight/AWAvenue-Ads-Rule/main/AWAvenue-Ads-Rule.txt`
3. **GOODBYEADS**
   `https://raw.githubusercontent.com/8680/GOODBYEADS/master/data/rules/dns.txt`

## 使用注意事项

- hosts 订阅类方案可能存在**误杀率过高**的问题：
  - 某个软件出现异常时，先打开该软件查看日志，对被拦截的域名点击**放行**；
  - 临时应对可以直接**关闭模块运行**，重启后恢复。
- 模块建议从 GitHub 下载使用，三方渠道获取存在风险。

## 主要功能

- 屏蔽系统内置反诈组件，拦截国家反诈相关 IP（iptables DROP）
- 冻结 / 禁用系统广告与隐私监控相关包（`com.oplus.thirdkit`、`com.opos.ads`）
- 广告缓存目录清理 + SQLite 空壳替换 + `chattr +i` 锁定（ads_lock）
- 少量静态 hosts，国内广告 SDK 精准拦截

## 安装

Magisk / KernelSU / APatch 刷入 zip，重启生效。

## 实际测试效果

- 手动开机 3~5 min 后再测试，完全生效需要时间
- 自检脚本：`/data/adb/modules/anti_fraud_ads/mod/self_check.sh`
- 自检日志：`/data/adb/modules/anti_fraud_ads/self_check.log`

## 致谢

- [lingeringsound/10007](https://github.com/lingeringsound/10007) — 10007 的 hosts 订阅规则源
- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) — 秋风广告规则
- [8680/GOODBYEADS](https://github.com/8680/GOODBYEADS) — GOODBYEADS 规则
