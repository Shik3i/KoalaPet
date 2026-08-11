class_name ContentPathPolicy
extends RefCounted

const SAFE_MEDIA_EXTENSIONS := ["png", "webp", "ogg", "wav"]
const FORBIDDEN_EXTENSIONS := [
	"gd", "gdc", "cs", "dll", "so", "dylib", "exe", "com", "bat", "cmd",
	"ps1", "sh", "app", "jar", "class", "py", "rb", "js", "mjs", "wasm",
	"zip", "rar", "7z", "tar", "gz", "bz2", "xz", "pkg", "dmg", "msi",
]


static func validate_relative_path(value: Variant, allowed_extensions: Array = []) -> String:
	if not value is String or value.is_empty():
		return "path must be a non-empty string"
	var path: String = value
	if path.begins_with("/") or path.begins_with("\\") or path.contains("://"):
		return "absolute or URI paths are not allowed"
	if path.contains("\\"):
		return "backslash path separators are not allowed"
	var drive_pattern := RegEx.new()
	drive_pattern.compile("^[A-Za-z]:")
	if drive_pattern.search(path) != null:
		return "absolute drive paths are not allowed"
	for segment in path.split("/", true):
		if segment in ["", ".", ".."]:
			return "path contains an empty, current, or parent segment"
	if not allowed_extensions.is_empty():
		var extension := path.get_extension().to_lower()
		if extension not in allowed_extensions:
			return "extension .%s is not allowlisted" % extension
	return ""


static func is_forbidden_payload(path: String) -> bool:
	return path.get_extension().to_lower() in FORBIDDEN_EXTENSIONS


static func is_namespaced_id(value: Variant) -> bool:
	if not value is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_.-]*:[a-z][a-z0-9_.-]*$")
	return pattern.search(value) != null


static func is_pack_id(value: Variant) -> bool:
	if not value is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_.-]*$")
	return pattern.search(value) != null


static func is_semver(value: Variant) -> bool:
	if not value is String:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[0-9]+\\.[0-9]+\\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$")
	return pattern.search(value) != null
