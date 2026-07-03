# Anti-Fraud & Ad Blocker (反诈去广告 Magisk 模块)

## 功能

- 🔒 **屏蔽 ColorOS 反诈**：iptables DROP 国家反诈中心 IP（213+ 条）
- 🚫 **拦截反诈上传**：REDIRECT phonemanager / appdetail / 国家反诈中心流量到 :8848
- ❄️ **冻结隐私监控**：pm disable com.oplus.thirdkit（智能应用检测）
- 📢 **冻结系统广告**：pm disable com.opos.ad（OPPO 广告组件）
- 🛡️ **Hosts 去广告**：17000+ 条屏蔽规则
- 🔄 **秋风广告规则**：自动订阅 AWAvenue-Ads-Rule，7 天更新一次


## 使用

Magisk / KernelSU / APatch 刷入，重启即可。

## 脚本说明

| 脚本 | 用途 |
|------|------|
| `check_update.sh` | 模块更新检测脚本 |
| `check_privacy.sh` | 实际效果检测脚本 |

## 效果检测

刷入重启后验证模块是否生效：

**方式一（推荐）：** 用 MT 管理器 / NP 管理器进入 `/data/adb/modules/anti_fraud_ads/`，直接点击 `check_privacy.sh` 执行。

**方式二：** 终端执行：
```bash
su -c "sh /data/adb/modules/anti_fraud_ads/check_privacy.sh"
```

## 检测问题
部分防护需要开机2~3分钟生效

## 卸载

Magisk中移除模块重启。

## 许可

原作者：10007  
维护：BaiLai7513

## 注意事项
本模块仅适用于中国大陆Oppo或一加手机，切勿用于非法用途，仅适用于保护隐私，同时请注意避免被诈骗。文件请从官方源下载，第三方有风险。
