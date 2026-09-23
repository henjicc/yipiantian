extends SceneTree
## Narrow frame-cap policy check. Does not grab focus or change another window.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var activity: Node=load("res://atmosphere/window_activity.gd").new()
	root.add_child(activity)
	activity._active=true
	activity._apply_frame_limit()
	assert(Engine.max_fps==60,"Normal foreground defaults to 60 FPS")
	activity.set_wallpaper(true)
	activity.set_wallpaper_interacting(true)
	assert(Engine.max_fps==60,"Interactive desktop remains capped at 60 FPS")
	activity.set_wallpaper_interacting(false)
	assert(Engine.max_fps==30,"Visible desktop observation remains at 30 FPS")
	activity.set_wallpaper_visible(false)
	assert(Engine.max_fps==2,"Covered desktop remains at 2 FPS")
	activity.set_wallpaper(false)
	activity.set_foreground_frame_limit(60)
	activity._active=false
	activity._apply_frame_limit()
	assert(Engine.max_fps==60,"Visible second-screen preview must not fall to 15 FPS")
	root.mode=Window.MODE_MINIMIZED
	activity._apply_frame_limit()
	assert(Engine.max_fps==15,"Minimized preview retains the background cap")
	root.mode=Window.MODE_WINDOWED
	activity.set_foreground_frame_limit(30)
	activity._active=false
	activity._apply_frame_limit()
	assert(Engine.max_fps==30,"Preview respects a lower selected frame cap")
	activity._active=true
	activity._apply_frame_limit()
	assert(Engine.max_fps==30,"Foreground limit is restored")
	activity.free()
	print("WINDOW_PREVIEW_ACTIVITY_PASS")
	quit()
