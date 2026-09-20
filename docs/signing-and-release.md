# Android 正式签名与发布

## 正式签名身份

- 首个正式签名版本：`1.0.0`（versionCode `3000`）
- 应用 ID：`com.local.shanghaitech_timetable`
- 密钥别名：`shanghaitech-timetable-release`
- 算法：RSA 4096 位
- 证书 SHA-256：`B2:2E:92:06:8D:18:D8:B8:E0:A0:58:2D:B4:B3:31:75:7C:6C:39:5B:A9:CA:04:DF:A8:48:72:EC:D1:1D:C2:11`
- 证书主体：`CN=ShanghaiTech Timetable Personal Project, OU=Personal Project, O=Personal, L=Shanghai, ST=Shanghai, C=CN`

证书主体明确表示这是个人项目，不表示上海科技大学对应用进行了认证或背书。

## 本机密钥位置

密钥和恢复信息保存在：

`%USERPROFILE%\.android\shanghaitech-timetable-release\`

密码不进入 Git，也不应写入公开文档。`mobile/android/key.properties` 仅存在于本机，并已被 `.gitignore` 排除。

## 必须长期遵守的规则

1. 所有 `1.0.0` 之后的正式更新都必须使用同一把密钥。
2. 每次发布必须递增 `pubspec.yaml` 中 `+` 后面的 versionCode。
3. 密钥文件和恢复信息必须一起做至少一份安全的离线备份。
4. 不得把密钥、恢复文件或 `key.properties` 提交到 Git、网盘公开链接或发送给其他人。
5. 开发签名版不能直接覆盖升级到正式签名版；迁移时先导出 `.sttb`，卸载开发版，安装正式版，再恢复备份。
