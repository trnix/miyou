# 手机侧载安装 HAP 指南(Windows)

## 一、手机开启开发者模式

1. **设置 → 关于手机**,连续快速点击「版本号」7 次,提示进入开发者模式。
2. **设置 → 系统与更新 → 开发人员选项**,打开 **USB 调试**。

## 二、电脑安装 hdc

1. 用华为账号登录 [华为开发者下载中心](https://developer.huawei.com/consumer/cn/download/),下载 **Windows 版 Command Line Tools** 并解压(不必安装完整 IDE)。
2. hdc 位于解压目录的 `sdk/default/openharmony/toolchains` 下,把该目录加入系统 PATH(此电脑 → 属性 → 高级系统设置 → 环境变量 → Path → 新建)。
3. 验证:打开 PowerShell 执行 `hdc`,能看到帮助信息即成功。

## 三、连接并安装

```powershell
hdc list targets                        # 应显示一串设备序列号
hdc install .\app-signed.hap           # 换成你下载的 HAP 路径
```

安装成功后,手机桌面会出现「米柚」图标。

首次连接时手机会弹出「是否允许 USB 调试」授权框,点允许;USB 连接方式选「传输文件」。

## 四、常见安装失败排查

| 现象 | 处理 |
|---|---|
| 提示签名校验失败 / install failed due to signature | 最常见原因是当前设备 UDID 没有注册进调试 Profile:去 AGC 设备管理补注册、重新申请 Profile 并重新构建。其次是证书/Profile 过期,去 AGC 确认有效期 |
| 用了发布证书签名的包 | 调试安装要用调试证书签名的包,确认 CI 用的是调试证书那套 Secrets |
| `hdc list targets` 为空 | 换数据线/USB 口,确认手机上已授权调试,检查驱动 |
| 装到别的手机失败 | 正常:调试包只能装到 Profile 中注册过的设备 |
| 下载的 HAP 是 `app-unsigned.hap` | 说明 CI 没配置签名 Secrets(或非 tag 构建只出了未签名包),按 docs/signing.md 配置后重新构建 |

## 五、卸载

设置 → 应用与服务 → 应用管理 → 米柚 → 卸载;或 `hdc uninstall com.miyou.app`(与你实际的 bundleName 一致)。
