# iCar - AI 智能车辆检测助手

基于 iPhone 传感器与端侧 AI 的汽车健康检测工具 App，支持中英双语。

## 功能模块

| 模块 | 功能 | AI 模型 |
|------|------|---------|
| 🔧 EngineEar 引擎听诊 | 录制发动机声音（最长15秒），AI 频谱分析诊断爆震、皮带异响、轴承磨损、气门敲击、缺缸等故障 | EngineSoundClassifier (CoreML) |
| 🎨 PaintScan 漆面检测 | 拍摄车身照片，AI 识别划痕、凹陷、掉漆等漆面损伤 | CarDamageDetector (CoreML) |
| 🛞 TireTread 轮胎检测 | 拍摄轮胎照片，AI 测量胎面内/中/外三处花纹深度，评估磨损状态 | TireTreadDepth (CoreML) |

## 应用截图与页面

- 🏠 **产品主页**: [icar-app.com](https://athenalion007.github.io/iCar/)
- 📄 **产品页 (中文)**: [docs/index.html](docs/index.html)
- 📄 **产品页 (英文)**: [docs/index-en.html](docs/index-en.html)
- 🔒 **隐私政策 (中文)**: [docs/privacy-policy.html](docs/privacy-policy.html)
- 🔒 **隐私政策 (英文)**: [docs/privacy-policy-en.html](docs/privacy-policy-en.html)
- 🆘 **技术支持 (中文)**: [docs/support.html](docs/support.html)
- 🆘 **技术支持 (英文)**: [docs/support-en.html](docs/support-en.html)

## 技术栈

- **UI**: SwiftUI (iOS 16.0+)
- **架构**: MVVM
- **AI**: CoreML 端侧推理，无需网络
- **国际化**: .xcstrings + LanguageManager (中文/英文/跟随系统)
- **项目生成**: xcodegen
- **CI/CD**: GitHub Actions (构建 + 测试 + 安全检查)

## 项目结构

```
iCar/
├── iCarApp.swift                          # 应用入口 (@main)
├── Info.plist                             # 权限声明等配置
├── project.yml                            # xcodegen 项目描述
├── .swiftlint.yml                         # SwiftLint 代码规范
├── Core/
│   ├── AppConstants.swift                 # 全局常量
│   ├── LanguageManager.swift              # 运行时语言切换
│   └── DetectionHistory.swift             # 检测历史持久化 (UserDefaults)
├── Theme/
│   └── Theme.swift                        # 色彩/字体/间距设计系统
├── Components/
│   ├── ICButton.swift                     # 通用按钮
│   ├── ICCard.swift                       # 通用卡片
│   ├── ICFullscreenCamera.swift           # 全屏相机组件
│   └── RecordingWaveView.swift            # 录音波形动画
├── Utils/
│   ├── L10n.swift                         # 类型安全的本地化字符串
│   └── UnitFormatter.swift                # 数值/单位格式化
├── Resources/
│   ├── Localizable.xcstrings              # 应用文本 (zh-Hans + en)
│   └── InfoPlist.xcstrings                # 权限描述 (zh-Hans + en)
├── Models/
│   ├── EngineSoundClassifier.mlpackage    # 发动机声音分类模型
│   ├── CarDamageDetector.mlpackage        # 车损检测模型
│   └── TireTreadDepth.mlmodel             # 轮胎花纹深度模型
├── Services/
│   ├── EngineSoundClassifierService.swift # 发动机声音分类服务
│   ├── CarDamageDetectorService.swift     # 车损检测服务
│   └── TireTreadDetector.swift            # 轮胎深度检测服务
├── Views/
│   ├── ContentView.swift                  # Tab 导航 (首页/历史/设置)
│   ├── HomeView.swift                     # 首页功能入口
│   ├── HistoryView.swift                  # 检测历史记录
│   ├── SettingsView.swift                 # 设置（语言/权限/清数据）
│   ├── EngineEar/                         # 引擎听诊模块
│   ├── PaintScan/                         # 漆面检测模块
│   └── TireTread/                         # 轮胎检测模块
├── Assets.xcassets/                       # 图标/主题色
└── docs/                                  # GitHub Pages 文档站点
```

## 开发方式

### 前置要求

- Xcode 14.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

### 生成项目

```bash
cd /path/to/iCar
xcodegen generate --spec project.yml
open iCar.xcodeproj
```

### 运行

在 Xcode 中选择目标设备（模拟器或真机），Cmd+R 即可运行。

> **注意**: CoreML 模型推理在模拟器上功能受限，建议在真机上测试 AI 检测功能。

## 国际化

- 🇨🇳 中文简体 (zh-Hans)
- 🇺🇸 英文 (en)
- 🔄 跟随系统语言

所有用户可见文本通过 `L10n` 枚举访问，对应 `.xcstrings` 中的 key。运行时通过 `LanguageManager.shared` 切换语言，即时生效。

## CI/CD

项目配置了 GitHub Actions 自动化流水线 ([ci.yml](.github/workflows/ci.yml)):

- **构建测试**: Xcode build + test + 静态分析（检查 TODO/FIXME、空函数、代码风格）
- **代码覆盖率**: 生成覆盖率报告并上传 Codecov
- **安全检查**: 检查硬编码密钥/密码和 debug 代码

触发条件: push 到 `main`/`develop` 分支，或 PR 到 `main`。

## 设计原则

- 🎨 **专业简洁** - 主色调不超过 3 种
- ⚡ **操作快捷** - 每个功能不超过 3 步
- 💬 **提示精悍** - 一句话说清楚

## 隐私

所有 AI 推理在设备端完成，数据不离开手机。详见 [隐私政策](docs/privacy-policy.html)。

- ✅ 本地 AI 处理，无需网络
- ✅ 照片、录音不上传云端
- ✅ 检测历史可随时清除
- ✅ 不收集位置/运动传感器数据

## 许可证

© 2026 iCar. All rights reserved.
