# anti-fraud-ads (AF_ADS_FUCK)

屏蔽 ColorOS 反诈 + 去广告 + 隐私防护 Magisk/KSU/APatch 模块

## 功能

| 功能 | 说明 |
|------|------|
| hosts 去广告 | 18068 条屏蔽规则，覆盖主流广告/追踪域名 |
| iptables 反诈 IP 拦截 | 213 条 DROP 规则，封锁反诈中心 IP |
| 秋风广告规则 | AWAvenue-Ads-Rule 周更，双源自动降级 (GitHub raw → boki.moe) |
| 系统应用冻结 | pm disable com.oplus.thirdkit + com.opos.ads |
| 广告 SDK 缓存锁定 | chattr +i 锁定 pangle/beizi/gdt/ksad 等 187 个 SDK 目录 |
| SQLite 空壳注入 | 替换广告 SDK 数据库为空壳，阻止写入 |
| ColorOS 劫持 | phonemanager + appdetail → :8848 黑洞 |

## 更新日志

### v260718 (2026-07-18)

- 🐛 修复: 秋风规则 GitHub raw 被墙，新增 boki.moe 双源自动降级
- 🐛 修复: APatch 环境下 Phase3 pm disable 因 package service 未就绪失败，新增 60s 等待轮询
- 🐛 修复: update_rules.sh 历史 if-else 嵌套语法错误
- 🔧 优化: check_privacy.sh 清理旧模块路径引用 (anti_fraud_260517)，版本号同步至 v260718
- 🔧 优化: check_privacy.sh 秋风规则检测标注双源状态
- 📦 hosts 合并秋风规则至 18068 行

### v2600708

- 原始版本，hosts 去广告 + iptables + ads_lock

## 安装

Magisk / KernelSU / APatch 刷入 zip，重启生效。

## 检测

```sh
su -c "sh /data/adb/modules/anti_fraud_ads/check_privacy.sh"
```

## 致谢

- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) 秋风广告规则
