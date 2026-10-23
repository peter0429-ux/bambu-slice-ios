# 怎么拿到能装进 iPhone 的 ipa

我这边（Windows）出不了 ipa。原因很硬：

- ipa 里的可执行文件必须是 **arm64 的 Mach-O**，只能由 macOS 上的 clang + iOS SDK 产出
- 打包要用 Xcode 的 `xcodebuild`，Windows 上没有
- 最后一步签名必须绑定**你的 Apple ID 和设备 UDID**，这个无论如何得你自己做

所以流程拆成两半：**用 GitHub 的 macOS 机器编译 → 你在 Windows 上签名安装。**

---

## 路线 A：GitHub Actions（不需要 Mac，推荐）

### 1. 把工程推到 GitHub

```bash
cd bambu-slice-ios
git init
git add .
git commit -m "init"
# 在 GitHub 上建一个空仓库，然后：
git remote add origin git@github.com:<你的用户名>/bambu-slice-ios.git
git push -u origin main
```

`.github/workflows/build-ipa.yml` 已经写好了，push 上去会自动跑。

### 2. 等它跑完

仓库页面 → **Actions** → 最新那次运行 → 页面底部 **Artifacts** → 下载 `BambuSlice-unsigned-ipa`。

解压得到 `BambuSlice-unsigned.ipa`。

> 第一次运行**大概率会失败**，因为这份代码我没法在本地编译验证。
> 失败时展开 “Show compiler errors”，日志里会直接给出 `文件名:行号: error: ...`。
> 把那一段发给我，我照着改。这比在 Mac 上逐个试快得多。

### 3. 先改 Bundle ID（重要）

`project.yml` 里现在是 `com.example.bambuslice`。同一个 Apple ID 下面
这个 ID 只能被一个 App 占用；如果你之前签过别的包用了同样前缀会冲突。

改成你自己的，比如：

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.你的名字.bambuslice
```

改完再 push 一次。

### 4. 在 Windows 上签好并装进手机

需要两个东西：

- **iTunes**（或微软商店的「Apple 设备」）—— 提供 USB 驱动
- **Sideloadly** —— https://sideloadly.io

步骤：

1. iPhone 用数据线连电脑，手机上点「信任此电脑」
2. 打开 Sideloadly，把 `BambuSlice-unsigned.ipa` 拖进 **IPA** 框
3. **Apple ID** 填你的（普通 Apple ID 就行，不需要开发者账号）
4. 点 **Start**，输入 Apple ID 密码（有些账号要走 App 专用密码）
5. 装完后在手机上：**设置 → 通用 → VPN与设备管理 → 开发者App → 信任**

### 5. 打开「开发者模式」

iOS 16 之后，自己签名的 App 必须开这个才能启动：

**设置 → 隐私与安全性 → 开发者模式 → 打开 → 重启 → 确认**

（这个开关只有装过自签 App 之后才会出现。）

---

## 免费 Apple ID 的限制

用普通 Apple ID（Personal Team）签名，要接受这些：

| 限制 | 值 |
|---|---|
| 证书有效期 | **7 天**，到期 App 打不开，要重新签 |
| 同时安装的自签 App | 最多 3 个 |
| 每 7 天能注册的 App ID | 10 个 |
| 推送通知 / App Groups / iCloud | ❌ 不可用（本工程没用到） |

**每 7 天重签一次**是免费路线的常态。嫌麻烦的话：

- **AltStore** 配 AltServer，在同一个 Wi-Fi 下自动续签，iPhone 上点一下就行
- 或者花 99 美元/年 加入 Apple Developer Program，签名有效期变成 1 年

---

## 路线 B：有 Mac 的时候

```bash
cd bambu-slice-ios
bash scripts/make_ipa.sh
```

同样产出 `BambuSlice-unsigned.ipa`。

如果那台 Mac 上已经登录了你的 Apple ID，更省事的做法是直接在 Xcode 里：
选真机 → Signing & Capabilities 勾上 Automatically manage signing → ⌘R，
直接装到手机上，连 ipa 都不用导。

> 没有 Mac 又不想用 GitHub：MacinCloud / MacStadium 这类云 Mac 按小时租，
> 一小时大约 1 美元，装好 Xcode 后跑 `make_ipa.sh` 一样能出包。

---

## 一句提醒：现在这个包还不是「Bambu Studio」

工程默认 `BAMBU_CORE_ENABLED=0`，走的是内置**参考引擎**。所以你现在装上的版本：

- ✅ 能导入 STL/OBJ、能切片、能逐层看路径、能导出 G-code
- ❌ 不生成支撑、不做桥接、G-code 不能上机打印
- ❌ 没有 libslic3r

也就是说，这一版是用来**验证外壳和链路**的。真内核要按 `docs/PORTING.md`
把依赖编出来、把 `BAMBU_CORE_ENABLED` 改成 1，之后同一个 ipa 流程再走一遍。

先跑通这条链，再换引擎——顺序反了会很难定位问题。

---

## 排错

| 现象 | 原因 |
|---|---|
| Actions 卡在 `brew install xcodegen` | GitHub 偶发慢，重跑一次 |
| `error: Signing for "BambuSlice" requires a development team` | 说明 `CODE_SIGNING_ALLOWED=NO` 没生效，检查 workflow 里那三行 |
| 产物里没有 `.app` | 编译成功了但产物路径变了，看 `ls -R build/Build/Products` 的输出 |
| Sideloadly 报 `Failed to install` | 手机没信任电脑 / iOS 版本高于 Sideloadly 支持 / 忘了开开发者模式 |
| App 装上但一点就闪退 | 证书没被信任，去「VPN与设备管理」里点信任 |
| 7 天后打不开 | 证书过期，重新签一次，正常现象 |
