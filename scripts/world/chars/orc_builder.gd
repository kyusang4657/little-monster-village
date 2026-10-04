class_name OrcBuilder
extends RefCounted
## 꼬마 오크(4차 유닛)의 메시·골격 정의


static func build() -> Dictionary:
	return GoblinBuilder.build(2, true, true)
