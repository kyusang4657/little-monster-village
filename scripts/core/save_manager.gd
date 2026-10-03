class_name SaveManager
extends RefCounted
## 기기 안 저장. 임시 파일에 쓴 뒤 교체하고, 직전 정상본을 백업으로 남긴다.

var dir: String = "user://"
var last_message: String = ""


func _init(p_dir: String = "user://") -> void:
	dir = p_dir if p_dir.ends_with("/") else p_dir + "/"


func save_path() -> String:
	return dir + "save.json"


func backup_path() -> String:
	return dir + "save.bak.json"


func tmp_path() -> String:
	return dir + "save.tmp.json"


func save(state: GameState) -> bool:
	var text := JSON.stringify(state.to_dict(), "\t")
	var f := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if f == null:
		last_message = "저장 실패: %s" % error_string(FileAccess.get_open_error())
		push_error(last_message)
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# 방금 쓴 임시 파일이 온전한지 확인한 뒤 교체한다.
	var check = JSON.parse_string(FileAccess.get_file_as_string(tmp_path()))
	if GameState.validate_dict(check) != "":
		last_message = "저장 검증 실패: " + GameState.validate_dict(check)
		push_error(last_message)
		return false
	var da := DirAccess.open(dir)
	if da == null:
		return false
	if FileAccess.file_exists(save_path()):
		var current = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
		if GameState.validate_dict(current) == "":
			if FileAccess.file_exists(backup_path()):
				da.remove(backup_path().get_file())
			da.copy(save_path(), backup_path())
	var err := da.rename(tmp_path().get_file(), save_path().get_file())
	if err != OK:
		last_message = "저장 교체 실패: %s" % error_string(err)
		push_error(last_message)
		return false
	return true


## 불러오기. 결과: {status: "new"|"loaded"|"backup"|"reset", message}
func load_into(state: GameState) -> Dictionary:
	var has_main := FileAccess.file_exists(save_path())
	var has_bak := FileAccess.file_exists(backup_path())
	if not has_main and not has_bak:
		state.new_game()
		return {status = "new", message = ""}
	if has_main:
		var d = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
		var err := GameState.validate_dict(d)
		if err == "":
			state.from_dict(d)
			return {status = "loaded", message = ""}
		push_warning("저장 파일 이상(%s), 백업 확인" % err)
	if has_bak:
		var b = JSON.parse_string(FileAccess.get_file_as_string(backup_path()))
		if GameState.validate_dict(b) == "":
			state.from_dict(b)
			_preserve_broken()
			save(state)
			return {status = "backup", message = "저장 파일에 문제가 있어 직전 백업으로 복구했어요"}
	_preserve_broken()
	state.new_game()
	save(state)
	return {status = "reset", message = "저장 파일을 읽을 수 없어 새 마을로 시작해요.\n기존 파일은 save.broken.json 으로 보관했어요"}


func _preserve_broken() -> void:
	if not FileAccess.file_exists(save_path()):
		return
	var da := DirAccess.open(dir)
	var broken := dir + "save.broken.json"
	if FileAccess.file_exists(broken):
		da.remove(broken.get_file())
	da.copy(save_path(), broken)


func delete_all() -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	for p in [save_path(), backup_path(), tmp_path()]:
		if FileAccess.file_exists(p):
			da.remove(p.get_file())
