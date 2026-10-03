extends SceneTree
## THROWAWAY PROBE - delete after use


func _init() -> void:
	p1_stuck()
	p3_mark_lost_repairing()
	p4_story_migration()
	p5_determinism()
	p6_misc()
	p2_bad_types()
	quit(0)


func at_level(cleared: int) -> GameState:
	var s := GameState.new()
	s.new_game()
	s.highest_cleared = cleared
	s.ready_stage = mini(cleared + 1, GameConfig.stage_count())
	s.sync_castle_level()
	return s


func finish(s: GameState) -> void:
	var m := s.mode
	s.mode = GameState.MODE_VILLAGE
	for i in 60 * 60:
		if s.constructing().is_empty():
			break
		s.tick(1.0 / 60.0)
	s.mode = m


func p1_stuck() -> void:
	print("=== P1 stuck knight on outpost capture")
	for south in [false, true]:
		for real_hp in [false, true]:
			for stage in range(4, 11):
				var s := at_level(6)
				s.wood = 500
				s.commit_expand("east")
				if south:
					s.wood = 500
					s.commit_expand("south")
				s.wood = 500
				var r := s.commit_new_building("outpost", 16, 2, 0)
				finish(s)
				var b := BattleSim.new()
				b.setup(s.buildings, s.all_edges(), stage, 1.0, {castle_hp = s.castle_hp() if real_hp else 100000, bounds = s.bounds()})
				var cap_t := -1.0
				var stuck: Array = []
				while b.outcome == "" and b.time < 900:
					b.step(BattleSim.STEP)
					for e in b.events:
						if e.type == "outpost_captured":
							cap_t = b.time
					b.events.clear()
					for k in b.knights:
						if k.state == "stuck" and not stuck.has(k.id):
							stuck.append(k.id)
							print("    stuck knight #%d at %s (t=%.2f) alive=%s" % [k.id, str(k.pos), b.time, str(k.alive)])
				var still_stuck := 0
				for k in b.knights:
					if k.state == "stuck" and k.alive:
						still_stuck += 1
				print("  south=%s realhp=%s stage %d: outpost_ok=%s outcome=%s reason='%s' cap=%.1f stuck=%s alive_stuck_at_end=%d t=%.1f castle=%d" % [str(south), str(real_hp), stage, str(r.ok), b.outcome, b.abort_reason, cap_t, str(stuck), still_stuck, b.time, b.castle_hp])


func p3_mark_lost_repairing() -> void:
	print("=== P3 mark_outpost_lost on repairing / constructing outpost")
	var s := at_level(6)
	s.wood = 500
	s.commit_expand("east")
	s.wood = 500
	s.commit_new_building("outpost", 16, 2, 0)
	var id: String = s.outposts()[0].id
	# under construction
	s.mark_outpost_lost(id)
	var b := s.get_building(id)
	print("  constructing+lost: damaged=%s build_left=%.1f check_repair=%s" % [str(b.get("damaged")), float(b.build_left), str(s.check_repair(id))])
	var w0 := s.wood
	var rr := s.commit_repair(id)
	print("  repair while still constructing: ok=%s wood %d->%d build_left=%.1f repairing=%s" % [str(rr.ok), w0, s.wood, float(b.build_left), str(b.get("repairing"))])
	print("  validate after: '%s'" % GameState.validate_dict(s.to_dict()))
	# repairing then lost
	var t := at_level(6)
	t.wood = 500
	t.commit_expand("east")
	t.wood = 500
	t.commit_new_building("outpost", 16, 2, 0)
	finish(t)
	var id2: String = t.outposts()[0].id
	t.mark_outpost_lost(id2)
	t.wood = 100
	t.commit_repair(id2)
	t.mark_outpost_lost(id2)
	var c := t.get_building(id2)
	print("  repairing+lost: damaged=%s repairing=%s build_left=%.1f" % [str(c.get("damaged")), str(c.get("repairing")), float(c.build_left)])
	finish(t)
	print("  after repair finished: damaged=%s income=%.1f wood=%d" % [str(c.get("damaged")), t.income_rate(), t.wood])
	# mark_outpost_lost on non-outpost
	var u := at_level(6)
	u.mark_outpost_lost("house_01")
	print("  house marked lost: damaged=%s check_repair=%s" % [str(u.get_building("house_01").get("damaged")), str(u.check_repair("house_01"))])


func p4_story_migration() -> void:
	print("=== P4 v2 migration story ids")
	for hc in [9, 10]:
		var s := at_level(hc)
		var d := s.to_dict()
		d.version = 2
		d.erase("expansions")
		d.erase("story_seen")
		var t := GameState.new()
		t.from_dict(d)
		print("  hc=%d story_seen=%s ; has final_start=%s ; has ending=%s" % [hc, str(t.story_seen.keys()), str(t.story_seen.has("final_start")), str(t.story_seen.has("ending"))])
		print("  seen_scenes ids: %s" % str(Story.seen_scenes(t.story_seen).map(func(x): return x.id)))


func p5_determinism() -> void:
	print("=== P5 determinism boss + outpost + south")
	var logs: Array = []
	for run in 2:
		var s := at_level(9)
		for d in ["east", "south", "west", "north"]:
			s.wood = 500
			s.commit_expand(d)
		s.wood = 500
		s.commit_new_building("outpost", 16, 2, 0)
		finish(s)
		var b := BattleSim.new()
		b.setup(s.buildings, s.all_edges(), 10, 1.0, {castle_hp = 100000, bounds = s.bounds()})
		var log := []
		while b.outcome == "" and b.time < 900:
			b.step(BattleSim.STEP)
			for e in b.events:
				log.append(str(e))
			b.events.clear()
		log.append(b.outcome + str(b.castle_hp) + str(b.time))
		logs.append(log)
	print("  identical=%s len=%d" % [str(logs[0] == logs[1]), logs[0].size()])


func p6_misc() -> void:
	print("=== P6 misc")
	# expand while under construction, save/validate
	var s := at_level(6)
	s.wood = 500
	s.commit_new_building("house", 10, 7, 0)
	s.wood = 500
	print("  expand during construction: %s" % str(s.commit_expand("south")))
	s.wood = 500
	s.commit_expand("east")
	s.wood = 500
	s.commit_new_building("outpost", 16, 2, 0)
	s.wood = 500
	s.commit_new_building("flowerbed", 6, -2, 0)
	print("  validate: '%s'" % GameState.validate_dict(JSON.parse_string(JSON.stringify(s.to_dict()))))
	# damaged outpost moved to another site
	var t := at_level(9)
	for d in ["east", "west", "north"]:
		t.wood = 500
		t.commit_expand(d)
	t.wood = 500
	t.commit_new_building("outpost", 16, 2, 0)
	finish(t)
	var id: String = t.outposts()[0].id
	t.mark_outpost_lost(id)
	print("  move damaged outpost to north site: %s" % str(t.commit_move(id, 9, 11, 0)))
	print("  validate: '%s'" % GameState.validate_dict(JSON.parse_string(JSON.stringify(t.to_dict()))))
	# repairing roundtrip with snapping
	t.wood = 100
	t.commit_repair(id)
	print("  validate repairing: '%s'" % GameState.validate_dict(JSON.parse_string(JSON.stringify(t.to_dict()))))


func p2_bad_types() -> void:
	print("=== P2 bad types in save")
	var s := at_level(3)
	for bad in ["east", null, 5, {"a": 1}]:
		var d := JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary
		d.expansions = bad
		print("  expansions=%s -> validate=" % str(bad))
		var res = GameState.validate_dict(d)
		print("     result=%s (type %d)" % [str(res), typeof(res)])
	for bad in [null, 5, "abc"]:
		var d := JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary
		d.story_seen = bad
		var res = GameState.validate_dict(d)
		print("  story_seen=%s -> validate='%s'" % [str(bad), str(res)])
		var t := GameState.new()
		t.from_dict(d)
		print("     from_dict ok? mode=%s story_seen=%s" % [t.mode, str(t.story_seen.keys())])
	var d2 := JSON.parse_string(JSON.stringify(s.to_dict())) as Dictionary
	d2.expansions = [1]
	print("  expansions=[1] -> '%s'" % str(GameState.validate_dict(d2)))
