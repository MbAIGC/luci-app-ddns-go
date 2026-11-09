# luci-app-ddns-go（Lua CBI 版）

[DDNS-GO](https://github.com/jeessy2/ddns-go) 的 LuCI 界面，改造自
[sirpdboy/luci-app-ddns-go](https://github.com/sirpdboy/luci-app-ddns-go)。

**本 fork 的唯一目的：把上游的 ucode/JS 前端换成 Lua CBI**，让它在使用
**Lua 派发器**的 LuCI 上能正常显示和工作（LEDE / Lean / 带 `luci-compat` 的固件）。

## 为什么需要这个 fork

上游包只包含这些文件：

```
/usr/share/luci/menu.d/luci-app-ddns-go.json     ← JSON 菜单
/www/luci-static/resources/view/ddns-go/*.js     ← JS 视图
/usr/share/rpcd/ucode/luci.ddns-go               ← ucode RPC 对象
```

它们工作依赖 **ucode 派发器 + JS 前端**（`/www/luci-static/resources/luci.js`）。
在 Lua 派发器的固件上：

- `menu.d/*.json` 没人读 → 菜单不出现
- JS 视图没有加载器 → 即使菜单出现也是空白

判断自己的固件属于哪种：

```sh
uci -q get uhttpd.main.ucode_prefix     # 有值 = ucode；空 = Lua
ls -l /www/luci-static/resources/luci.js # 存在 = 有 JS 前端
```

本 fork 把这三个资源全部改为 Lua（controller + CBI + 模板），
Lua 派发器直接执行，不再需要 rpcd/ucode。

## 目录结构

一个插件一个文件夹，后续要加别的插件直接并列即可：

```
.
├── ddns-go/                     # 上游的 ddns-go 二进制包（Go 构建，本仓库 CI 不构建）
│   ├── Makefile
│   └── files/                   # 默认配置 + init 脚本
├── luci-app-ddns-go/            # ← 本 fork 改造的 LuCI 插件
│   ├── Makefile                 # 纯文件包，PKGARCH:=all，不依赖 luci.mk
│   ├── luasrc/
│   │   ├── controller/ddns_go.lua
│   │   ├── model/cbi/ddns_go/config.lua
│   │   └── view/ddns_go/{panel.htm,log.htm}
│   └── root/etc/uci-defaults/99-luci-ddns-go
├── tools/lint.sh
└── .github/workflows/build.yml  # 24.10.5 SDK 出 IPK
```

> Lua 模块名用 `ddns_go`（下划线），因为 `require` 的模块路径里带 `-` 容易踩坑；
> 菜单路径仍是 `admin/services/ddns-go`。

## 页面

| 菜单项 | 实现 | 说明 |
|---|---|---|
| 控制面板 | `view/ddns_go/panel.htm` | 内嵌 `http://<host>:<端口>` 的 ddns-go Web UI；未运行 / 已禁用 Web / HTTPS 混合内容都有对应提示 |
| 基础设置 | `model/cbi/ddns_go/config.lua` | 启用、端口、更新间隔、比对间隔、DNS、跳过证书校验、禁用 Web、延迟启动；另含「重置面板密码」「检查更新」和版本显示 |
| 日志 | `view/ddns_go/log.htm` | `logread` 过滤 ddns-go 的最近 200 行，可刷新 / 清空（清空会重启 log 服务，影响所有服务日志） |

## 与上游的差异

| 项 | 上游 | 本 fork |
|---|---|---|
| 前端 | ucode + JS（`menu.d` + `view/*.js`） | Lua CBI + Lua 模板 |
| 依赖 | `+ddns-go` | `+ddns-go +luci-base +luci-compat` |
| 构建 | `luci.mk`（需要 luci feed） | 纯 `package.mk`，CI 不需要 feeds |
| 版本检查 | ucode RPC `luci.ddns-go` | Lua 直接 `ddns-go -v` / `ddns-go -u` |
| 重置密码 | JS 调 `fs.exec` | CBI Button 服务端执行 |
| 运行时 | 需要 rpcd-mod-ucode | 不需要 ucode |
| 包版本 | 1.6.8 | 1.6.9（区分上游） |

功能面保持一致，没有删减。

## 构建

CI 用 24.10.5 的 x86-64 SDK，只构建 `luci-app-ddns-go`（包是 `all` 架构，任意 24.10.x 都能装）。
`ddns-go/` 那个 Go 包不在 CI 里构建——你需要时从上游 Release 拿现成 IPK 即可。

```sh
# 本地
git tag v1.6.9 && git push origin master --tags   # 触发 Release
```

产物：`luci-app-ddns-go_1.6.9-r1_all.ipk`

## 安装

```sh
# 1) 先确保 ddns-go 本体已安装（上游 Release 里的 ddns-go_*_x86_64.ipk）
opkg install /tmp/ddns-go_6.17.1-r1_x86_64.ipk

# 2) 再装本插件
opkg install /tmp/luci-app-ddns-go_1.6.9-r1_all.ipk
```

装完打开 **服务 → DDNS-GO**。若菜单没出现：

```sh
rm -f /tmp/luci-indexcache
/etc/init.d/uhttpd reload
```

## 注意

- `ddns-go -u`（检查更新）会**直接替换 `/usr/bin/ddns-go`**，不经过 opkg。
  之后 `opkg list-installed` 里显示的版本会和实际二进制不一致，这是上游行为，页面里已注明。
- 本插件不管理域名解析记录，那些在 ddns-go 自带面板里配，存在
  `/etc/ddns-go/ddns-go-config.yaml`（属于 `ddns-go` 包，卸载本插件不会动它）。
- 卸载本插件只删 LuCI 页面，不影响 ddns-go 服务。

## 许可

MIT，见 [LICENSE](LICENSE)。原项目版权归 sirpdboy。
