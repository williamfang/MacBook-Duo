# MacBook Duo

MacBook Duo 是一个源码可见的原生 macOS 应用。它读取 MacBook 的真实屏幕角度，在屏幕低于设定角度时冻结内建显示器画面，并以 Metal 保持画面边缘和像素坐标不变。连续毛玻璃覆盖全屏，以宽渐变保持从上向下的方向感。

如果这个项目对你有帮助，欢迎通过 [Ko-fi 支持 William Fang](https://ko-fi.com/williamfang)。

## 构建

当前电脑的 Command Line Tools 与 macOS 26.5 SDK 存在小版本不匹配，因此脚本固定使用已安装且可工作的 macOS 15.4 SDK。Metal shader 在应用启动时编译，不要求安装完整 Xcode：

```bash
./test.sh
./build.sh
```

应用生成在 `.build/MacBook Duo.app`。

应用图标源文件为 `Resources/AppIcon-master.png`。需要重新生成 `.icns` 时运行：

```bash
swift -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  -module-cache-path .build/module-cache \
  Tools/generate-icon.swift Resources/AppIcon-master.png Resources/AppIcon.icns
```

## 使用

1. 打开应用；控制窗口、Dock 图标和菜单栏的 `Duo` 图标都会出现。
2. 点击“授予屏幕录制权限”，在系统设置中允许 MacBook Duo。
3. 重新启动应用。
4. 屏幕低于 90° 自动触发；重新抬高后自动退出。
5. 菜单内滑杆可在不合盖时测试渲染效果。

控制窗口的“上下模糊差异”范围为 0–50%。0% 表示全屏模糊一致，50% 表示底部模糊强度为顶部的 50%；默认值为 30%，修改后自动保存。

“开始变化角度”和“完全模糊与变暗角度”两个滑块范围为 0–90°，默认分别为 90° 与 30°。模糊和暗度共用这段角度区间同步变化，两个端点至少相差 5°，设置自动保存。

“启用透视变形”默认开启：画面随折叠进度产生轻微纵向压缩和顶部透视收拢，底边保持为虚拟铰链；关闭后只保留原有模糊与暗度效果。选择会自动保存。

测试或任何异常情况下按 `Esc` 可立即隐藏覆盖层。

应用只捕获内建显示器的一帧，图像只在内存中使用，不会保存或上传。传感器、权限、捕获或 Metal 初始化失败时，覆盖层保持隐藏。

## 开发者签名

默认构建使用 ad-hoc 签名。若希望更新后保持稳定身份并减少屏幕录制权限失效，可显式传入自己的 Developer ID Application 证书：

```bash
MACBOOK_DUO_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./build.sh
```

## 许可证

本项目采用自定义的[源码参考许可证](LICENSE)：

- 个人、非商业学习和参考可以免费使用。
- 分享代码或衍生作品时必须明确注明原作者 **William Fang** 及本项目地址。
- 任何商业用途均须事先取得付费商业授权。

商业授权及其他许可咨询：<william.fang@qq.com>
