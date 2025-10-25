# Video Mute

一个简单的iOS应用，用于快速处理视频的音频部分。

## 功能特点

- **批量静音**: 一次性处理多个视频文件，移除音频
- **部分静音**: 选择视频片段进行静音处理
- **视频预览**: 处理前后预览视频效果
- **保存到相册**: 将处理后的视频保存到设备相册

## 系统要求

- iOS 15.0+
- Xcode 13.0+

## 安装使用

1. 克隆项目到本地
```bash
git clone git@github.com:xiaoyan-hou/video-mute.git
```

2. 使用Xcode打开 `videoMute.xcodeproj`

3. 连接iOS设备或选择模拟器

4. 点击运行按钮构建并启动应用

## 使用说明

1. 打开应用后，选择"批量静音"或"部分静音"功能
2. 从相册中选择要处理的视频
3. 根据需要调整设置
4. 点击处理按钮开始处理
5. 处理完成后，可以预览并保存结果

## 技术栈

- SwiftUI
- AVFoundation
- Core Data
- PhotosUI

## 许可证

[MIT License](LICENSE)

## 贡献

欢迎提交问题报告和功能请求。