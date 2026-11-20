# Status —（已降级为字段约定，A52 裁决采纳）

> **不再是独立概念（v0.13，R12）**：Status 无对象、无 Kind，只是字段约定。
> conditions / observedGeneration / phase / drift 的结构规范**并入 core/scheme.yaml 的 Status 约定节**（conventions.status）；
> 各对象文档里的 status 示例照旧有效，只是不再有独立概念文档与"Status 子系统"式的演进。
