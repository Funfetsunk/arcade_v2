class_name SaveSystem
extends RefCounted
## Saves the GameState as a text resource in user:// (IndexedDB on web).

const SAVE_PATH := "user://save.tres"


static func save(state: GameState, path := SAVE_PATH) -> Error:
	state.save_version = GameState.SAVE_VERSION
	return ResourceSaver.save(state, path)


## Returns null when there is no save or it is from an incompatible version.
static func load_save(path := SAVE_PATH) -> GameState:
	if not ResourceLoader.exists(path):
		return null
	var state := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameState
	if state == null or state.save_version != GameState.SAVE_VERSION:
		return null
	return state


static func delete(path := SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
