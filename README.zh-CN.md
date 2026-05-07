<p align="center">
  <img src="themes/rocky/assets/rocky-idle-follow.svg" width="160" alt="Rocky">
</p>
<h1 align="center">Rocky on Desk</h1>
<p align="center">
  <a href="README.md">English</a>
</p>
<p align="center">
  <sub>基于 Andy Weir《挽救计划》中 <b>Rocky</b>（洛奇）角色的像素风桌宠。<br>基于 <a href="https://github.com/rullerzhou-afk/clawd-on-desk">clawd-on-desk</a> 框架构建。</sub>
</p>

<p align="center">
  <img src="assets/gif/rocky-idle-follow.gif" width="400" alt="Rocky — 来自波江座的硅基工程师，球形岩石身体，五条蜘蛛腿，金色声纳感应晶体">
</p>

Rocky 住在你的桌面上，实时感知 AI 编程助手在做什么。作为波江座工程师，他用声纳感应器追踪光标，思考时用腿轻敲，任务完成时举起双臂庆祝。

> 基于 **[clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk)** 开源桌宠框架开发。Rocky 是一个自定义主题 — 框架引擎的所有功劳归于 clawd-on-desk 的作者和贡献者。

## Rocky — 波江座工程师

- **球形岩石身体**，带有纹理石板和温暖发光的晶体
- **五条可动蜘蛛腿**，能打字、杂耍、扫地、挥手
- **金色声纳感应晶体**代替眼睛追踪光标
- **完整睡眠序列** — 打哈欠 → 瞌睡 → 倒下 → 睡觉 → 惊醒
- **点击互动** — 拖拽时四肢乱晃，双击时惊喜弹跳

## 动画一览

<table>
  <tr>
    <td align="center"><img src="assets/gif/rocky-idle-follow.gif" width="100"><br><sub>待机</sub></td>
    <td align="center"><img src="assets/gif/rocky-idle-look.gif" width="100"><br><sub>张望</sub></td>
    <td align="center"><img src="assets/gif/rocky-idle-yawn.gif" width="100"><br><sub>打哈欠</sub></td>
    <td align="center"><img src="assets/gif/rocky-idle-doze.gif" width="100"><br><sub>瞌睡</sub></td>
    <td align="center"><img src="assets/gif/rocky-collapse-sleep.gif" width="100"><br><sub>倒下</sub></td>
    <td align="center"><img src="assets/gif/rocky-sleeping.gif" width="100"><br><sub>睡觉</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/gif/rocky-wake.gif" width="100"><br><sub>醒来</sub></td>
    <td align="center"><img src="assets/gif/rocky-working-thinking.gif" width="100"><br><sub>思考</sub></td>
    <td align="center"><img src="assets/gif/rocky-working-typing.gif" width="100"><br><sub>打字</sub></td>
    <td align="center"><img src="assets/gif/rocky-working-juggling.gif" width="100"><br><sub>杂耍</sub></td>
    <td align="center"><img src="assets/gif/rocky-working-building.gif" width="100"><br><sub>建造</sub></td>
    <td align="center"><img src="assets/gif/rocky-working-sweeping.gif" width="100"><br><sub>扫地</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="assets/gif/rocky-working-carrying.gif" width="100"><br><sub>搬运</sub></td>
    <td align="center"><img src="assets/gif/rocky-happy.gif" width="100"><br><sub>开心</sub></td>
    <td align="center"><img src="assets/gif/rocky-error.gif" width="100"><br><sub>报错</sub></td>
    <td align="center"><img src="assets/gif/rocky-notification.gif" width="100"><br><sub>通知</sub></td>
    <td align="center"><img src="assets/gif/rocky-react-drag.gif" width="100"><br><sub>拖拽</sub></td>
    <td align="center"><img src="assets/gif/rocky-react-double.gif" width="100"><br><sub>双击</sub></td>
  </tr>
</table>

## 主题能力

| 能力 | 状态 |
|---|---|
| 眼球/光标追踪 | 声纳感应晶体追踪光标 |
| 完整睡眠序列 | 打哈欠 → 瞌睡 → 倒下 → 睡觉 → 醒来 |
| 工作分级 | 打字(1) → 杂耍(2+) → 建造(3+) |
| 点击反应 | 拖拽晃腿、双击弹跳 |
| 空闲动画 | 光标追踪 + 随机张望 |
| 音效 | 5 词 Rocky 词汇（WAV）— 完成、确认、错误、思考、醒来 |
| 极简模式 | 暂未支持 |

### 可用主题

| 主题 | 描述 |
|---|---|
| **Rocky** | 经典球形岩石身体，金色声纳感应晶体 |
| **Rocky Domed** | 带有保护性氙石穹顶的 Rocky（如在"万福玛利亚号"上所见） |

## 快速开始

### 下载安装（推荐）

1. 从 **[Releases](https://github.com/YingYveltal/rocky-on-desk/releases)** 下载最新安装包
2. 运行 `Rocky-on-Desk-Setup-x64.exe` 安装
3. 从开始菜单启动 **Rocky on Desk**
4. 在设置中选择主题：**Rocky**（经典）或 **Rocky Domed**（带穹顶）

### 连接 Claude Code

让 Rocky 响应 Claude Code 事件，需要安装 hooks：

```bash
cd rocky-on-desk
node hooks/install.js
```

这会在 `~/.claude/settings.json` 中注册命令 hooks。重启 Claude Code 会话后，Rocky 就会根据工具调用、思考、出错等状态自动切换动画。

### 源码运行

```bash
git clone https://github.com/YingYveltal/rocky-on-desk.git
cd rocky-on-desk
npm install
npm start
```

## 致谢

本项目是基于 **[clawd-on-desk](https://github.com/rullerzhou-afk/clawd-on-desk)** 框架开发的自定义主题。

- **clawd-on-desk** — Electron 桌宠引擎，由 [@rullerzhou-afk](https://github.com/rullerzhou-afk)（鹿鹿）及[贡献者](https://github.com/rullerzhou-afk/clawd-on-desk#contributors)创建和维护。基于 AGPL-3.0 许可。
- **Rocky 主题** — 像素美术与角色设计由 [@YingYveltal](https://github.com/YingYveltal) 创作。Rocky 角色来自 Andy Weir 的《挽救计划》。这是一个非官方粉丝作品。
- **《挽救计划》** — Andy Weir 的科幻小说，创造了 Rocky 这个深受读者喜爱的波江座工程师角色。

## 许可证

- **源代码**（引擎、脚本、hooks）：[AGPL-3.0](LICENSE)，继承自 clawd-on-desk。
- **Rocky 主题素材**（`themes/rocky/assets/`）：版权归 [@YingYveltal](https://github.com/YingYveltal) 所有，保留所有权利。
- **其他主题素材**（`themes/calico/`、`themes/clawd/`、`themes/cloudling/`、`assets/`）：版权归各自所有者。详见 [assets/LICENSE](assets/LICENSE)。
