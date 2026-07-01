# Anti-Fraud & Ad Blocker (反诈去广告 Magisk 模块)

## 功能

- 🔒 **屏蔽 ColorOS 反诈**：iptables DROP 国家反诈中心 IP（213+ 条）
- 🚫 **拦截反诈上传**：REDIRECT phonemanager / appdetail / 国家反诈中心流量到 :8848
- ❄️ **冻结隐私监控**：pm disable com.oplus.thirdkit（智能应用检测）
- 📢 **冻结系统广告**：pm disable com.opos.ad（OPPO 广告组件）
- 🛡️ **Hosts 去广告**：17000+ 条屏蔽规则
- 🔄 **秋风广告规则**：自动订阅 AWAvenue-Ads-Rule，7 天更新一次

## 版本

当前: 260701

## 使用

Magisk / KernelSU / APatch 刷入，重启即可。

## 脚本说明

| 脚本 | 用途 |
|------|------|
| `check_update.sh` | 模块更新检测脚本 |
| `check_privacy.sh` | 实际效果检测脚本 |

## 卸载

Magisk 中移除模块。

## 许可

原作者：10007  
维护：BaiLai7513