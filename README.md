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
- 应用私有目录广告缓存备份锁定 + SQLite 空壳替换（ads_lock，可回滚，不触碰 /data/media）
- 少量静态 hosts，国内广告 SDK 精准拦截

## 存储安全与回滚（v3）

> 背景：旧版本的 `mod/ads_lock.sh` 会扫描 `/data/media/*/Android/data`，并对匹配目录执行
> `rm -rf`、`chmod 000`、`chattr +i`。这些操作会直接落在 Android 共享存储（FUSE/MediaProvider）
> 管理的路径上；在部分 ColorOS 设备上，它与 `/storage/emulated/0` 不可访问、内部存储显示 0B
> 的故障同时出现。两者是否存在直接因果关系仍需更多设备日志验证，但旧实现缺少备份和回滚，
> 本身就是不可接受的工程风险，因此 v3 做了以下调整。

### 现在的修改边界

- **不再处理共享存储**：`/data/media/*`、`/storage/emulated/*`、`/sdcard/*`、
  `/mnt/media_rw/*`、`/mnt/runtime/*` 全部拒绝，代码中没有可绕过的开关。
- `ads_lock.sh` 只扫描/处理应用私有目录：`/data/data/<pkg>/...` 与 `/data/user/<uid>/...`。
- 修改前先记录原路径、权限、属主、immutable 状态，并把原目录/文件移动到
  `backup/payload/`；SQLite 先复制到 `backup/sqlite/` 再替换为空壳。
- 所有记录写入 `backup/state.tsv`。脚本不依赖全盘 `find` 猜测哪些路径被修改过。
- 单个路径失败只跳过该路径并写日志，不会中断整个脚本；`chattr` 不可用时降级为 `chmod`。

### 手动回滚

```sh
# 模块目录通常为 /data/adb/modules/anti_fraud_ads
sh /data/adb/modules/anti_fraud_ads/mod/rollback.sh --dry-run   # 只列出将要恢复的条目
sh /data/adb/modules/anti_fraud_ads/mod/rollback.sh             # 实际恢复
```

卸载模块时会自动执行 `rollback.sh`；如果恢复失败，`uninstall.sh` 会把
`backup/` 复制到 `/data/local/tmp/anti_fraud_ads_rollback_<时间戳>`，避免模块目录被删除后备份丢失。
恢复失败的条目会保留在 `state.tsv`，请按日志人工处理。

### 配置

安装后生成 `config.conf`（已存在则不覆盖）：

```sh
AFADS_ADS_LOCK_ENABLED=1      # 广告缓存锁定总开关
AFADS_DRY_RUN=0               # 1=只扫描并记录，不修改文件
AFADS_MAX_DB_BACKUP_MB=64     # 单个 SQLite 备份上限，超过则跳过
```

### 从旧版本升级

旧版本没有 `state.tsv`，因此 v3 **无法自动推断并恢复旧版本已经锁定过的共享存储路径**。
如果设备曾出现存储 0B，建议先禁用模块并检查：

```sh
ls -ld /storage/emulated/0 /data/media/0
sm list-volumes all
lsattr -d /data/media/0/Android/data/* 2>/dev/null | grep ' i'
```

不要为了“清理”而直接对 `/data/media` 执行 `chattr -i`/`chmod`；请先确认路径属于本模块
曾经处理过的广告缓存目录，并在备份/记录后再操作。

### 故障排查

- 内部存储显示 0B、`/storage/emulated/0` 报 `Transport endpoint is not connected`：
  先禁用所有存储相关模块（包括 FuseFixer）重启，确认是哪个模块/框架组合触发。
- 自检日志：`/data/adb/modules/anti_fraud_ads/self_check.log`，包含
  `sm list-volumes all`、`ls -ld /storage/emulated/0`、`state.tsv` 和备份数量。
- 卸载时不要使用 `iptables -F OUTPUT` 手工清理；v3 的 `uninstall.sh` 只删除本模块
  添加的规则（`mod/iptables.sh --cleanup`），不会清空其他模块/防火墙的规则。


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
