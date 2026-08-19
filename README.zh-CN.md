<div align="center">

<img src="docs/icon.png" alt="GestaltEdit 应用图标" width="128" height="128">

# GestaltEdit

**直接在 iPhone 和 iPad 上运行的 MobileGestalt 工具**

<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/daily?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>
<a href="https://trendshift.io/repositories/128548?utm_source=trendshift-badge&amp;utm_medium=badge&amp;utm_campaign=badge-trendshift-128548" target="_blank" rel="noopener noreferrer"><img src="https://trendshift.io/api/badge/trendshift/repositories/128548/weekly?language=Swift" alt="frs0n%2FGestaltEdit | Trendshift" width="250" height="55"/></a>

<p>
  <a href="https://github.com/frs0n/GestaltEdit/releases/latest"><img src="https://img.shields.io/github/v/release/frs0n/GestaltEdit?style=flat-square&label=release&color=6E56CF" alt="最新版本"></a>
  <a href="https://github.com/frs0n/GestaltEdit/releases"><img src="https://img.shields.io/github/downloads/frs0n/GestaltEdit/total?style=flat-square&label=downloads&color=6E56CF" alt="下载量"></a>
  <a href="https://github.com/frs0n/GestaltEdit/stargazers"><img src="https://img.shields.io/github/stars/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="Stars"></a>
  <img src="https://img.shields.io/badge/iOS%20%7C%20iPadOS-27-000000?style=flat-square&logo=apple&logoColor=white" alt="支持平台">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/frs0n/GestaltEdit?style=flat-square&color=6E56CF" alt="MIT 许可证"></a>
</p>

<a href="https://github.com/frs0n/GestaltEdit/releases/latest"><b>下载 IPA</b></a> ·
<a href="#系统要求与签名">系统要求</a> ·
<a href="#使用-iloader-签名安装">安装</a> ·
<a href="#使用方法">使用方法</a> ·
<a href="README.md">English</a>

</div>

GestaltEdit 是一款直接在 iPhone 和 iPad 上运行的 MobileGestalt 工具——无需电脑、无需侧载主机、无需连线。它读取设备的 `com.apple.MobileGestalt.plist`，提供常用功能预设、完整的字段编辑器，以及备份 / 导入 / 恢复流程。

> [!WARNING]
> 本项目使用私有 API 并修改系统缓存数据。错误的 MobileGestalt 取值可能破坏系统功能或界面行为，严重时需要刷机恢复。请仅在你本人拥有或已获授权管理的设备上使用。

> [!IMPORTANT]
> 本项目完全免费、开源，严禁以任何形式售卖本 App 或其二次打包、修改版本。如发现有人售卖，请举报。

## 功能

### MobileGestalt 预设

- 灵动岛设备子类型与备用支持标志
- 「关于本机」中显示的设备型号名称
- 开关机铃声、充电限制、轻点唤醒与相机控制设置
- Apple Pencil、操作按钮与车祸检测设置
- 息屏显示、AOD 鲜明度、壁纸视差与液态玻璃低性能模式
- 台前调度、iPad 应用兼容性，以及 Nugget 的 iPadOS `CacheData` 补丁
- Siri AI 美区、Apple 内部安装、内部存储与安全研究设备模式

预设沿用 Nugget 的暂存应用模型：开关代表下一次写入的改动，所有已选改动由底部的「应用」按钮统一提交。写入成功后选择项会被清空。写入值相互冲突的选项之间互斥。

### 字段编辑器

- 在 `CacheExtra` 与 plist 顶层搜索键和值
- 编辑 String、Integer、Float、Boolean、Data、Array 与 Dictionary 类型的值
- 添加或删除 `CacheExtra` 字段
- 保存后回读文件以校验写入结果
- 校验通过后自动注销，改动无需手动重启即可生效

### 备份

- 手动备份当前的 MobileGestalt 文件
- 每次写入前自动保留原始 plist
- 通过系统文件选择器导入 `.plist` 文件
- 导入前校验顶层字典与 `CacheExtra`
- 导出、恢复与删除本地备份

导入只会把文件拷贝进 GestaltEdit 的备份库，并不会立即修改系统文件。恢复时会先备份当前文件，再写入所选备份。

## 系统要求与签名

- 支持的系统版本：iOS 与 iPadOS 18，以及 27 beta 1 至 beta 4
- 一种可以对 IPA 进行签名并安装的方式，例如 [iLoader](https://github.com/nab138/iloader)
- 设备已开启开发者模式
- Bundle identifier：`me.ssus.gestaltedit`

GestaltEdit 在访问 MobileGestalt 前会检查当前系统版本号。当前版本接受 iOS 与 iPadOS 18（任意 build；bad_query 在 iOS 18 上的支持上游未验证，属 "ymmv"），以及 27 beta 1–4（24A5355q、24A5370h、24A5380h、24A5380i、24A5380l、24A5390f）。Apple 随时可能改变这些私有行为。

## 使用 iLoader 签名安装

GestaltEdit 在 [Releases](https://github.com/frs0n/GestaltEdit/releases/latest) 页面提供可直接安装的 IPA。[iLoader](https://github.com/nab138/iloader) 可以用你自己的 Apple ID 对它进行签名并安装。

1. 从 [Releases](https://github.com/frs0n/GestaltEdit/releases/latest) 下载最新的 `GestaltEdit.ipa`。
2. 从 [iloader.app](https://iloader.app/) 或其 [GitHub Releases](https://github.com/nab138/iloader/releases) 安装 iLoader（支持 Windows、Linux 与 macOS）。
3. 用数据线把 iPhone 或 iPad 连接到电脑，打开 iLoader 并登录你的 Apple ID（仅用于本地签名）。
4. 在 iLoader 中导入刚下载的 IPA，让它完成签名并安装到设备。
5. 若设备提示信任开发者证书，请前往「设置」→「通用」→「VPN 与设备管理」进行信任。

## 使用方法

1. 安装并打开 GestaltEdit，等待它读取 MobileGestalt。
2. 在「工具」标签页勾选需要的改动，然后点击「应用」。
3. 需要精确编辑 plist 时，使用「字段」标签页。
4. 在「备份」标签页创建、导入、导出或恢复备份。
5. 写入或恢复成功后，GestaltEdit 会自动刷新 SpringBoard，使改动生效。

## 致谢

- [Nugget](https://github.com/leminlimez/Nugget) —— MobileGestalt 预设与 iPadOS `CacheData` 思路
- [FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) —— ContainerManager 文件访问研究
- [bad_query](https://github.com/forcequitOS/bad_query) —— 基于路径的 ContainerManager 沙盒逃逸
- [0xJohnny](https://x.com/0xjohnny) —— MobileHouseArrest / ContainerManager 概念验证
- [neospring](https://github.com/rooootdev/neospring) —— WebKit 注销实现

GestaltEdit 是独立实现的项目，与 Apple 及上述项目均无隶属关系。

## 许可证

[MIT License](LICENSE)
