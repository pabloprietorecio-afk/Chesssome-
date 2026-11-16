extends Node
## Capturas de la app en varios idiomas: inicio con el tablerito-bandera, la hoja de idiomas y Opciones.
## Uso: SHOTS_DIR=… LANGS=en,ja xvfb-run godot --path godot --rendering-driver vulkan --rendering-method mobile res://tests/idiomas.tscn

var out_dir := ""


func _ready() -> void:
	out_dir = OS.get_environment("SHOTS_DIR")
	if out_dir == "":
		out_dir = OS.get_user_data_dir().path_join("idiomas")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var langs := OS.get_environment("LANGS")
	var list: Array = Array(langs.split(",")) if langs != "" else Loc.LANGUAGES.duplicate()
	var demo: Control = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	demo.use_settings = false
	add_child(demo)
	await _frames(20)
	var p: Dictionary = Assessment.start_test("never")
	p["done"] = true
	p["rating"]["r"] = 1272.0
	demo.player = p
	for code: String in list:
		demo._set_language(code)
		await _frames(6)
		demo._open_home()
		await _frames(8)
		await _shot("%s_1_inicio" % code)
		demo._open_language(false)
		await _frames(6)
		await _shot("%s_2_idiomas" % code)
		demo._close_options()
		demo._open_options()
		await _frames(6)
		await _shot("%s_3_opciones" % code)
		demo._close_options()
		if OS.get_environment("MAS") != "":
			demo._open_course()
			await _frames(8)
			await _shot("%s_4_curso" % code)
			demo._open_game_setup()
			await _frames(8)
			await _shot("%s_5_partida" % code)
			demo._go_home_now()
			demo._open_train_hub()
			await _frames(4)
			var idx := 0
			for i in demo.puzzles.size():
				if str(demo.puzzles[i]["id"]) == "IBanZ":
					idx = i
			demo.view.board.anim_mode = Board3D.Anim.NONE
			demo._start(idx)
			await _frames(12)
			await _shot("%s_6_problema" % code)
			demo._show_solution()
			await get_tree().create_timer(1.5).timeout
			await _frames(6)
			await _shot("%s_7_solucion" % code)
			demo._go_home_now()
			await _frames(4)
		if OS.get_environment("PREMIOS") != "":
			await _premios(demo, code)
	print("HECHO")
	get_tree().quit()


## Premios en cada idioma (PREMIOS=1): «Tu día» con racha de 4 días, objetivos, reto semanal, lo hecho hoy e
## insignias; el aviso de premio; y los textos del resumen, las insignias y el aviso diario.
func _premios(demo: Control, code: String) -> void:
	var now: Array = demo._prog_now()
	var bias: int = int(now[1])
	var today: int = demo._prog_day()
	var st := Progress.new_state()
	var ctx: Dictionary = demo._prog_ctx()
	for d in range(today - 3, today + 1):
		var at := d * 86400 + 43200 - bias * 60
		Progress.ensure_today(st, d, ctx)
		var fam := str(st["semana"]["familia"])
		for i in (2 if d == today else 1):
			Progress.record_problem(st, {"correct": i == 0}, at, bias, ctx)
			Progress.record_finish(st, {"id": "s%d_%d" % [d, i], "family": fam, "solved": i == 0}, at, bias, ctx)
	Progress.record_game(st, {"own_moves": 12, "result": 1}, today * 86400 + 43200 - bias * 60, bias, ctx)
	st["insignias"] = ["racha3", "semana1", "dia10"]
	st["aviso"]["activo"] = true
	demo.prog = st
	demo._open_home()
	await _frames(8)
	await _shot("%s_8_inicio_reto" % code)
	demo._open_day()
	await _frames(10)
	await _shot("%s_9_tu_dia" % code)
	demo._prog_toast(Loc.t("¡Reto del día cumplido!"), Loc.f("Racha de %d días", 4), true)
	await get_tree().create_timer(0.7).timeout
	await _shot("%s_10_aviso" % code)
	print("PREMIOS %s · %s · %s · %s" % [code, " | ".join(Progress.summary_lines(st, today)), str(Progress.badge_info("semana5")["nombre"]), str(Reminder._text(st, today, today, today))])
	demo.prog = {}
	demo._close_progress()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
