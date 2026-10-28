class_name ShipCode
extends RefCounted
## A ship as it leaves the device (PLAN.md 7.4): a `.mssship` file (the blueprint JSON) or a share
## code to paste into a chat (CODE_PREFIX, then the JSON deflated and in base64). Either way it's
## the shared form: no gun item ids (they name guns in the sender's inventory, §5.4) and not for
## sale (publishing is the receiver's call, 7.3). Creative gun levels are part of the design, so
## they come along; buying a ship drops them (HangarEditor.swap_to).
##
## What comes in is untrusted: `read` never crashes, caps the size, and says what's wrong.

const CODE_PREFIX := "MSS1:"
const FILE_EXTENSION := "mssship"
## The most JSON a code or file may hold, unpacked: a 150-tile ship is about 25 KB.
const MAX_BYTES := 1 << 20


## `bp` as it's shared.
static func shared(bp: Blueprint) -> Dictionary:
	var out := bp.to_dict()
	out["tags"] = (out["tags"] as Array).filter(func(tag: String) -> bool: return tag != Blueprint.PUBLISHED)
	for mount: Dictionary in out["mounts"]:
		mount.erase("gun")
	return out


## The `.mssship` file's text.
static func file_text(bp: Blueprint) -> String:
	return JSON.stringify(shared(bp), "\t")


## The share code: one line of text.
static func code(bp: Blueprint) -> String:
	var packed := JSON.stringify(shared(bp)).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE)
	return CODE_PREFIX + Marshalls.raw_to_base64(packed)


## A ship from a share code or a file's text, or null with the reasons in `errors`.
static func read(text: String, errors: PackedStringArray) -> Blueprint:
	if text.length() > MAX_BYTES:
		errors.append("That's too big to be a ship")
		return null
	var json_text := text
	# Chat apps wrap long lines and pad them; a code has no spaces of its own.
	var compact := RegEx.create_from_string("\\s+").sub(text, "", true)
	# A code pasted with the message it came in ("Look at my ship! MSS1:…") starts at its prefix.
	var at := compact.find(CODE_PREFIX) if not compact.begins_with("{") else -1
	if at >= 0:
		compact = compact.substr(at)
		var packed := Marshalls.base64_to_raw(compact.substr(CODE_PREFIX.length()))
		var raw := packed.decompress_dynamic(MAX_BYTES, FileAccess.COMPRESSION_DEFLATE) if not packed.is_empty() else PackedByteArray()
		if raw.is_empty():
			errors.append("That share code is damaged or cut short")
			return null
		json_text = raw.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(json_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		errors.append("That isn't a ship" if not compact.begins_with(CODE_PREFIX) else "That share code is damaged")
		return null
	var bp := Blueprint.from_dict(json.data, errors)
	if bp == null:
		return null
	return Blueprint.from_dict(shared(bp), errors)


## A file name for `bp`: its name in letters, digits, `-` and `_`, then the extension.
static func file_name(bp: Blueprint) -> String:
	var regex := RegEx.create_from_string("[^A-Za-z0-9_-]+")
	var stem := regex.sub(bp.name.strip_edges(), "_", true).trim_prefix("_").trim_suffix("_")
	return "%s.%s" % [stem if not stem.is_empty() else "ship", FILE_EXTENSION]
