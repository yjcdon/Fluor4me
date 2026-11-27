# Chrome 测试样本

| 用例 | 样本 | 操作与预期 |
| --- | --- | --- |
| CHR-01、CHR-02 · F4 搜索 | [Anthropic 技术文章](https://www.anthropic.com/research/migrating-api-to-rust) | 选中正文标题中的 `Messages API`。按 F4 后，当前 Chrome 配置的默认搜索引擎收到完整词组，无痕结果留在发起窗口。 |
| CHR-01、CHR-02 · F4 中文选区 | [中文维基百科的 Rust 编程语言条目](https://zh.wikipedia.org/wiki/Rust_%28%E7%BC%96%E7%A8%8B%E8%AF%AD%E8%A8%80%29) | 选中标题中的「编程语言」或该页实际显示的繁体变体。按 F4 后核对查询文字和窗口归属。 |
| CHR-01、CHR-02 · F4 直达 | [本地样本](chrome-sample.html)里的真实目标地址 | 分别选中 `rust-lang.org` 和完整的 Rust Book 地址。按 F4 后分别直达对应网页，完整地址须保留路径及两项查询参数。 |
| CHR-04 · F5 复制历史 | [Rust 官网学习页](https://rust-lang.org/learn/) → [Rust Book](https://doc.rust-lang.org/book/) | 在同一个标签里点「Read the Book!」后按 F5。副本应在同一个窗口打开，副本后退到学习页，源标签仍停在 Rust Book。 |
| CHR-01、CHR-03、CHR-04 · 本地对照 | [本地样本](chrome-sample.html) | 用 `C++ 测试`、跨行文本和普通输入框测搜索，用空白、测试密码框和地址栏选区测忽略。点击「打开第二页」建立本地后退记录。 |

本地样本可直接用 Chrome 打开，无需起服务。公开网页改版时，记录实际选中的文字和页面地址。页面加载失败时，分别记录快捷键是否打开了正确目标以及目标是否加载成功。
