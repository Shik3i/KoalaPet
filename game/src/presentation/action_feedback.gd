class_name ActionFeedback
extends RefCounted

## Turns an application command result into one short, localized player message.
##
## The rejected build printed raw `error_code` / `reason` strings straight into
## the status area, so a blocked action looked like a developer log line and an
## unmapped code looked like a defect. Every visible outcome now resolves to a
## localization key with an explicit severity, and unknown codes fall back to a
## safe generic sentence instead of leaking engine text.

const SEVERITY_SUCCESS := "success"
const SEVERITY_NOTICE := "notice"
const SEVERITY_BLOCKED := "blocked"
const SEVERITY_FAILURE := "failure"

const PERSISTENCE_CODES := [
	"BACKUP_COPY_FAILED", "BACKUP_REPLACE_FAILED", "BACKUP_ROTATE_FAILED",
	"CONCURRENT_SAVE_CONFLICT", "DIRECTORY_CREATE_FAILED", "PRIMARY_REPLACE_FAILED",
	"PRIMARY_ROTATE_FAILED", "SAVE_LOCKED", "SAVE_LOCK_FAILED", "SAVE_SIZE_LIMIT",
	"TEMP_VALIDATION_FAILED", "TEMP_WRITE_FAILED",
]

const CONTENT_CODES := [
	"ENCOUNTER_MISSING", "ENCOUNTER_NOT_FOUND", "DUNGEON_EMPTY", "DUNGEON_NOT_FOUND",
	"MISSING_TARGET_FORM", "STARTER_BINDING_MISSING", "INVALID_STARTER",
	"INVALID_INJURY_TREATMENT", "NOT_FOUND",
]

const DIRECT_CODES := {
	"FEATURE_LOCKED": ["feedback.locked", "Das ist noch nicht freigeschaltet.", SEVERITY_BLOCKED],
	"EGG_NOT_HATCHED": ["feedback.not_hatched", "Das geht erst nach dem Schlüpfen.", SEVERITY_BLOCKED],
	"NO_PET": ["feedback.no_pet", "Wähle zuerst ein Ei.", SEVERITY_BLOCKED],
	"PET_ALREADY_EXISTS": ["feedback.pet_exists", "Du hast bereits einen Gefährten.", SEVERITY_BLOCKED],
	"BATTLE_ALREADY_ACTIVE": ["feedback.battle_active", "Ein Kampf läuft bereits.", SEVERITY_BLOCKED],
	"ADVENTURE_ALREADY_ACTIVE": ["feedback.adventure_active", "Ein Abenteuer läuft bereits.", SEVERITY_BLOCKED],
	"BATTLE_NOT_ALLOWED": ["feedback.battle_blocked", "Dein Gefährte kann jetzt nicht kämpfen.", SEVERITY_BLOCKED],
	"DUNGEON_NOT_ALLOWED": ["feedback.dungeon_blocked", "Der Dungeon ist jetzt nicht möglich.", SEVERITY_BLOCKED],
	"NO_ACTIVE_BATTLE": ["feedback.no_battle", "Gerade läuft kein Kampf.", SEVERITY_BLOCKED],
	"NO_ACTIVE_DUNGEON": ["feedback.no_dungeon", "Gerade läuft kein Dungeon.", SEVERITY_BLOCKED],
	"NO_INJURY": ["feedback.no_injury", "Keine Behandlung nötig.", SEVERITY_BLOCKED],
	"EVOLUTION_NOT_ELIGIBLE": ["feedback.no_evolution", "Noch keine Entwicklung möglich.", SEVERITY_BLOCKED],
	"INVALID_NICKNAME": ["feedback.invalid_nickname", "Dieser Spitzname geht nicht.", SEVERITY_BLOCKED],
	"INVALID_STANCE": ["feedback.invalid_stance", "Diese Haltung gibt es nicht.", SEVERITY_BLOCKED],
	"DUNGEON_CHOICE_INVALID": ["feedback.invalid_choice", "Diese Wahl ist hier nicht möglich.", SEVERITY_BLOCKED],
}

## Action-specific reasons for the generic domain refusal `COMMAND_NOT_APPLICABLE`.
## The domain reports only "nothing changed", so the readable reason is derived
## from the authoritative view model that the player can also see on screen.
const NOT_APPLICABLE := {
	"feed": ["feedback.feed.unchanged", "Dein Gefährte mag gerade nichts essen."],
	"treat": ["feedback.treat.unchanged", "Für ein Leckerli ist gerade kein Platz."],
	"clean": ["feedback.clean.unchanged", "Hier ist schon alles sauber."],
	"train": ["feedback.train.unchanged", "Training ist gerade nicht möglich."],
	"sleep": ["feedback.sleep.unchanged", "Dein Gefährte schläft schon."],
	"wake": ["feedback.wake.unchanged", "Dein Gefährte ist schon wach."],
	"medicine": ["feedback.medicine.unchanged", "Medizin wird gerade nicht gebraucht."],
	"treat_injury": ["feedback.treatment.unchanged", "Keine Behandlung nötig."],
	"resolve_call": ["feedback.call.unchanged", "Dieser Ruf ist schon erledigt."],
}

const SUCCESS := {
	"feed": ["feedback.feed.ok", "Mahlzeit! Die Sättigung steigt.", "satiety"],
	"treat": ["feedback.treat.ok", "Das Leckerli hebt die Stimmung.", "mood"],
	"clean": ["feedback.clean.ok", "Alles sauber.", "hygiene"],
	"train": ["feedback.train.ok", "Training abgeschlossen.", "energy"],
	"sleep": ["feedback.sleep.ok", "Gute Nacht. Energie erholt sich.", "energy"],
	"wake": ["feedback.wake.ok", "Ausgeschlafen und wach.", "energy"],
	"medicine": ["feedback.medicine.ok", "Die Medizin wirkt.", "health"],
	"treat_injury": ["feedback.treatment.ok", "Die Verletzung ist versorgt.", "health"],
	"resolve_call": ["feedback.call.ok", "Ruf erledigt.", "mood"],
	"set_nickname": ["feedback.nickname.ok", "Name gespeichert.", "mood"],
	"start_battle": ["feedback.battle.started", "Der Kampf beginnt.", "battle"],
	"battle_round": ["feedback.battle.round", "Runde ausgeführt.", "battle"],
	"battle_stance": ["feedback.battle.stance", "Haltung gewählt.", "battle"],
	"start_dungeon": ["feedback.dungeon.started", "Aufbruch in den Dungeon.", "dungeon"],
	"dungeon_next": ["feedback.dungeon.next", "Nächste Etappe erreicht.", "dungeon"],
	"dungeon_choice": ["feedback.dungeon.choice", "Entscheidung getroffen.", "dungeon"],
	"complete_hatch": ["feedback.hatch.ok", "Dein Gefährte ist geschlüpft.", "evolution"],
}


## Returns `{key, fallback, severity, icon}` for one finished command.
static func describe(action_id: String, result: Dictionary) -> Dictionary:
	if bool(result.get("ok", false)):
		return _success(action_id, result)
	var code := str(result.get("error_code", ""))
	if code.is_empty():
		code = "COMMAND_NOT_APPLICABLE"
	return _failure(action_id, code)


static func _success(action_id: String, result: Dictionary) -> Dictionary:
	var summary: Dictionary = result.get("summary", {}) if result.get("summary", {}) is Dictionary else {}
	var events: Array = summary.get("events", []) if summary.get("events", []) is Array else []
	if "overfed" in events:
		return _entry("feedback.feed.overfed", "Vorsicht: dein Gefährte ist überfüttert.", SEVERITY_NOTICE, "satiety")
	if "sickness_started" in events and action_id != "force_sickness":
		return _entry("feedback.sick.started", "Dein Gefährte ist krank geworden.", SEVERITY_NOTICE, "sickness")
	var entry: Array = SUCCESS.get(action_id, [])
	if entry.is_empty():
		return _entry("feedback.generic.ok", "Erledigt.", SEVERITY_SUCCESS, "call")
	return _entry(str(entry[0]), str(entry[1]), SEVERITY_SUCCESS, str(entry[2]))


static func _failure(action_id: String, code: String) -> Dictionary:
	if code == "COMMAND_NOT_APPLICABLE" or code == "UNKNOWN_COMMAND":
		var reason: Array = NOT_APPLICABLE.get(action_id, [])
		if not reason.is_empty():
			return _entry(str(reason[0]), str(reason[1]), SEVERITY_BLOCKED, "call")
		return _entry("feedback.unavailable", "Das geht gerade nicht.", SEVERITY_BLOCKED, "call")
	if DIRECT_CODES.has(code):
		var direct: Array = DIRECT_CODES[code]
		return _entry(str(direct[0]), str(direct[1]), str(direct[2]), "call")
	if code in PERSISTENCE_CODES:
		return _entry("feedback.save_failed", "Nicht gespeichert. Die Aktion wurde zurückgenommen.", SEVERITY_FAILURE, "injury")
	if code in CONTENT_CODES:
		return _entry("feedback.content_missing", "Dieser Inhalt fehlt gerade.", SEVERITY_FAILURE, "injury")
	return _entry("feedback.unavailable", "Das geht gerade nicht.", SEVERITY_BLOCKED, "call")


## An extra, purely presentational hint used when a control is disabled up front.
static func unavailable_hint(action_id: String, model: Dictionary) -> Dictionary:
	if bool(model.get("sleeping", false)) and action_id in ["train", "battle", "dungeon", "clean"]:
		return _entry("feedback.state.sleeping", "Dein Gefährte schläft gerade.", SEVERITY_BLOCKED, "sleep")
	if bool(model.get("sickness", false)) and action_id in ["train", "battle", "dungeon"]:
		return _entry("feedback.state.sick", "Zu krank dafür. Erst Medizin geben.", SEVERITY_BLOCKED, "sickness")
	if not model.get("injury", {}).is_empty() and action_id in ["train", "battle", "dungeon"]:
		return _entry("feedback.state.injured", "Erst die Verletzung behandeln.", SEVERITY_BLOCKED, "injury")
	# Only *starting* an adventure is blocked by a running one. Advancing the
	# active battle or dungeon keeps its own action id and stays available.
	if not model.get("active_battle", {}).is_empty() and action_id in ["dungeon", "battle"]:
		return _entry("feedback.battle_active", "Ein Kampf läuft bereits.", SEVERITY_BLOCKED, "battle")
	if not model.get("active_dungeon_run", {}).is_empty() and action_id == "dungeon":
		return _entry("feedback.adventure_active", "Ein Abenteuer läuft bereits.", SEVERITY_BLOCKED, "dungeon")
	return {}


static func _entry(key: String, fallback: String, severity: String, icon: String) -> Dictionary:
	return {"key": key, "fallback": fallback, "severity": severity, "icon": icon}
