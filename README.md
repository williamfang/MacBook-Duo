# MacBook Duo

MacBook Duo 是一个原生 macOS 菜单栏应用。它读取 MacBook 的真实屏幕角度，在屏幕低于 85° 时冻结内建显示器画面，并以 Metal 实时生成空间锁定、渐进模糊和黑场折叠效果。

## 构建

当前电脑的 Command Line Tools 与 macOS 26.5 SDK 存在小版本不匹配，因此脚本固定使用已安装且可工作的 macOS 15.4 SDK。Metal shader 在应用启动时编译，不要求安装完整 Xcode：

```bash
./test.sh
./build.sh
```

应用生成在 `.build/MacBook Duo.app`。

## 使用

1. 打开应用，在菜单栏点击 MacBook 图标。
2. 点击“授予屏幕录制权限”，在系统设置中允许 MacBook Duo。
3. 重新启动应用。
4. 屏幕低于 85° 自动触发；重新抬到 92° 以上退出。
5. 菜单内滑杆可在不合盖时测试渲染效果。

测试或任何异常情况下按 `Esc` 可立即隐藏覆盖层。

应用只捕获内建显示器的一帧，图像只在内存中使用，不会保存或上传。传感器、权限、捕获或 Metal 初始化失败时，覆盖层保持隐藏。

## 开发者签名

`build.sh` 默认使用 ad-hoc 签名。发布时将末尾的 `codesign` 身份替换为你的 Developer ID Application 证书，并为同一 Bundle ID 创建签名配置。
