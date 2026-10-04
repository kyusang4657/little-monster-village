extends SceneTree
## UI 아이콘·대화 얼굴 캡처(검수용, 디스플레이 필요):
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 900x300 --script res://tests/icon_capture.gd -- --out=<폴더> [--kinds=imp,commander,hero,chief]

var out := "/tmp/icons"
var kinds := "imp,commander,hero,chief"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--kinds="):
			kinds = a.substr(8)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	var bg := ColorRect.new()
	bg.color = Color("fdf3dc")
	bg.size = root.get_visible_rect().size
	root.add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(20, 20)
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for k in kinds.split(","):
		var ic := UiIcon.new(k, 112)
		row.add_child(ic)
		var small := UiIcon.new(k, 34)
		row.add_child(small)
	for i in 4:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("icons.png"))
	print("SHOT icons")
	quit(0)
