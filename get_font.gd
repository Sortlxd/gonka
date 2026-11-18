@tool
extends EditorScript

# Одноразовый скрипт: скачивает бесплатный шрифт Nunito (Google Fonts, лицензия OFL)
# в папку игры: res://fonts/main.ttf. Запуск: File -> Run (Ctrl+Shift+X).
const URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf"


func _run():
	DirAccess.make_dir_recursive_absolute("res://fonts")
	var http = HTTPRequest.new()
	EditorInterface.get_base_control().add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 10000:
			var f = FileAccess.open("res://fonts/main.ttf", FileAccess.WRITE)
			f.store_buffer(body)
			f.close()
			print("Шрифт скачан: ", body.size(), " байт")
			EditorInterface.get_resource_filesystem().scan()
		else:
			print("Не получилось скачать шрифт. result=", result, " code=", code)
		http.queue_free())
	var err = http.request(URL)
	print("Скачиваю шрифт... ", err)
