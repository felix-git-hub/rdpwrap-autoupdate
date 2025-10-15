# RDP Wrapper Auto-Update for Latest `rdpwrap.ini`

# RDP Wrapper 自动更新最新 `rdpwrap.ini` 文件

## English Version

**RDP Wrapper Auto-Update for Latest `rdpwrap.ini`**

This tool automatically updates the `rdpwrap.ini` file for RDP Wrapper to help support the latest Windows versions.

**Key Features**

* Broader set of sources for downloading `rdpwrap.ini` compared to the original repository.
* Simplified logic: parts originally implemented in VBA have been rewritten entirely in batch script.
* Removed unnecessary features for a leaner, more focused workflow.

**Prerequisites**

1. RDP Wrapper installed. Download from the official releases:
   [https://github.com/stascorp/rdpwrap/releases](https://github.com/stascorp/rdpwrap/releases)

**Usage**

* Run `autoupdate.bat` **as Administrator**.
* You can obtain administrator privileges by either:

  * Right‑click the script and choose **Run as administrator**, or
  * Double‑click the script: the script will prompt for UAC elevation and automatically relaunch elevated if needed.
* The script will attempt to detect your `termsrv.dll` version and replace `rdpwrap.ini` if a matching entry is found in the candidate sources.

**Behavior**

* If the script is not running with administrator privileges, it will attempt to restart itself with elevated permissions (PowerShell `Start-Process -Verb RunAs`) and then exit the non-elevated instance.
* The script supports an optional `autoupdate.conf` to override proxy and candidate URL settings.

**Notes**

* Prefer saving configuration files in UTF-8 (no BOM) when using non-ASCII characters.
* Make sure `curl` is available in PATH (Windows 10/11 usually include `curl`).

---

## 中文版本

**RDP Wrapper 自动更新最新 `rdpwrap.ini` 文件**

本工具用于自动更新 RDP Wrapper 的 `rdpwrap.ini`，以便支持最新的 Windows 版本。

**主要特点**

* 相较原始仓库，增加了更广泛的候选数据源以获取 `rdpwrap.ini`。
* 精简逻辑：原用 VBA 实现的部分功能已全部用批处理（batch）重写。
* 剔除不必要功能，流程更精简、聚焦。

**前置条件**

1. 已安装 RDP Wrapper。请从官方发布页面下载：
   [https://github.com/stascorp/rdpwrap/releases](https://github.com/stascorp/rdpwrap/releases)

**使用方法**

* 以管理员权限运行 `autoupdate.bat`。
* 获取管理员权限的方法包括：

  * 右键脚本选择“以管理员身份运行”，或
  * 直接双击脚本：脚本会提示 UAC 提升并在授权后自动以管理员权限重启自身。
* 脚本会检测 `termsrv.dll` 版本，并在候选源中找到匹配条目时替换 `rdpwrap.ini`。

**行为说明**

* 若脚本未以管理员运行，会尝试使用 PowerShell（`Start-Process -Verb RunAs`）以提升权限并退出当前非管理员实例。
* 脚本支持可选的 `autoupdate.conf`，用于覆盖代理与候选 URL 设置。

**注意**

* 若包含中文或其它非 ASCII 字符，建议使用 UTF-8（无 BOM）保存配置文件。
* 请确保系统中可用 `curl`（Windows 10/11 常自带）。
