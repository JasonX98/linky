# Linky 链可

基于 yt-dlp 的 Windows 桌面视频下载工具（Flutter 开发）。

- 英文名：**Linky**
- 中文名：**链可**
- 发布标识：`identity_name: com.linky.app`（见 `pubspec.yaml` 的 `msix_config:`）

## 开发环境准备

1. 安装 Flutter stable 并启用 Windows 桌面支持（`flutter config --enable-windows-desktop`）
2. **首次构建前必须先下载引擎**（yt-dlp + FFmpeg，约 220MB）：
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\fetch_engine.ps1
   ```
3. `flutter pub get`
4. `flutter run -d windows`

## 测试

```powershell
flutter test
```

## MSIX 打包

MSIX 打包由 dev 依赖 `msix` 提供，配置在 `pubspec.yaml` 的顶层 `msix_config:` 键中
（identity/publisher/display name/logo/capabilities/languages 等）。

生成 MSIX 安装包：

```powershell
flutter pub run msix:create --release
# 或等价的 dart 方式：dart run msix:create --release
```

- 命令会先执行 `flutter build windows`（release），再打包并签名 MSIX。
- 产出文件位于 `build\windows\x64\runner\Release\video_downloader.msix`。
- 未提供证书时使用 `msix` 包自带的**测试证书**签名，仅可用于本机侧载/开发验收；
  正式分发需提供你的 PFX 证书（见下节）。

### 签名证书（需用户提供）

**签名证书必须由用户提供，PFX 证书文件不应提交到仓库。** 提供一个受信任的自签名
证书即可在本地安装测试；发布/商店外分发则需正式的代码签名证书。

1. 在 `pubspec.yaml` 的 `msix_config:` 中配置：

   ```yaml
   msix_config:
     certificate_path: C:\path\to\signcert.pfx
     certificate_password: your-password
     publisher: "CN=Your Publisher, O=Your Org, C=US"
   ```

   或通过命令行传入（优先于 YAML）：

   ```powershell
   flutter pub run msix:create --release --certificate-path C:\path\to\signcert.pfx --certificate-password your-password
   ```

   > `publisher` 为证书 Subject。未提供证书时，`msix` 包会回退到自带的
   > **测试证书** 签名（可正常打包，但非受信任证书，不建议分发）。

2. 默认会提示把证书安装到本机信任存储；
   `--install-certificate false`（或 YAML `install_certificate: false`）可跳过该步骤。
