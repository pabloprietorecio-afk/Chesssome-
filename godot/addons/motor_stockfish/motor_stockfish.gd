@tool
extends EditorPlugin
## Complemento de Android «MotorStockfish» (android_motor/): al exportar con Gradle, registra el complemento en el
## manifiesto y añade el AAR con Stockfish compilado para arm64 (lib/arm64-v8a/libstockfish.so). La CI compila
## Stockfish sf_19 y deja el AAR en bin/; sin él (compilaciones locales), la app usa el Stockfish del servidor.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	const AAR := "motor_stockfish/bin/motor_stockfish.aar"

	func _get_name() -> String:
		return "MotorStockfish"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if FileAccess.file_exists("res://addons/" + AAR):
			return PackedStringArray([AAR])
		return PackedStringArray()

	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return '<meta-data android:name="org.godotengine.plugin.v2.MotorStockfish" android:value="com.pabloprieto.motor.MotorStockfish" />'
