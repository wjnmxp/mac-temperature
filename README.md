# mac-temperature

一个为 Apple M5 Mac 开发的菜单栏温度计。打开应用后，屏幕顶部会显示芯片温度和温度计图标。

## 功能

- 默认显示 CPU 传感器的最高温度，每 3 秒刷新一次。
- 点击菜单栏图标可查看 CPU 最高温度、CPU 平均温度、GPU 最高温度、系统散热状态、更新时间和传感器详情。
- 可切换菜单栏显示 CPU 或 GPU 温度，并选择 3、5 或 10 秒的刷新间隔。设置会自动保存。
- 通过 AppleSMC 只读获取芯片内部温度，运行时无需管理员权限。读数暂不可用时，菜单栏显示 `--°C` 并自动重试。

## 适用的 Mac

已在 **搭载 Apple M5 的 MacBook Air** 上验证。当前版本使用 M5 的传感器映射。其他 M5 机型、M5 Pro / Max、其他 Apple 芯片及 Intel Mac 均未验证，温度读数可能不可用。构建目标最低为 macOS 13.0，实际可用性还取决于 Mac 型号和传感器映射。

## 编译

在 Mac 上安装 Xcode Command Line Tools。已经安装的可以跳过这条命令。

```bash
xcode-select --install
```

登录有仓库访问权限的 GitHub 账号，在仓库页面选择 **Code → Download ZIP**，解压后进入包含 `build.sh` 的目录，在终端执行：

```bash
zsh build.sh
```

脚本会在同一目录生成 `温度计.app`，并进行本地临时签名。

## 使用

在 Finder 中双击 `温度计.app`，然后在屏幕顶部的菜单栏查看读数。点击图标可以调整显示项和刷新间隔，或选择 **退出温度计**。如需登录后自动运行，在 **系统设置 → 通用 → 登录项** 中添加应用。

也可以在应用所在目录运行下面的命令，检查当前 Mac 能读到哪些传感器：

```bash
./温度计.app/Contents/MacOS/MacTemperature --check
```

更多细节见 [使用说明](使用说明.txt)。传感器映射参考 [Stats](https://github.com/exelban/stats)，许可见 [第三方许可证](THIRD-PARTY-LICENSE.txt)。
