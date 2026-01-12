整体还可继续的方向：
功能层
- 完整 Rust Anchor 宏语法等价（真正 #[account(...)]/#[derive(Accounts)] 级别的语法糖与解析）
- 事件索引字段的更多语义（如多字段 index 校验）
- IDL 自动写入 idl/ 目录的主仓库集成（不仅 anchor 子包）

这三项里你想先做哪一项？
x 1) 完整 Rust Anchor 宏语法等价  
2) 事件索引字段更多语义校验  
3) 主仓库集成 IDL 自动写入 idl/ 目录

客户端层
- 生成 TypeScript/JS client（如果需要对齐 Anchor 生态）
- 生成 accounts/types 的更高阶 decode/encode helpers
运行时/约束层
- 完整 constraint 运行时验证（constraint = <expr> 的实际执行，而不是仅 IDL 输出）
另外：仓库还有未跟踪的 TODO.md。要我处理它（提交或忽略）吗？
你想优先走哪个方向？
