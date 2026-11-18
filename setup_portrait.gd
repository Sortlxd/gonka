@tool
extends EditorScript

# Одноразовый скрипт: переключает проект на вертикальный экран телефона.
# Запуск: в редакторе скриптов File -> Run (Ctrl+Shift+X).
func _run():
	ProjectSettings.set_setting("display/window/size/viewport_width", 720)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1280)
	ProjectSettings.set_setting("display/window/size/window_width_override", 540)
	ProjectSettings.set_setting("display/window/size/window_height_override", 960)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("display/window/handheld/orientation", 1)  # 1 = портрет
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_2d", 2)
	ProjectSettings.save()
	print("Готово: вертикальный экран 720x1280, окно 540x960")
