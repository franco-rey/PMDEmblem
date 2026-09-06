class_name NotationParser
extends RefCounted

const VERSION: String = "pmdn/1"
const KIND_COMMENT: String = "comment"
const KIND_TAG: String = "tag"
const KIND_TERRAIN: String = "terrain"
const KIND_UNIT: String = "unit"
const KIND_TURN: String = "turn"
const KIND_ACTION: String = "action"
const KIND_RESULT: String = "result"
const KIND_FINAL: String = "final"
const KIND_BOARD: String = "board"
const KIND_BRANCH: String = "branch"
const KIND_PRESENT: String = "present"
const COMMAND_VERBS: Array[String] = ["mv", "atk", "item", "end"]


static func parse(line: String) -> Dictionary:
	var text: String = line.strip_edges()
	if text.is_empty() or text.begins_with("#"):
		return {"kind": KIND_COMMENT, "text": text}
	if text.begins_with("[") and text.ends_with("]"):
		return _parse_tag(text.substr(1, text.length() - 2))
	var tokens: PackedStringArray = tokenize(text)
	if tokens.is_empty():
		return {"kind": KIND_COMMENT, "text": text}
	var head: String = tokens[0]
	if head.length() > 1 and head.begins_with("T") and head.substr(1).is_valid_int() and tokens.size() >= 2:
		var tile: String = tokens[2].trim_prefix("@") if tokens.size() > 2 else ""
		return {"kind": KIND_TURN, "turn": int(head.substr(1)), "unit": tokens[1], "tile": tile, "tokens": tokens}
	match head:
		"terrain":
			return {"kind": KIND_TERRAIN, "row": int(tokens[1]) if tokens.size() > 1 else 0, "cells": _slice(tokens, 2)}
		"unit":
			var fields: Dictionary = _fields(_slice(tokens, 3))
			return {"kind": KIND_UNIT, "unit": tokens[1] if tokens.size() > 1 else "", "species": tokens[2] if tokens.size() > 2 else "", "fields": fields}
		"result":
			return {"kind": KIND_RESULT, "winner": tokens[1] if tokens.size() > 1 else "", "fields": _fields(_slice(tokens, 2))}
		"final":
			return {"kind": KIND_FINAL, "unit": tokens[1] if tokens.size() > 1 else "", "fields": _fields(_slice(tokens, 2))}
		"board":
			return {"kind": KIND_BOARD, "tokens": tokens}
		"branch":
			return {"kind": KIND_BRANCH, "tokens": tokens}
		"present":
			return {"kind": KIND_PRESENT, "tokens": tokens}
	return {"kind": KIND_ACTION, "verb": head, "args": _slice(tokens, 1), "tokens": tokens}


static func is_command(parsed: Dictionary) -> bool:
	return String(parsed.get("kind", "")) == KIND_ACTION and COMMAND_VERBS.has(String(parsed.get("verb", "")))


static func tokenize(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var current: String = ""
	var quoted: bool = false
	var i: int = 0
	while i < text.length():
		var ch: String = text.substr(i, 1)
		if quoted:
			if ch == "\\" and i + 1 < text.length():
				current += text.substr(i + 1, 1)
				i += 2
				continue
			if ch == "\"":
				quoted = false
			else:
				current += ch
		elif ch == "\"":
			quoted = true
		elif ch == " " or ch == "\t":
			if not current.is_empty():
				out.append(current)
				current = ""
		else:
			current += ch
		i += 1
	if not current.is_empty():
		out.append(current)
	return out


static func quote(text: String) -> String:
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")


static func is_unit_id(text: String) -> bool:
	var base: String = text.rstrip("'")
	if base.length() < 2 or not (base.begins_with("P") or base.begins_with("E")):
		return false
	return base.substr(1).is_valid_int()



static func split_move(text: String) -> PackedStringArray:
	return text.split(">", false)


static func _parse_tag(inner: String) -> Dictionary:
	var tokens: PackedStringArray = tokenize(inner)
	if tokens.is_empty():
		return {"kind": KIND_COMMENT, "text": inner}
	var values: PackedStringArray = _slice(tokens, 1)
	return {"kind": KIND_TAG, "key": tokens[0], "value": " ".join(values), "values": values}


static func _fields(tokens: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var positional: PackedStringArray = []
	for token in tokens:
		if token.begins_with("@"):
			out["tile"] = token.substr(1)
		elif token.begins_with("L") and token.substr(1).is_valid_int():
			out["level"] = int(token.substr(1))
		elif token.contains("=") and not token.begins_with("="):
			var split: PackedStringArray = token.split("=", false, 1)
			out[split[0]] = split[1] if split.size() > 1 else ""
		elif token.contains("/") and token.split("/")[0].is_valid_int():
			var hp: PackedStringArray = token.split("/")
			out["hp"] = int(hp[0])
			out["hp_max"] = int(hp[1]) if hp.size() > 1 else 0
		else:
			positional.append(token)
	out["positional"] = positional
	return out


static func _slice(tokens: PackedStringArray, from: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(from, tokens.size()):
		out.append(tokens[i])
	return out
