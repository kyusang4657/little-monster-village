class_name BattleAdvisor
extends RefCounted
## 전투가 끝난 뒤 시뮬레이션 기록(사거리 밖 길, 쏘지 못한 탑, 성 피해 등)을 보고 다음 판 조언을 고른다.
## 생성형 AI가 아니다. 정해진 한국어 문장 틀에 위치 단어만 채우며, 같은 입력이면 항상 같은 조언이 나온다.

const MAX_TIPS := 3


## 논리 좌표 → "정문 쪽 왼쪽" 같은 위치 말
static func place_words(p: Vector2) -> String:
	var side := "가운데"
	if p.x < 5.0:
		side = "왼쪽"
	elif p.x > 9.0:
		side = "오른쪽"
	var depth := "마을 가운데"
	if p.y <= 2.5:
		depth = "정문 쪽"
	elif p.y >= 5.0:
		depth = "성 앞"
	return "%s %s" % [depth, side]


## 방어탑 사거리가 닿지 않는 길 칸 중 가장 길게 이어진 구간. {length, center}
static func longest_uncovered(sim: BattleSim) -> Dictionary:
	var best := {length = 0, center = Vector2.ZERO}
	var paths: Array = []
	for l in sim.lanes:
		paths.append(l.path)
	if paths.is_empty() and not sim.route.is_empty():
		paths.append(sim.route)
	for path in paths:
		var run: Array = []
		for i in path.size() + 1:
			var covered := true
			if i < path.size():
				var c: Vector2i = path[i]
				covered = _covered(sim, Vector2(c.x + 0.5, c.y + 0.5))
			if not covered:
				run.append(path[i])
			elif not run.is_empty():
				if run.size() > int(best.length):
					var mid: Vector2i = run[run.size() / 2]
					best = {length = run.size(), center = Vector2(mid.x + 0.5, mid.y + 0.5)}
				run = []
	return best


static func _covered(sim: BattleSim, p: Vector2) -> bool:
	for t in sim.towers:
		if (t.center as Vector2).distance_to(p) <= float(t.range):
			return true
	return false


static func advise(sim: BattleSim, state: GameState) -> Array[String]:
	var tips: Array[String] = []
	var won := sim.outcome == "win"
	var reached := 0
	for k in sim.knights:
		if bool(k.get("reached", false)):
			reached += 1
	var castle_damage := sim.castle_max - sim.castle_hp
	# 1. 공사 중이라 빠진 탑
	if not sim.constructing_towers.is_empty():
		tips.append("공사 중이던 방어탑 %d개는 싸우지 않았어요. 공사가 끝난 뒤 방어를 시작해 보세요." % sim.constructing_towers.size())
	# 2. 사거리가 닿지 않는 길
	var gap := longest_uncovered(sim)
	if int(gap.length) >= 2 and (not won or castle_damage > 0):
		tips.append("%s 길(%d칸)은 방어탑이 닿지 않아요. 그 근처에 방어탑을 두어 보세요." % [place_words(gap.center), int(gap.length)])
	# 3. 한 번도 쏘지 못한 탑
	for t in sim.towers:
		if int(t.shots) == 0:
			tips.append("%s 방어탑은 한 번도 쏘지 못했어요. 기사가 지나가는 길 가까이 옮겨 보세요." % place_words(t.center))
			break
	if not won:
		# 4. 화력 부족: 강화·추가 건설
		var lv1 := 0
		for t in sim.towers:
			if int(t.level) < 2:
				lv1 += 1
		var cost_up := int(GameConfig.tower_level(2).get("upgrade_cost", 60))
		if lv1 > 0:
			tips.append("방어탑을 강화하면 공격력이 %d→%d로 올라요(목재 %d)." % [int(GameConfig.tower_level(1).damage), int(GameConfig.tower_level(2).damage), cost_up])
		if state.count_type("defense_tower") < state.max_count("defense_tower"):
			tips.append("방어탑을 하나 더 지으면(목재 %d) 훨씬 든든해요." % state.build_cost("defense_tower"))
		if state.interior_fences.is_empty():
			tips.append("울타리로 길을 돌아가게 만들면 방어탑이 더 오래 쏠 수 있어요.")
		if not state.assist_enabled and state.consecutive_losses >= int(GameConfig.raids().get("assist", {}).get("after_losses", 2)):
			tips.append("어렵다면 메뉴에서 도움 모드를 켜 보세요. 계속 지면 기사 체력이 조금 줄어요.")
	else:
		if castle_damage == 0:
			tips.append("완벽한 방어! 성이 피해를 하나도 입지 않았어요.")
		elif reached > 0:
			tips.append("기사 %d명이 성에 닿아 피해 %d를 입었어요. 성 앞쪽을 더 단단히 지켜 보세요." % [reached, castle_damage])
		var next := GameConfig.stage(sim.stage_id + 1)
		if not next.is_empty():
			tips.append("다음 습격은 기사 %d명(체력 %d)이에요. 미리 준비해 두세요." % [int(next.knight_count), int(next.knight_hp)])
	if tips.size() > MAX_TIPS:
		tips.resize(MAX_TIPS)
	return tips
