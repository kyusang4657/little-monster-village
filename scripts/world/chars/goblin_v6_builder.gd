class_name GoblinV6Builder
extends RefCounted
## 6차 교체 후보(고블린 일꾼 3종). 아직 5차 빌더에 위임하는 자리표시자 — 조각 구·회전체·이어진 관(DemonGeo)으로 다시 만든다.


static func build(v: int, with_hammer: bool) -> Dictionary:
	return GoblinBuilder.build(v, with_hammer)
