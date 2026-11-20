# Selector —（已删除，A47）

> **本概念已删除（v0.11，R8 后裁决："Selector 在新系统中没啥用"）**。
> 原三处用途全部有更直接的归处：
> 1. 事件路由 → 按**事件类型 + involved/owner + scope** 直达（scheme.dispatch，无标签匹配）；
> 2. 能力匹配 → WorkService.capabilities 字段（本来就是字段不是标签）；
> 3. 观测聚合 → 按 Kind/scope/owner 聚合。
> metadata.labels 降级为自由注释性元数据，**不再承载选择语义**。
