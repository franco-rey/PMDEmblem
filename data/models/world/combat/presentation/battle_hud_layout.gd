class_name BattleHudLayout
extends RefCounted

const MARGIN: float = 16.0
const GAP: float = 14.0
const PANEL_WIDTH: float = 440.0
const PANEL_HEIGHT: float = 196.0
const QUEUE_TILE: float = 64.0
const ACTIVE_TILE: float = 80.0
const TILE_FRAME: float = 8.0
const TILE_GAP: float = 10.0
const DIVIDER_WIDTH: float = 12.0
const MIN_TILE_SCALE: float = 0.6
const STATUS_HEIGHT: float = 104.0
const STATUS_MIN_HEIGHT: float = 30.0
const LOG_HEIGHT: float = 236.0
const LOG_MIN_HEIGHT: float = 96.0
const DOCK_WIDTH: float = 640.0
const DOCK_MIN_WIDTH: float = 320.0
const SPEED_BAR_RESERVE: float = 500.0
const INSPECTOR_WIDTH: float = 480.0
const INSPECTOR_MIN_WIDTH: float = 300.0
const CHIP_HEIGHT: float = 30.0


static func queue_width(count: int, has_divider: bool, scale: float, strip_margins: float) -> float:
	if count <= 0:
		return 0.0
	var fixed: float = strip_margins + float(count) * TILE_FRAME + float(count - 1) * TILE_GAP
	if has_divider:
		fixed += DIVIDER_WIDTH + 2.0 * TILE_GAP
	return fixed + scale * (ACTIVE_TILE + float(count - 1) * QUEUE_TILE)


static func top_row_available(width: float) -> float:
	return width - (MARGIN + PANEL_WIDTH + GAP) - (GAP + PANEL_WIDTH + MARGIN)


static func tile_scale(width: float, count: int, has_divider: bool, strip_margins: float) -> float:
	if count <= 0 or width <= 0.0:
		return 1.0
	var available: float = top_row_available(width)
	if queue_width(count, has_divider, 1.0, strip_margins) <= available:
		return 1.0
	var fixed: float = queue_width(count, has_divider, 0.0, strip_margins)
	var scalable: float = ACTIVE_TILE + float(count - 1) * QUEUE_TILE
	if scalable <= 0.0:
		return 1.0
	return clampf((available - fixed) / scalable, MIN_TILE_SCALE, 1.0)


static func solve(input: Dictionary) -> Dictionary:
	var size: Vector2 = input.get("size", Vector2(1920, 1080))
	var count: int = int(input.get("tile_count", 0))
	var has_divider: bool = bool(input.get("has_divider", false))
	var strip_margins: float = float(input.get("strip_margins", 20.0))
	var queue_height: float = float(input.get("queue_height", 148.0))
	var status_minimized: bool = bool(input.get("status_minimized", false))
	var inspector_content: float = float(input.get("inspector_content", 0.0))
	var inspector_margins: float = float(input.get("inspector_margins", 16.0))
	var inspector_min_width: float = maxf(INSPECTOR_MIN_WIDTH, float(input.get("inspector_min_width", INSPECTOR_MIN_WIDTH)))
	var scale: float = tile_scale(size.x, count, has_divider, strip_margins)
	var strip_width: float = queue_width(count, has_divider, scale, strip_margins)
	var stacked: bool = count > 0 and strip_width > top_row_available(size.x)
	var queue_top: float = MARGIN + PANEL_HEIGHT + GAP if stacked else MARGIN
	var chip_top: float = queue_top + queue_height + GAP
	var inspector_top: float = MARGIN + PANEL_HEIGHT + GAP + (queue_height + GAP if stacked else 0.0)
	var corner_reserve: float = float(input.get("corner_reserve", 0.0))
	var dock_left: float = MARGIN
	var dock_width: float = clampf(size.x - SPEED_BAR_RESERVE, DOCK_MIN_WIDTH, DOCK_WIDTH)
	var status_height: float = STATUS_MIN_HEIGHT if status_minimized else STATUS_HEIGHT
	var reserved_top: float = MARGIN + PANEL_HEIGHT + GAP + (queue_height + GAP if stacked else 0.0) + (corner_reserve + GAP if corner_reserve > 0.0 else 0.0)
	var log_height: float = clampf(size.y - reserved_top - MARGIN - status_height - GAP - MARGIN, LOG_MIN_HEIGHT, LOG_HEIGHT)
	var inspector_width: float = minf(INSPECTOR_WIDTH, maxf(inspector_min_width, size.x - 2.0 * MARGIN - GAP - dock_width))
	var inspector_max: float = maxf(120.0, size.y - inspector_top - MARGIN - inspector_margins)
	var inspector_scroll: float = minf(inspector_content, inspector_max) if inspector_content > 0.0 else 0.0
	return {
		"scale": scale,
		"stacked": stacked,
		"queue_top": queue_top,
		"strip_width": strip_width,
		"chip_visible": not stacked,
		"chip_top": chip_top,
		"dock_width": dock_width,
		"dock_left": dock_left,
		"log_height": log_height,
		"inspector_top": inspector_top,
		"inspector_width": inspector_width,
		"inspector_scroll": inspector_scroll,
	}
