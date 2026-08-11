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

## 安装

Magisk / KernelSU / APatch 刷入 zip，重启生效

## 实际测试效果

## 反馈
反馈请提issues

## 致谢

- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) 秋风广告规则

## 注意事项
- 模块建议从github下载使用，三方获取存在风险，仅用用保护个人隐私，切勿用于非法用途。
