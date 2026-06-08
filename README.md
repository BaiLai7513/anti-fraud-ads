# AF_ADS_FUCK — 屏蔽反诈 + 去广告 Magisk 模块

屏蔽ColorOS系统内置反诈相关组件 + 拦截反诈IP(213条) + 冻结官方应用监控 + 冻结OPPO广告 + hosts去广告(17000+条) + chattr锁定广告缓存 + SQLite空壳防广告SDK写入。**保留广告奖励**，不影响游戏内看广告领奖励。

支持 **Magisk / KernelSU / APatch**。

## 模块信息

| 项目 | 内容 |
|------|------|
| ID | `anti_fraud_ads` |
| 版本 | 260607 (2026-06-07) |
| 作者 | Bailai7513 (原作者：10007) |
| 平台 | ColorOS (OPPO/一加) |

## 功能

### 🛡️ 反诈屏蔽
- 拦截 **213 条**反诈相关 IP（iptables DROP）
- REDIRECT 劫持 `com.coloros.phonemanager` / `com.oplus.appdetail` / `com.hicorenational.antifraud` 到 `:8848`（空端口）
- 屏蔽应用列表上传和手机用户数据刻画用户行为肖像

### 🚫 应用冻结
- 冻结 `com.oplus.thirdkit`（智能应用检测/隐私监控）
- 冻结 `com.opos.ad`（OPPO 系统广告）

### 🧹 去广告
- hosts 去广告 **17000+** 条规则（bind mount 覆盖 `/system/etc/hosts`）
- chattr +i 锁定广告缓存目录
- SQLite 空壳防广告 SDK 写入

### 🎮 保留广告奖励
- 游戏内"看广告领奖励"不受影响，仅屏蔽后台偷偷跑的广告

## 快速开始

### 下载

| 文件 | 直链 |
|------|------|
| 📦 模块 zip | [anti_fraud_ads_fix_final.zip](https://raw.githubusercontent.com/BaiLai7513/anti-fraud-ads/main/anti_fraud_ads_fix_final.zip) |
| 🔍 检测脚本 | [check_privacy.sh](https://raw.githubusercontent.com/BaiLai7513/anti-fraud-ads/main/check_privacy.sh) |

### 安装

1. 在 Magisk / KernelSU / APatch 中刷入模块 zip
2. 重启手机
3. 运行检测脚本验证：

```sh
su -c "sh /sdcard/Download/check_privacy.sh"
```

## 检测脚本 (check_privacy.sh)

10 项隐私防护状态检测：

| # | 检测项 |
|---|--------|
| 1 | iptables DROP 规则（反诈IP封锁） |
| 2 | iptables REDIRECT 劫持 |
| 3 | phonemanager 劫持状态 |
| 4 | appdetail 劫持状态 |
| 5 | thirdkit 冻结状态 |
| 6 | OPPO 系统广告冻结状态 |
| 7 | 国家反诈中心劫持状态 |
| 8 | hosts 去广告挂载 |
| 9 | ads_lock 广告缓存锁定 |
| 10 | 反诈IP连通性抽样测试 |

## 项目结构

```
├── anti_fraud_ads_fix_final.zip   # 完整模块包
├── check_privacy.sh               # 隐私防护检测脚本
├── module.prop                    # 模块信息
├── service.sh                     # 开机自启服务
├── uninstall.sh                   # 卸载脚本
├── system/etc/hosts               # hosts 去广告规则 (17000+ 条)
└── mod/
    ├── iptables.sh                # iptables 规则加载
    ├── ads_lock.sh                # 广告缓存锁定
    ├── kernel_su.sh               # KernelSU/APatch 适配
    └── util_functions.sh          # 工具函数
```

## 手动重载

```sh
su -c 'source /data/adb/modules/anti_fraud_ads/mod/iptables.sh'
```

## 查看日志

```sh
cat /data/adb/modules/anti_fraud_ads/module.log
```

## 卸载

在 Magisk/KernelSU/APatch 中移除模块后重启，或手动执行：

```sh
su -c "sh /data/adb/modules/anti_fraud_ads/uninstall.sh"
```

## 免责声明

本模块仅供学习和交流，切勿用于非法用途。如有问题使用者承担法律责任，法律责任与模块开发者无关。
