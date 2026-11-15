extends SceneTree
## Saca de las explicaciones de los problemas (data/explain/*.json) lo que hay que traducir:
## plantillas de frases (con {1}, {2}…), piezas tal como aparecen, etiquetas de variantes y de filas del análisis.
## Escribe tools/i18n/claves_explicaciones.json. Uso: godot --headless --path godot -s tests/i18n_explicaciones.gd


func _init() -> void:
	var templates := {}
	var pieces := {}
	var labels := {}
	var dir := DirAccess.open("res://data/explain")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/explain/" + f))
		for s: Variant in d.get("S", []):
			var text := str(s)
			if "\t" in text:
				var cells := text.split("\t")
				labels[cells[0]] = int(labels.get(cells[0], 0)) + 1
				if cells.size() > 2:
					_add(Loc.exp_template(cells[2]), templates, pieces)
				continue
			_add(Loc.exp_template(text), templates, pieces)
		for line: Dictionary in d.get("lines", []):
			labels[str(line.get("label", ""))] = int(labels.get(str(line.get("label", "")), 0)) + 1
	var order := templates.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return int(templates[a]) > int(templates[b]))
	var out := {"plantillas": order, "piezas": pieces.keys(), "etiquetas": labels.keys(), "usos": templates}
	var file := FileAccess.open("res://../tools/i18n/exp_raw.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, " "))
	print("HECHO plantillas=%d piezas=%d etiquetas=%d" % [order.size(), pieces.size(), labels.size()])
	quit()


func _add(tpl: Array, templates: Dictionary, pieces: Dictionary) -> void:
	for sentence: Array in Loc.exp_sentences(tpl[0]):
		templates[sentence[0]] = int(templates.get(sentence[0], 0)) + 1
	for i in (tpl[1] as Array).size():
		if tpl[2][i] == "p":
			pieces[tpl[1][i]] = true
