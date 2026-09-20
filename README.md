# 上科大课表

面向 Android 的本地优先课表应用。用户在应用内打开上海科技大学官方统一身份认证页面并自行登录；应用复用登录成功后的临时会话读取研究生系统课表，不收集或保存学校密码。

> 本项目是个人开发的非官方工具，与上海科技大学官方无隶属或授权关系。课程信息以学校教务系统为准。

## 功能

- 登录学校统一身份认证并同步研究生课表。
- 按教学周显示具体日期、上课时间、课程名称和教室。
- 使用 SQLite 在本地离线保存课表。
- 支持主题、自定义背景、背景收藏与历史。
- 支持完整 `.sttb` 备份与恢复。
- 同步前预览课表变化。
- 不连续周次、临时换日和不同节次数均按学校返回数据处理。

## 隐私边界

- 密码只输入学校官方页面。
- 不将密码、Cookie、会话令牌或课表上传到第三方服务器。
- 不把真实学生身份信息、会话抓包或个人课表样本提交到仓库。
- 日志不得记录认证信息、学号或完整服务端响应。

## 下载与安装

正式 APK 不提交到 Git 历史；公开发布时应作为 GitHub Release 附件上传。当前正式版本为 `v1.0.1`，支持 Android 7.0 及以上的 ARM64 设备。

从开发签名版迁移到正式签名版时，需要先导出 `.sttb`，卸载开发版，安装正式版，再恢复备份。`v1.0.0` 及之后的正式版可以直接覆盖升级。

## 开发环境

- Flutter 3.47.5
- Dart 3.13.4
- JDK 17
- Android SDK 36

仓库中的应用工程位于 `mobile/`。本地 SDK、构建缓存、签名密钥和 `android/key.properties` 均不会上传。

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

没有正式签名材料时仍可进行开发和调试，但不能生成可冒充正式发布者的更新包。正式发布流程及公开证书指纹见 [docs/signing-and-release.md](docs/signing-and-release.md)。

## 项目结构

```text
mobile/      Flutter Android 应用
docs/        接入研究、实现计划和版本说明
scripts/     本地开发辅助脚本
```

教务系统接入方式与数据字段说明见 [docs/integration-research.md](docs/integration-research.md)。

## 作者

夜斗绽星明

## 许可证

源代码采用 [MIT License](LICENSE)。上海科技大学名称、校徽、标志、商标及其他品牌素材不属于 MIT 授权范围，详见 [BRANDING.md](BRANDING.md)。
