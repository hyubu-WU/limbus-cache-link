# Limbus Company 缓存转移（Windows）

把《边狱公司》（Limbus Company）在 C 盘 `LocalLow` 里那坨**几个 G 的缓存**，搬到别的盘去，
然后在原位置留一个 **junction（目录符号链接）**，让游戏以为自己还在原地读写。

- 游戏不用重装，存档不受影响
- 缓存实际存在 D 盘（或你指定的任何盘）
- 游戏重装/修复把链接冲成一个真目录时，这个脚本会**把内容搬回去再重建链接**

> 为什么要它：Unity 游戏的缓存默认堆在 `C:\Users\<你>\AppData\LocalLow\Unity\ProjectMoon_LimbusCompany`，
> 玩久了能到 10 GB 以上，C 盘小的机器很容易被吃满。

---

## 它到底动了什么

| 位置 | 说明 |
|---|---|
| `%LOCALAPPDATA%Low\Unity\ProjectMoon_LimbusCompany` | **链接**（junction），指向下面那个真实目录 |
| `D:\LimbusCache`（可改） | **真实缓存目录**，所有文件在这儿 |

只动这两个路径，**不碰存档**（存档在 `%LOCALAPPDATA%Low\ProjectMoon\LimbusCompany`，是另一个目录）。

---

## 用法

### 一、改配置（可选）

第一次用，编辑 `config.json`：

```json
{
  "Link": "C:\\Users\\你的用户名\\AppData\\LocalLow\\Unity\\ProjectMoon_LimbusCompany",
  "Target": "D:\\LimbusCache",
  "GameProcess": "LimbusCompany"
}
```

- `Link`：游戏期望缓存所在的位置，一般不用改，把"你的用户名"换成自己的
- `Target`：你想让缓存实际待在哪儿
- `GameProcess`：游戏进程名，用来判断"游戏是不是在跑"

### 二、跑

双击 `一键修复.cmd`，或者：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-LimbusCacheLink.ps1
```

它会依次：

1. 发现游戏在跑 → 什么都不做，直接退出（避免抢文件）
2. 目标目录不存在 → 建一个
3. 链接指向正确 → 报个"完好"就退出
4. 链接指向错了 → 拆掉重建
5. **发现链接位置变成了真目录**（重装最常见）→ 用 robocopy 把内容搬回目标盘，确认源目录空了，再重建链接
6. 每一步失败都**停下、不改动**，并把原因写进日志

### 三、开机自动跑（可选）

任务计划程序 → 创建任务 → 触发器"登录时" → 操作：

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\你的路径\Fix-LimbusCacheLink.ps1" -Quiet
```

加 `-Quiet` 就只写日志、不弹窗。

---

## 日志

`%LOCALAPPDATA%\LimbusCacheLink\fix-link.log`，一行一次运行结果。

---

## 常见问题

**Q：游戏更新/重装之后缓存又跑回 C 盘了？**
跑一次脚本就行。它会检测到"链接位置变成了真目录"，把内容搬回去、重建链接。
建议挂成开机任务，省得记。

**Q：会不会丢数据？**
脚本只在**源目录已经搬空**之后才删源目录；任何一步出错都会停下并保留现场。
搬运用 `robocopy /MOVE`，先复制成功再删源。

**Q：能用在别的 Unity 游戏上吗？**
能。把 `Link` 换成那个游戏在 `LocalLow\Unity` 下的目录，`GameProcess` 换成它的进程名即可。

**Q：删除链接会不会把缓存也删了？**
不会。junction 只是个路标，删路标不影响目标目录里的文件。
但反过来——**用"删除"按钮删真目录会删文件**，所以脚本里用的是 `rmdir`（只摘链接）。

---

## 许可

MIT。
