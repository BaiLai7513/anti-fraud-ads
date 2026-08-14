

# anti-fraud-ads (AF_ADS_FUCK)

屏蔽 ColorOS 反诈 + 去广告 + 隐私防护 Magisk/KSU/APatch 模块

## 功能

| 功能 | 说明 |
|------|------|
| hosts 云端订阅 | 自动拉取双源合并去重（lingeringsound/10007 reward + AWAvenue 秋风广告规则），7 天自动更新，多镜像容错（GitHub raw → boki.moe → jsdelivr） |
| iptables 反诈 IP 拦截 | 213 条 DROP 规则，封锁反诈中心 IP |
| 系统应用冻结 | pm disable com.oplus.thirdkit + com.opos.ads |
| 广告 SDK 缓存锁定 | chattr +i 锁定 pangle/beizi/gdt/ksad 等 187 个 SDK 目录 |
| SQLite 空壳注入 | 替换广告 SDK 数据库为空壳，阻止写入 |
| ColorOS 劫持 | phonemanager + appdetail → :8848 黑洞 |

## hosts 云端订阅（完全订阅化）

- 模块**不再内置完整 hosts 规则**（仅占位兜底），改为开机后自动拉取云端规则，7 天自动更新，无需手动替换
- 无网时占位 hosts 生效，有网后自动补拉
- 订阅源：
  - [lingeringsound/10007](https://github.com/lingeringsound/10007) — reward 规则（hosts 格式，含大量广告/追踪域名 + 网络加速映射）
  - [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) — 秋风广告规则（Adblock 格式自动转换）
- 每个源 3 条镜像链，直连失败自动切换

## 自定义订阅（替换拦截广告源）

模块默认订阅上述双源，如需自行替换/添加订阅源：

- **刷写前**：编辑 zip 内 `mod/update_rules.sh`，修改源地址变量后重新打包刷入
  - 源1（reward）：`REWARD_URL` / `REWARD_FB1` / `REWARD_FB2`
  - 源2（秋风）：`AWA_URL` / `AWA_FB1` / `AWA_FB2`
- **刷写后**：直接编辑设备上的 `/data/adb/modules/anti_fraud_ads/mod/update_rules.sh`，改完执行
  ```sh
  sh /data/adb/modules/anti_fraud_ads/mod/update_rules.sh
  ```
  hosts更新立即生效（无需重启）
- 规则格式支持：
  - **hosts 格式** `0.0.0.0 域名` → 直接可用
  - **Adblock 格式** `||域名^` → 保留脚本内置的 sed 转换逻辑

## 安装

Magisk / KernelSU / APatch 刷入 zip，重启生效

## 实际测试效果
- 手动开机3~5min后再测试，完全生效需要时间
- 测试脚本路径:/data/adb/modules/anti_fraud_ads/mod/self_check.sh
- 测试日志路径:/data/adb/modules/anti_fraud_ads/self_check.log

## 反馈
bug反馈等请提供/data/adb/modules/anti_fraud_ads/self_check.log提交issues


## 致谢

- [lingeringsound/10007](https://github.com/lingeringsound/10007) — 10007的hosts订阅规则源
- [TG-Twilight/AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule) — 秋风广告规则

## 注意事项
- 模块建议从github下载使用，三方获取存在风险，仅用于保护个人隐私，切勿用于非法用途。
- 模块卸载会自动清除规则并恢复冻结应用，但 `chattr +i` 锁定的文件/目录需手动执行 `chattr -i` 恢复，或重启后等待对应应用重新创建。
