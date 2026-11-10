extends Node
## Central, data-driven content database. Everything gameplay-facing lives here
## so new blocks, items, recipes, monsters and biomes can be added without code.

# ---------------------------------------------------------------- blocks
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const SANDSTONE := 5
const SNOW := 6
const WATER := 7
const LOG := 8
const LEAVES := 9
const CACTUS := 10
const PLANKS := 11
const STONE_BRICK := 12
const GLASS := 13
const LAMP := 14
const COAL_ORE := 15
const IRON_ORE := 16
const GOLD_ORE := 17
const CRYSTAL_ORE := 18
const BEDROCK := 19
const ASH := 20
const BASALT := 21
const LAVA := 22
const MYCELIUM := 23
const MUSH_STEM := 24
const MUSH_CAP := 25
const ICE := 26
const FARMLAND := 27
const WHEAT0 := 28
const WHEAT1 := 29
const WHEAT2 := 30
const WHEAT3 := 31
const TORCH := 32
const CHEST := 33
const TABLE := 34
const DOOR := 35
const ROOF := 36
const PLASTER := 37
const GRAVEL := 38
const FLOWER_RED := 39
const FLOWER_YELLOW := 40
const TUFT := 41
const SMALL_MUSHROOM := 42
const DUNGEON_BRICK := 43
const RUNE := 44
const CRYSTAL_BLOCK := 45
const PINE_LEAVES := 46
const RANCH := 47
const FLOWER_BLUE := 48

const TILE_COLUMNS := 16

var TILES: Dictionary = {}
var BLOCKS: Dictionary = {}
var ITEMS: Dictionary = {}
var RECIPES: Array = []
var SPECIES: Dictionary = {}
var BIOMES: Dictionary = {}
var ELEMENTS: Dictionary = {}
var OBJECTIVES: Array = []
var QUEST_TEMPLATES: Array = []
var VILLAGE_NAMES: Array = []
var NPC_NAMES: Array = []
var MERCHANT_STOCK: Array = []
var MERCHANT_BUY: Array = []
var VARIANTS: Dictionary = {}

var atlas_image: Image
var atlas_texture: ImageTexture
var _icon_cache: Dictionary = {}
var _held_cache: Dictionary = {}
var _color_cache: Dictionary = {}
var _portrait_cache: Dictionary = {}
var _monster_mat_cache: Dictionary = {}
var _monster_tex_cache: Dictionary = {}

func _ready() -> void:
	for i in PixelArt.TILE_NAMES.size():
		TILES[PixelArt.TILE_NAMES[i]] = i
	_build_blocks()
	_build_items()
	_build_recipes()
	_build_monsters()
	_build_rare_species()
	_build_biomes()
	_build_elements()
	_build_quests()
	_build_merchant()
	atlas_image = PixelArt.make_atlas(TILE_COLUMNS)
	atlas_texture = ImageTexture.create_from_image(atlas_image)

# ---------------------------------------------------------------- builders

func _tile(name: String) -> int:
	return int(TILES.get(name, 0))

func _block(id: int, name: String, top: String, side: String, bottom: String, props: Dictionary) -> void:
	var d := {
		"id": id, "name": name,
		"top": _tile(top), "side": _tile(side), "bottom": _tile(bottom),
		"solid": true, "opaque": true, "render": "opaque",
		"hardness": 1.0, "tool": "", "light": 0.0,
		"drops": [], "interact": "", "plant": false,
		"needs_soil": false, "replaceable": false, "icon_tile": _tile(side),
	}
	for k in props:
		d[k] = props[k]
	BLOCKS[id] = d

func _drop(item_id: String, chance: float = 1.0, min_n: int = 1, max_n: int = 1) -> Dictionary:
	return {"id": item_id, "chance": chance, "min": min_n, "max": max_n}

func _build_blocks() -> void:
	_block(GRASS, "Grass", "grass_top", "grass_side", "dirt", {
		"hardness": 0.65, "tool": "shovel", "drops": [_drop("dirt")], "icon_tile": _tile("grass_top")})
	_block(DIRT, "Dirt", "dirt", "dirt", "dirt", {
		"hardness": 0.6, "tool": "shovel", "drops": [_drop("dirt")]})
	_block(STONE, "Stone", "stone", "stone", "stone", {
		"hardness": 2.2, "tool": "pick", "drops": [_drop("stone")]})
	_block(SAND, "Sand", "sand", "sand", "sand", {
		"hardness": 0.5, "tool": "shovel", "drops": [_drop("sand")],
		"icon_tile": _tile("sand")})
	_block(SANDSTONE, "Sandstone", "sandstone_top", "sandstone_side", "sandstone_top", {
		"hardness": 1.7, "tool": "pick", "drops": [_drop("sandstone")]})
	_block(SNOW, "Frost", "snow", "snow", "snow", {
		"hardness": 0.4, "tool": "shovel", "drops": [_drop("snow")]})
	_block(WATER, "Water", "water", "water", "water", {
		"solid": false, "opaque": false, "render": "liquid", "hardness": -1.0})
	_block(LOG, "Log", "log_top", "log_side", "log_top", {
		"hardness": 1.7, "tool": "axe", "drops": [_drop("log")], "icon_tile": _tile("log_top")})
	_block(LEAVES, "Leaves", "leaves", "leaves", "leaves", {
		"opaque": false, "render": "cutout", "hardness": 0.3, "tool": "axe",
		"drops": [_drop("fiber", 0.5, 1, 2), _drop("berry", 0.12)]})
	_block(PINE_LEAVES, "Pine Leaves", "pine_leaves", "pine_leaves", "pine_leaves", {
		"opaque": false, "render": "cutout", "hardness": 0.3, "tool": "axe",
		"drops": [_drop("fiber", 0.5, 1, 2)]})
	_block(CACTUS, "Cactus", "cactus_top", "cactus_side", "cactus_top", {
		"hardness": 0.5, "tool": "axe", "drops": [_drop("cactus")], "icon_tile": _tile("cactus_top")})
	_block(PLANKS, "Planks", "planks", "planks", "planks", {
		"hardness": 1.2, "tool": "axe", "drops": [_drop("planks")]})
	_block(STONE_BRICK, "Stone Bricks", "stone_brick", "stone_brick", "stone_brick", {
		"hardness": 2.3, "tool": "pick", "drops": [_drop("stone_brick")]})
	_block(GLASS, "Glass", "glass", "glass", "glass", {
		"opaque": false, "render": "transparent", "hardness": 0.4,
		"drops": [_drop("glass")]})
	_block(LAMP, "Crystal Lamp", "lamp", "lamp", "lamp", {
		"hardness": 0.9, "tool": "pick", "light": 1.1, "drops": [_drop("lamp")]})
	_block(COAL_ORE, "Coal Ore", "coal_ore", "coal_ore", "coal_ore", {
		"hardness": 2.8, "tool": "pick", "drops": [_drop("coal", 1.0, 1, 2)]})
	_block(IRON_ORE, "Iron Ore", "iron_ore", "iron_ore", "iron_ore", {
		"hardness": 3.1, "tool": "pick", "drops": [_drop("iron_ore", 1.0, 1, 2)]})
	_block(GOLD_ORE, "Gold Ore", "gold_ore", "gold_ore", "gold_ore", {
		"hardness": 3.4, "tool": "pick", "drops": [_drop("gold_ore", 1.0, 1, 2)]})
	_block(CRYSTAL_ORE, "Crystal Ore", "crystal_ore", "crystal_ore", "crystal_ore", {
		"hardness": 3.8, "tool": "pick", "drops": [_drop("crystal", 0.85, 1, 2), _drop("amber", 0.3)]})
	_block(BEDROCK, "Bedrock", "bedrock", "bedrock", "bedrock", {
		"hardness": -1.0, "drops": []})
	_block(ASH, "Volcanic Ash", "ash", "ash", "ash", {
		"hardness": 0.6, "tool": "shovel", "drops": [_drop("ash")]})
	_block(BASALT, "Basalt", "basalt", "basalt", "basalt", {
		"hardness": 2.6, "tool": "pick", "drops": [_drop("basalt")]})
	_block(LAVA, "Lava", "lava", "lava", "lava", {
		"solid": false, "opaque": false, "render": "liquid", "hardness": -1.0, "light": 1.3})
	_block(MYCELIUM, "Mycelium", "mycelium_top", "mycelium_side", "dirt", {
		"hardness": 0.65, "tool": "shovel", "drops": [_drop("dirt")], "icon_tile": _tile("mycelium_top")})
	_block(MUSH_STEM, "Mushroom Stem", "mushroom_stem", "mushroom_stem", "mushroom_stem", {
		"hardness": 0.9, "tool": "axe", "drops": [_drop("mush_stem")]})
	_block(MUSH_CAP, "Mushroom Cap", "mushroom_cap", "mushroom_cap", "mushroom_cap_cream", {
		"hardness": 0.5, "tool": "axe", "drops": [_drop("mush_cap")]})
	_block(ICE, "Ice", "ice", "ice", "ice", {
		"opaque": false, "render": "transparent", "hardness": 1.0, "tool": "pick",
		"drops": [_drop("ice")]})
	_block(FARMLAND, "Farmland", "farmland", "dirt", "dirt", {
		"hardness": 0.55, "tool": "shovel", "drops": [_drop("dirt")]})
	for i in 4:
		_block(WHEAT0 + i, "Wheat", "wheat_%d" % i, "wheat_%d" % i, "wheat_%d" % i, {
			"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
			"drops": [_drop("seeds", 1.0, 1, 1)], "replaceable": true,
			"drops_full": i == 3, "icon_tile": _tile("wheat_3")})
	_block(TORCH, "Torch", "torch", "torch", "torch", {
		"solid": false, "opaque": false, "render": "plant", "plant": true,
		"hardness": 0.05, "light": 1.0, "drops": [_drop("torch")], "replaceable": true})
	_block(CHEST, "Chest", "chest_top", "chest_side", "chest_top", {
		"hardness": 1.4, "tool": "axe", "drops": [_drop("chest")], "interact": "chest",
		"icon_tile": _tile("chest_side")})
	_block(TABLE, "Crafting Table", "crafting_top", "crafting_side", "planks", {
		"hardness": 1.4, "tool": "axe", "drops": [_drop("table")], "interact": "table",
		"icon_tile": _tile("crafting_top")})
	_block(DOOR, "Wooden Door", "door", "door", "door", {
		"hardness": 0.9, "tool": "axe", "drops": [_drop("door")]})
	_block(ROOF, "Roof Tiles", "roof", "roof", "roof", {
		"hardness": 1.1, "tool": "pick", "drops": [_drop("roof")]})
	_block(PLASTER, "Plaster Wall", "plaster", "plaster", "plaster", {
		"hardness": 1.0, "tool": "pick", "drops": [_drop("plaster")]})
	_block(GRAVEL, "Gravel", "gravel", "gravel", "gravel", {
		"hardness": 0.8, "tool": "shovel", "drops": [_drop("gravel")]})
	_block(FLOWER_RED, "Red Flower", "flower_red", "flower_red", "flower_red", {
		"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
		"drops": [_drop("flower_red")], "needs_soil": true, "replaceable": true})
	_block(FLOWER_YELLOW, "Yellow Flower", "flower_yellow", "flower_yellow", "flower_yellow", {
		"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
		"drops": [_drop("flower_yellow")], "needs_soil": true, "replaceable": true})
	_block(FLOWER_BLUE, "Blue Flower", "flower_blue", "flower_blue", "flower_blue", {
		"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
		"drops": [_drop("flower_blue")], "needs_soil": true, "replaceable": true})
	_block(TUFT, "Wild Grass", "grass_tuft", "grass_tuft", "grass_tuft", {
		"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
		"drops": [_drop("fiber", 1.0, 1, 1)], "needs_soil": true, "replaceable": true})
	_block(SMALL_MUSHROOM, "Small Mushroom", "small_mushroom", "small_mushroom", "small_mushroom", {
		"solid": false, "opaque": false, "render": "plant", "plant": true, "hardness": 0.05,
		"drops": [_drop("mush_cap", 0.7), _drop("fiber", 0.5)], "needs_soil": true, "replaceable": true})
	_block(DUNGEON_BRICK, "Ancient Bricks", "dungeon_brick", "dungeon_brick", "dungeon_brick", {
		"hardness": 3.2, "tool": "pick", "drops": [_drop("dungeon_brick")]})
	_block(RUNE, "Rune Core", "rune", "rune", "rune", {
		"hardness": -1.0, "light": 0.9, "interact": "rune", "drops": []})
	_block(CRYSTAL_BLOCK, "Crystal Block", "crystal_block", "crystal_block", "crystal_block", {
		"hardness": 2.6, "tool": "pick", "light": 0.6, "drops": [_drop("crystal_block")]})
	_block(RANCH, "Ranch Banner", "ranch_banner", "ranch_banner", "ranch_banner", {
		"hardness": 1.3, "tool": "axe", "drops": [_drop("ranch_banner")], "interact": "ranch"})

# ---------------------------------------------------------------- items

func _item(id: String, name: String, opts: Dictionary) -> void:
	var d := {"id": id, "name": name, "stack": 99, "cat": "Misc", "type": "material",
		"icon": "ore", "color": "#c9c9c9", "color2": "#ffffff", "color3": "#ffe2a8",
		"desc": ""}
	for k in opts:
		d[k] = opts[k]
	ITEMS[id] = d

func _tool(id: String, name: String, kind: String, tier: int, color: Color) -> void:
	var speeds := [0.0, 2.2, 3.4, 5.2, 7.5]
	var damages := [0.0, 4, 6, 9, 13]
	if kind == "sword":
		damages = [0.0, 7, 10, 15, 22]
	_item(id, name, {"stack": 1, "cat": "Tools", "type": "tool", "tool_kind": kind,
		"tier": tier, "speed": speeds[tier], "damage": damages[tier],
		"icon": kind, "color": color, "color2": color.darkened(0.3),
		"desc": _tool_desc(kind)})

func _tool_desc(kind: String) -> String:
	match kind:
		"pick": return "Mines stone blocks faster."
		"axe": return "Chops wood and organic blocks faster."
		"shovel": return "Digs dirt, sand, and snow faster."
		"sword": return "A close-range weapon. Higher damage."
		"hoe": return "Turns dirt into farmland."
	return ""

func _build_items() -> void:
	# Block item ids are hand-mapped to keep save files readable.
	var block_keys := {
		DIRT: "dirt", STONE: "stone", SAND: "sand", SANDSTONE: "sandstone", SNOW: "snow",
		LOG: "log", LEAVES: "leaves", PINE_LEAVES: "pine_leaves", CACTUS: "cactus",
		PLANKS: "planks", STONE_BRICK: "stone_brick", GLASS: "glass", LAMP: "lamp",
		ASH: "ash", BASALT: "basalt", MYCELIUM: "mycelium", MUSH_STEM: "mush_stem",
		MUSH_CAP: "mush_cap", ICE: "ice", TORCH: "torch", CHEST: "chest", TABLE: "table",
		DOOR: "door", ROOF: "roof", PLASTER: "plaster", GRAVEL: "gravel",
		FLOWER_RED: "flower_red", FLOWER_YELLOW: "flower_yellow", FLOWER_BLUE: "flower_blue",
		DUNGEON_BRICK: "dungeon_brick", CRYSTAL_BLOCK: "crystal_block", RANCH: "ranch_banner",
	}
	for bid in block_keys:
		var key: String = block_keys[bid]
		var b: Dictionary = BLOCKS[bid]
		_item(key, b.name, {"stack": 99, "cat": "Blocks", "type": "block", "block": bid,
			"desc": "A building block. Can be placed and mined.",
			"icon": "block"})
		ITEMS[key]["icon_tile"] = b.get("icon_tile", b.side)

	_item("stick", "Stick", {"icon": "stick", "color": "#a97a46", "color2": "#6f4e2c",
		"desc": "A basic material for tools and torches."})
	_item("coal", "Coal", {"icon": "ore", "color": "#3a3d42", "color2": "#22252a",
		"desc": "Fuel and a crafting component."})
	_item("iron_ore", "Iron Ore", {"icon": "ore", "color": "#d7a57d", "color2": "#9a6a4b",
		"desc": "Smelt with coal to make an iron ingot."})
	_item("iron_ingot", "Iron Ingot", {"icon": "ingot", "color": "#cfd6da",
		"color2": "#8d979e", "desc": "Sturdy metal for tools and armor."})
	_item("gold_ore", "Gold Ore", {"icon": "ore", "color": "#f0c34f", "color2": "#b98d2e",
		"desc": "A precious metal; smelt it into a gold ingot."})
	_item("gold_ingot", "Gold Ingot", {"icon": "ingot", "color": "#f5d26b",
		"color2": "#c3982f", "desc": "Used in lamps and ornaments."})
	_item("crystal", "Crystal", {"icon": "gem", "color": "#6fe4d4", "color2": "#2e8d87",
		"desc": "A glowing crystal from the depths. The heart of monster technology."})
	_item("amber", "Amber", {"icon": "amber", "color": "#f0a93e", "color2": "#ffd98a",
		"desc": "The valley currency of the folk."})
	_item("fiber", "Fiber", {"icon": "fiber", "color": "#6fae5c", "color2": "#a9d68a",
		"desc": "Plant fiber for rope and snares."})
	_item("leather", "Leather", {"icon": "leather", "color": "#a86a43", "color2": "#7a4a2d",
		"desc": "Monster hide for saddles and gear."})
	_item("monster_core", "Monster Core", {"icon": "core", "color": "#8f6ec9",
		"color2": "#e0c7ff", "desc": "The energy core of a powerful monster. The key to the world rift."})
	_item("seeds", "Wheat Seeds", {"icon": "seeds", "color": "#c9b26b", "color2": "#8b7442",
		"desc": "Plant on farmland. Grows into wheat."})
	_item("wheat", "Wheat", {"icon": "wheat", "color": "#e2cb6e", "color2": "#8fa84e",
		"desc": "A farm harvest. Used to make monster feed."})
	_item("berry", "Wild Berries", {"icon": "berry", "color": "#cf4f57", "color2": "#6fae5c",
		"type": "food", "heal": 8, "desc": "Eat to restore 8 HP."})
	_item("roast_berry", "Roasted Berries", {"icon": "roast", "color": "#b1613b",
		"color2": "#e0b48a", "type": "food", "heal": 22, "desc": "Eat to restore 22 HP."})
	_item("potion", "Healing Potion", {"icon": "potion", "color": "#d9525d",
		"color2": "#e8dcc0", "type": "food", "heal": 55, "desc": "A warm brew. Restores 55 HP."})
	_item("orb", "Capture Orb", {"icon": "orb", "color": "#6acfc4", "color2": "#d8fff8",
		"type": "orb", "orb_mult": 1.0, "desc": "Throw at a weakened monster to capture it."})
	_item("orb_great", "Great Capture Orb", {"icon": "orb_great", "color": "#b58cf0",
		"color2": "#f0d1ff", "type": "orb", "orb_mult": 1.9,
		"desc": "A powerful capture orb. Much higher catch chance."})
	_item("feed", "Monster Feed", {"icon": "feed", "color": "#c99a5b", "color2": "#8a5f35",
		"type": "feed", "desc": "Feed a wild monster to tame it, or give it to your partner to raise bond."})
	_item("saddle", "Saddle", {"icon": "saddle", "color": "#a2693f", "color2": "#6d4327",
		"color3": "#e3c06b", "type": "saddle", "desc": "Equip on a rideable monster."})
	_item("rift_key", "Rift Key", {"icon": "key", "color": "#c39bf0", "color2": "#6e4aa8",
		"type": "rift_key", "desc": "Opens the World Rift for an endless wave challenge."})

	_tool("pick_wood", "Wooden Pickaxe", "pick", 1, Color("#a97a46"))
	_tool("pick_stone", "Stone Pickaxe", "pick", 2, Color("#8f989e"))
	_tool("pick_iron", "Iron Pickaxe", "pick", 3, Color("#c4ced3"))
	_tool("pick_crystal", "Crystal Pickaxe", "pick", 4, Color("#6fe4d4"))
	_tool("axe_wood", "Wooden Axe", "axe", 1, Color("#a97a46"))
	_tool("axe_stone", "Stone Axe", "axe", 2, Color("#8f989e"))
	_tool("axe_iron", "Iron Axe", "axe", 3, Color("#c4ced3"))
	_tool("axe_crystal", "Crystal Axe", "axe", 4, Color("#6fe4d4"))
	_tool("shovel_wood", "Wooden Shovel", "shovel", 1, Color("#a97a46"))
	_tool("shovel_stone", "Stone Shovel", "shovel", 2, Color("#8f989e"))
	_tool("shovel_iron", "Iron Shovel", "shovel", 3, Color("#c4ced3"))
	_tool("shovel_crystal", "Crystal Shovel", "shovel", 4, Color("#6fe4d4"))
	_tool("sword_wood", "Wooden Sword", "sword", 1, Color("#a97a46"))
	_tool("sword_stone", "Stone Sword", "sword", 2, Color("#8f989e"))
	_tool("sword_iron", "Iron Sword", "sword", 3, Color("#c4ced3"))
	_tool("sword_crystal", "Crystal Sword", "sword", 4, Color("#6fe4d4"))
	_tool("hoe_wood", "Wooden Hoe", "hoe", 1, Color("#a97a46"))
	_tool("hoe_stone", "Stone Hoe", "hoe", 2, Color("#8f989e"))
	_tool("hoe_iron", "Iron Hoe", "hoe", 3, Color("#c4ced3"))

	var armor := [
		["helm_iron", "Iron Helmet", "helmet", "head", 3, "#c4ced3"],
		["chest_iron", "Iron Chestplate", "chestplate", "body", 5, "#c4ced3"],
		["boots_iron", "Iron Boots", "boots", "feet", 2, "#c4ced3"],
		["helm_crystal", "Crystal Helmet", "helmet", "head", 5, "#6fe4d4"],
		["chest_crystal", "Crystal Chestplate", "chestplate", "body", 8, "#6fe4d4"],
		["boots_crystal", "Crystal Boots", "boots", "feet", 4, "#6fe4d4"],
	]
	for a in armor:
		_item(a[0], a[1], {"stack": 1, "cat": "Tools", "type": "armor", "slot": a[3],
			"defense": a[4], "icon": a[2], "color": a[5], "color2": Color(a[5]).darkened(0.35),
			"desc": "Armor. Reduces damage taken. Equip it from the bag."})

const BLOCK_ITEM_KEYS := {
	DIRT: "dirt", STONE: "stone", SAND: "sand", SANDSTONE: "sandstone", SNOW: "snow",
	LOG: "log", LEAVES: "leaves", PINE_LEAVES: "pine_leaves", CACTUS: "cactus",
	PLANKS: "planks", STONE_BRICK: "stone_brick", GLASS: "glass", LAMP: "lamp", ASH: "ash",
	BASALT: "basalt", MYCELIUM: "mycelium", MUSH_STEM: "mush_stem", MUSH_CAP: "mush_cap",
	ICE: "ice", TORCH: "torch", CHEST: "chest", TABLE: "table", DOOR: "door", ROOF: "roof",
	PLASTER: "plaster", GRAVEL: "gravel", FLOWER_RED: "flower_red",
	FLOWER_YELLOW: "flower_yellow", FLOWER_BLUE: "flower_blue",
	DUNGEON_BRICK: "dungeon_brick", CRYSTAL_BLOCK: "crystal_block", RANCH: "ranch_banner",
	GRASS: "grass", COAL_ORE: "coal_ore", IRON_ORE: "iron_ore", GOLD_ORE: "gold_ore",
	CRYSTAL_ORE: "crystal_ore", FARMLAND: "farmland", WHEAT3: "wheat",
}

func _block_item_key(bid: int) -> String:
	return BLOCK_ITEM_KEYS.get(bid, "stone")

# ---------------------------------------------------------------- recipes

func _recipe(out: String, n: int, need: Dictionary, cat: String) -> void:
	RECIPES.append({"out": out, "n": n, "need": need, "cat": cat})

func _build_recipes() -> void:
	_recipe("planks", 4, {"log": 1}, "Blocks")
	_recipe("stick", 4, {"planks": 2}, "Blocks")
	_recipe("table", 1, {"planks": 4}, "Blocks")
	_recipe("chest", 1, {"planks": 8}, "Blocks")
	_recipe("torch", 4, {"stick": 1, "coal": 1}, "Blocks")
	_recipe("stone_brick", 4, {"stone": 4}, "Blocks")
	_recipe("glass", 2, {"sand": 2, "coal": 1}, "Blocks")
	_recipe("lamp", 1, {"gold_ingot": 2, "crystal": 2}, "Blocks")
	_recipe("crystal_block", 4, {"crystal": 4}, "Blocks")
	_recipe("roof", 4, {"sand": 2, "coal": 1}, "Blocks")
	_recipe("plaster", 4, {"sand": 2, "fiber": 2}, "Blocks")
	_recipe("door", 1, {"planks": 4}, "Blocks")
	_recipe("gravel", 2, {"stone": 1, "sand": 1}, "Blocks")

	_recipe("pick_wood", 1, {"planks": 3, "stick": 2}, "Tools")
	_recipe("axe_wood", 1, {"planks": 3, "stick": 2}, "Tools")
	_recipe("shovel_wood", 1, {"planks": 1, "stick": 2}, "Tools")
	_recipe("sword_wood", 1, {"planks": 2, "stick": 1}, "Tools")
	_recipe("hoe_wood", 1, {"planks": 2, "stick": 2}, "Tools")
	_recipe("pick_stone", 1, {"stone": 3, "stick": 2}, "Tools")
	_recipe("axe_stone", 1, {"stone": 3, "stick": 2}, "Tools")
	_recipe("shovel_stone", 1, {"stone": 1, "stick": 2}, "Tools")
	_recipe("sword_stone", 1, {"stone": 2, "stick": 1}, "Tools")
	_recipe("hoe_stone", 1, {"stone": 2, "stick": 2}, "Tools")
	_recipe("iron_ingot", 1, {"iron_ore": 1, "coal": 1}, "Misc")
	_recipe("gold_ingot", 1, {"gold_ore": 1, "coal": 1}, "Misc")
	_recipe("pick_iron", 1, {"iron_ingot": 3, "stick": 2}, "Tools")
	_recipe("axe_iron", 1, {"iron_ingot": 3, "stick": 2}, "Tools")
	_recipe("shovel_iron", 1, {"iron_ingot": 1, "stick": 2}, "Tools")
	_recipe("sword_iron", 1, {"iron_ingot": 2, "stick": 1}, "Tools")
	_recipe("hoe_iron", 1, {"iron_ingot": 2, "stick": 2}, "Tools")
	_recipe("pick_crystal", 1, {"crystal": 3, "stick": 2}, "Tools")
	_recipe("axe_crystal", 1, {"crystal": 3, "stick": 2}, "Tools")
	_recipe("shovel_crystal", 1, {"crystal": 1, "stick": 2}, "Tools")
	_recipe("sword_crystal", 1, {"crystal": 2, "stick": 1}, "Tools")
	_recipe("helm_iron", 1, {"iron_ingot": 5}, "Tools")
	_recipe("chest_iron", 1, {"iron_ingot": 8}, "Tools")
	_recipe("boots_iron", 1, {"iron_ingot": 4}, "Tools")
	_recipe("helm_crystal", 1, {"crystal": 5}, "Tools")
	_recipe("chest_crystal", 1, {"crystal": 8}, "Tools")
	_recipe("boots_crystal", 1, {"crystal": 4}, "Tools")

	_recipe("orb", 2, {"crystal": 1, "fiber": 2, "planks": 1}, "Monster")
	_recipe("orb_great", 1, {"orb": 3, "gold_ingot": 1, "crystal": 1}, "Monster")
	_recipe("feed", 2, {"wheat": 2, "berry": 2, "fiber": 1}, "Monster")
	_recipe("saddle", 1, {"leather": 4, "planks": 4, "fiber": 2}, "Monster")
	_recipe("ranch_banner", 1, {"planks": 8, "stone": 4, "fiber": 2, "orb": 1}, "Monster")
	_recipe("potion", 1, {"berry": 3, "crystal": 1}, "Misc")
	_recipe("roast_berry", 2, {"berry": 2, "coal": 1}, "Misc")
	_recipe("rift_key", 1, {"monster_core": 4, "crystal": 4, "amber": 2}, "Monster")

# ---------------------------------------------------------------- elements & variants

func _build_elements() -> void:
	ELEMENTS = {
		"Nature": {"name": "Nature", "color": Color("#7fd36b")},
		"Stone": {"name": "Stone", "color": Color("#b0a58f")},
		"Fire": {"name": "Fire", "color": Color("#ff8a4c")},
		"Frost": {"name": "Frost", "color": Color("#9adcf0")},
		"Sand": {"name": "Sand", "color": Color("#e8c87a")},
		"Light": {"name": "Light", "color": Color("#ffe18a")},
		"Water": {"name": "Water", "color": Color("#6fc9e8")},
		"Spark": {"name": "Spark", "color": Color("#ffe457")},
		"Shadow": {"name": "Shadow", "color": Color("#b08cd8")},
		"Toxic": {"name": "Toxic", "color": Color("#a9cf58")},
		"Wind": {"name": "Wind", "color": Color("#c8eadb")},
		"Void": {"name": "Void", "color": Color("#d98cf0")},
	}
	VARIANTS = {
		"normal": {"name": "Normal", "mult": 1.0, "accent": Color.TRANSPARENT, "chance": 1.0},
		"shiny": {"name": "Shiny", "mult": 1.15, "accent": Color("#ffd76a"), "chance": 0.06},
	}

# ---------------------------------------------------------------- monsters

func _species(id: String, name: String, element: String, shape: String, stage: int,
		palette: Array, opts: Dictionary) -> void:
	var d := {
		"id": id, "name": name, "element": element, "shape": shape, "stage": stage,
		"colors": {
			"body": Color(palette[0]), "belly": Color(palette[1]),
			"accent": Color(palette[2]), "eye": Color(palette[3]),
		},
		"hp": 24, "atk": 5, "def": 3, "spd": 3.6, "scale": 0.8, "catch": 0.5,
		"aggro": false, "rideable": false, "biomes": ["meadow"], "time": "any",
		"ability": "gathering", "evolve": "", "evolve_level": 0,
		"skill": "projectile", "power": 8, "srange": 6.0, "cooldown": 9.0,
		"egg": "field", "lore": "", "boss": false, "wild": true,
		"drops": [{"id": "fiber", "chance": 0.7, "min": 1, "max": 2}],
		"desc": "",
	}
	for k in opts:
		d[k] = opts[k]
	SPECIES[id] = d

func _build_monsters() -> void:
	_species("spriggle", "Spriggle", "Nature", "quad", 1, ["#7cc86a", "#f1e4bf", "#ffcf6b", "#243b2c"], {
		"hp": 28, "atk": 6, "def": 4, "spd": 3.6, "catch": 0.55, "biomes": ["meadow", "mushroom"],
		"ability": "farming", "evolve": "verdantail", "evolve_level": 12, "egg": "plant",
		"skill": "heal", "power": 10, "srange": 7.0, "cooldown": 10.0,
		"lore": "A tiny sprout growing its first pair of leaf wings.",
		"drops": [{"id": "fiber", "chance": 0.8, "min": 1, "max": 2}, {"id": "berry", "chance": 0.4}]})
	_species("verdantail", "Verdantail", "Nature", "quad", 2, ["#4f9d58", "#e6d7a7", "#ffb85c", "#1d3325"], {
		"hp": 48, "atk": 10, "def": 7, "spd": 3.9, "catch": 0.32, "scale": 1.05, "biomes": ["meadow"],
		"ability": "farming", "evolve": "sylvanox", "evolve_level": 26, "egg": "plant",
		"skill": "aoe", "power": 14, "srange": 5.0, "cooldown": 11.0, "wild": true,
		"lore": "Its flowering tail signals that the forest has healed.",
		"drops": [{"id": "fiber", "chance": 0.8, "min": 2, "max": 3}, {"id": "wheat", "chance": 0.3}]})
	_species("sylvanox", "Sylvanox", "Nature", "quad", 3, ["#346b46", "#dacb92", "#ffd166", "#13281b"], {
		"hp": 82, "atk": 16, "def": 12, "spd": 4.2, "catch": 0.16, "scale": 1.4, "rideable": true,
		"ability": "guard", "egg": "plant", "skill": "aoe", "power": 22, "srange": 5.5,
		"cooldown": 12.0, "wild": false, "lore": "A forest guardian with moss-covered antlers.",
		"drops": [{"id": "fiber", "chance": 1.0, "min": 2, "max": 4}, {"id": "monster_core", "chance": 0.15}]})
	_species("pebbit", "Pebbit", "Stone", "quad", 1, ["#a2a49a", "#e0d4b3", "#f0b35d", "#2d3230"], {
		"hp": 32, "atk": 6, "def": 7, "spd": 2.9, "catch": 0.55, "scale": 0.72,
		"biomes": ["meadow", "frost"], "ability": "mining", "evolve": "boulderon",
		"evolve_level": 14, "egg": "stone", "skill": "aoe", "power": 9, "srange": 3.5,
		"cooldown": 9.0, "lore": "Chews pebbles like candy.",
		"drops": [{"id": "stone", "chance": 0.6, "min": 1, "max": 2}, {"id": "coal", "chance": 0.25}]})
	_species("boulderon", "Boulderon", "Stone", "quad", 2, ["#7f8279", "#d8c7a3", "#ffc96b", "#242a27"], {
		"hp": 58, "atk": 11, "def": 12, "spd": 2.7, "catch": 0.3, "scale": 1.2,
		"biomes": ["frost"], "ability": "mining", "evolve": "terrabor", "evolve_level": 28,
		"egg": "stone", "skill": "aoe", "power": 15, "srange": 4.0, "cooldown": 10.0,
		"lore": "A stone back that hides veins of ore.",
		"drops": [{"id": "stone", "chance": 1.0, "min": 2, "max": 4}, {"id": "iron_ore", "chance": 0.3}]})
	_species("terrabor", "Terrabor", "Stone", "golem", 3, ["#66695f", "#c4b28c", "#6fe4d4", "#1c2420"], {
		"hp": 105, "atk": 18, "def": 16, "spd": 3.1, "catch": 0.12, "scale": 1.6, "rideable": true,
		"ability": "guard", "egg": "stone", "skill": "aoe", "power": 24, "srange": 5.0,
		"cooldown": 12.0, "wild": false, "lore": "An ancient golem; its steps shake the caves.",
		"drops": [{"id": "stone", "chance": 1.0, "min": 3, "max": 5}, {"id": "monster_core", "chance": 0.2}]})
	_species("emberpup", "Emberpup", "Fire", "quad", 1, ["#e27a45", "#f3d6a0", "#ffd166", "#331d1a"], {
		"hp": 30, "atk": 9, "def": 3, "spd": 3.9, "catch": 0.5, "biomes": ["ash"],
		"aggro": true, "ability": "smelting", "evolve": "pyroar", "evolve_level": 13,
		"egg": "ember", "skill": "projectile", "power": 11, "srange": 7.0, "cooldown": 8.0,
		"lore": "A little fire fox that chases sparks through the ash.",
		"drops": [{"id": "coal", "chance": 0.5, "min": 1, "max": 2}, {"id": "leather", "chance": 0.3}]})
	_species("pyroar", "Pyroar", "Fire", "quad", 2, ["#b54c34", "#e8b77c", "#ffe07a", "#2b1715"], {
		"hp": 55, "atk": 14, "def": 6, "spd": 4.4, "catch": 0.3, "scale": 1.2, "rideable": true,
		"biomes": ["ash"], "aggro": true, "ability": "smelting", "evolve": "vulcanox",
		"evolve_level": 27, "egg": "ember", "skill": "projectile", "power": 17, "srange": 8.0,
		"cooldown": 9.0, "lore": "Its fiery mane is hot enough to melt iron.",
		"drops": [{"id": "coal", "chance": 0.8, "min": 1, "max": 3}, {"id": "amber", "chance": 0.3}]})
	_species("vulcanox", "Vulcanox", "Fire", "quad", 3, ["#863d2b", "#d99a5c", "#ffcf5c", "#201110"], {
		"hp": 90, "atk": 22, "def": 9, "spd": 4.6, "catch": 0.1, "scale": 1.5, "rideable": true,
		"biomes": ["ash"], "aggro": true, "ability": "guard", "egg": "ember",
		"skill": "projectile", "power": 26, "srange": 9.0, "cooldown": 9.0, "wild": false,
		"lore": "King of the caldera, with breath of embers.",
		"drops": [{"id": "coal", "chance": 1.0, "min": 2, "max": 4}, {"id": "monster_core", "chance": 0.15}]})
	_species("frostbun", "Frostbun", "Frost", "quad", 1, ["#e8f1f2", "#bfe0e8", "#9adcf0", "#2b3a40"], {
		"hp": 26, "atk": 5, "def": 4, "spd": 4.3, "catch": 0.6, "scale": 0.68,
		"biomes": ["frost"], "ability": "speed", "evolve": "cryostag", "evolve_level": 12,
		"egg": "frost", "skill": "buff", "power": 10, "srange": 4.0, "cooldown": 10.0,
		"lore": "Its ears chill the air around it.",
		"drops": [{"id": "fiber", "chance": 0.7, "min": 1, "max": 2}, {"id": "snow", "chance": 0.5}]})
	_species("cryostag", "Cryostag", "Frost", "quad", 2, ["#cfe5ec", "#a6d3e0", "#bfefff", "#273a44"], {
		"hp": 62, "atk": 12, "def": 9, "spd": 5.1, "catch": 0.28, "scale": 1.3, "rideable": true,
		"biomes": ["frost"], "ability": "speed", "egg": "frost", "skill": "projectile",
		"power": 16, "srange": 8.0, "cooldown": 9.0, "lore": "An ice stag that looks like a walking aurora.",
		"drops": [{"id": "leather", "chance": 0.5}, {"id": "crystal", "chance": 0.2}]})
	_species("duneel", "Duneel", "Sand", "serpent", 1, ["#d8b574", "#f0dcae", "#ffdb8c", "#3a2d22"], {
		"hp": 27, "atk": 8, "def": 2, "spd": 4.1, "catch": 0.5, "scale": 0.7,
		"biomes": ["desert"], "aggro": true, "ability": "mining", "evolve": "sandwyrm",
		"evolve_level": 15, "egg": "dune", "skill": "dash", "power": 10, "srange": 4.0,
		"cooldown": 8.0, "lore": "Swims through sand without leaving a trace.",
		"drops": [{"id": "sand", "chance": 0.6, "min": 1, "max": 2}, {"id": "leather", "chance": 0.3}]})
	_species("sandwyrm", "Sandwyrm", "Sand", "serpent", 2, ["#bd9757", "#e8d19b", "#ffcf6b", "#2c221a"], {
		"hp": 52, "atk": 13, "def": 5, "spd": 4.5, "catch": 0.3, "scale": 1.15,
		"biomes": ["desert"], "aggro": true, "ability": "mining", "egg": "dune",
		"skill": "dash", "power": 17, "srange": 5.0, "cooldown": 9.0,
		"lore": "A desert wyrm that carves tunnels under the dunes.",
		"drops": [{"id": "sand", "chance": 0.8, "min": 2, "max": 4}, {"id": "gold_ore", "chance": 0.2}]})
	_species("glimmerwing", "Glimmerwing", "Light", "floater", 1, ["#b9a9e8", "#f6e7ff", "#9ff0e2", "#2d2840"], {
		"hp": 24, "atk": 6, "def": 2, "spd": 4.7, "catch": 0.45, "scale": 0.62,
		"biomes": ["mushroom", "frost"], "time": "night", "ability": "glow",
		"evolve": "luminmoth", "evolve_level": 14, "egg": "glow", "skill": "projectile",
		"power": 9, "srange": 7.5, "cooldown": 8.0,
		"lore": "Its wing dust glows when the moon rises.",
		"drops": [{"id": "crystal", "chance": 0.25}, {"id": "fiber", "chance": 0.6}]})
	_species("luminmoth", "Luminmoth", "Light", "floater", 2, ["#8f7cd4", "#ffecc8", "#b9fff3", "#241f38"], {
		"hp": 44, "atk": 10, "def": 4, "spd": 5.0, "catch": 0.24, "scale": 1.0,
		"biomes": ["mushroom"], "time": "night", "ability": "healing", "egg": "glow",
		"skill": "heal", "power": 20, "srange": 8.0, "cooldown": 10.0,
		"lore": "The light of its wings mends small wounds.",
		"drops": [{"id": "crystal", "chance": 0.4}, {"id": "monster_core", "chance": 0.08}]})
	_species("mushmo", "Mushmo", "Nature", "biped", 1, ["#e5cfa2", "#f5e6c8", "#c95050", "#332621"], {
		"hp": 36, "atk": 5, "def": 6, "spd": 2.7, "catch": 0.65, "scale": 0.78,
		"biomes": ["mushroom"], "ability": "farming", "evolve": "sporax", "evolve_level": 15,
		"egg": "spore", "skill": "heal", "power": 12, "srange": 7.0, "cooldown": 10.0,
		"lore": "Grows from spores carefully planted by farmers.",
		"drops": [{"id": "mush_cap", "chance": 0.7, "min": 1, "max": 2}, {"id": "fiber", "chance": 0.5}]})
	_species("sporax", "Sporax", "Nature", "biped", 2, ["#cbb185", "#e8d6a8", "#a84343", "#2b201c"], {
		"hp": 58, "atk": 11, "def": 10, "spd": 2.9, "catch": 0.3, "scale": 1.15,
		"biomes": ["mushroom"], "ability": "farming", "egg": "spore", "skill": "heal",
		"power": 22, "srange": 8.0, "cooldown": 11.0,
		"lore": "Its giant cap marks the age of the forest.",
		"drops": [{"id": "mush_cap", "chance": 0.9, "min": 2, "max": 3}, {"id": "monster_core", "chance": 0.1}]})
	_species("aquafin", "Aquafin", "Water", "quad", 1, ["#62b9b0", "#d6f1e7", "#7fe1e8", "#1f3335"], {
		"hp": 30, "atk": 7, "def": 5, "spd": 4.2, "catch": 0.55, "scale": 0.75,
		"biomes": ["meadow"], "ability": "fishing", "evolve": "tidalfin", "evolve_level": 14,
		"egg": "water", "skill": "heal", "power": 12, "srange": 7.0, "cooldown": 9.0,
		"lore": "The tufts on its ears store rainwater.",
		"drops": [{"id": "leather", "chance": 0.4}, {"id": "fiber", "chance": 0.4}]})
	_species("tidalfin", "Tidalfin", "Water", "quad", 2, ["#3e9d9c", "#c2e9df", "#6fdcdf", "#182c2e"], {
		"hp": 57, "atk": 13, "def": 8, "spd": 4.6, "catch": 0.3, "scale": 1.2, "rideable": true,
		"biomes": ["meadow"], "ability": "fishing", "egg": "water", "skill": "projectile",
		"power": 16, "srange": 8.0, "cooldown": 9.0,
		"lore": "Swims through strong currents to find pearls.",
		"drops": [{"id": "crystal", "chance": 0.25}, {"id": "leather", "chance": 0.5}]})
	_species("voltkit", "Voltkit", "Spark", "quad", 1, ["#f2cf58", "#f7e8b0", "#4d4549", "#2b2628"], {
		"hp": 26, "atk": 8, "def": 3, "spd": 4.9, "catch": 0.45, "scale": 0.62,
		"biomes": ["meadow"], "ability": "speed", "evolve": "stormtail", "evolve_level": 16,
		"egg": "storm", "skill": "dash", "power": 10, "srange": 5.0, "cooldown": 8.0,
		"lore": "Collects lightning from storm clouds.",
		"drops": [{"id": "fiber", "chance": 0.5}, {"id": "amber", "chance": 0.2}]})
	_species("stormtail", "Stormtail", "Spark", "quad", 2, ["#d8ab32", "#e9d99a", "#fff08a", "#242124"], {
		"hp": 50, "atk": 13, "def": 5, "spd": 5.3, "catch": 0.25, "scale": 1.1,
		"biomes": ["meadow", "ash"], "ability": "speed", "egg": "storm", "skill": "dash", "power": 18,
		"srange": 6.0, "cooldown": 9.0,
		"lore": "Its long tail cracks the air like thunder.",
		"drops": [{"id": "crystal", "chance": 0.2}, {"id": "amber", "chance": 0.3}]})
	_species("shadelet", "Shadelet", "Shadow", "floater", 1, ["#50405f", "#a97ebb", "#c08ff0", "#171120"], {
		"hp": 24, "atk": 9, "def": 2, "spd": 4.5, "catch": 0.45, "scale": 0.66,
		"biomes": ["meadow", "mushroom"], "time": "night", "aggro": true,
		"ability": "gathering", "evolve": "nocturne", "evolve_level": 15, "egg": "shadow",
		"skill": "dash", "power": 11, "srange": 5.0, "cooldown": 8.0,
		"lore": "A little shadow that steals fruit at night.",
		"drops": [{"id": "fiber", "chance": 0.6}, {"id": "amber", "chance": 0.15}]})
	_species("nocturne", "Nocturne", "Shadow", "floater", 2, ["#3c2f4c", "#8f6fae", "#d6a3ff", "#120d18"], {
		"hp": 48, "atk": 14, "def": 5, "spd": 5.0, "catch": 0.22, "scale": 1.05,
		"biomes": ["meadow"], "time": "night", "aggro": true, "ability": "gathering",
		"egg": "shadow", "skill": "dash", "power": 19, "srange": 6.0, "cooldown": 9.0,
		"lore": "Its wings swallow torchlight.",
		"drops": [{"id": "amber", "chance": 0.4}, {"id": "monster_core", "chance": 0.08}]})
	_species("thornback", "Thornback", "Nature", "quad", 1, ["#6d9c4c", "#c4b06b", "#c94f4f", "#2a3322"], {
		"hp": 48, "atk": 8, "def": 11, "spd": 2.4, "catch": 0.4, "scale": 0.95,
		"biomes": ["desert"], "ability": "harvest", "evolve": "cactitan", "evolve_level": 18,
		"egg": "plant", "skill": "aoe", "power": 12, "srange": 3.5, "cooldown": 10.0,
		"lore": "The cactus on its back purifies groundwater.",
		"drops": [{"id": "cactus", "chance": 0.5}, {"id": "fiber", "chance": 0.6}]})
	_species("cactitan", "Cactitan", "Nature", "golem", 2, ["#56843f", "#b39e60", "#e06a5a", "#212b1c"], {
		"hp": 82, "atk": 13, "def": 16, "spd": 2.8, "catch": 0.18, "scale": 1.45, "rideable": true,
		"biomes": ["desert"], "ability": "harvest", "egg": "plant", "skill": "aoe",
		"power": 18, "srange": 4.0, "cooldown": 11.0,
		"lore": "A walking fortress that blooms once a century.",
		"drops": [{"id": "cactus", "chance": 1.0, "min": 2, "max": 4}, {"id": "leather", "chance": 0.3}]})
	_species("cinderling", "Cinderling", "Fire", "floater", 1, ["#e77b3d", "#ffd7a1", "#ffe27a", "#2c1c18"], {
		"hp": 22, "atk": 7, "def": 2, "spd": 3.3, "catch": 0.55, "scale": 0.56,
		"biomes": ["ash"], "ability": "smelting", "egg": "ember", "skill": "projectile",
		"power": 9, "srange": 7.0, "cooldown": 8.0,
		"lore": "A living ember dancing over the ash.",
		"drops": [{"id": "coal", "chance": 0.5}, {"id": "amber", "chance": 0.1}]})
	_species("breezel", "Breezel", "Wind", "floater", 1, ["#c9e8d8", "#f3faf4", "#9bd6b8", "#2c3b35"], {
		"hp": 24, "atk": 5, "def": 2, "spd": 5.2, "catch": 0.5, "scale": 0.6,
		"biomes": ["meadow", "frost"], "ability": "glide", "evolve": "zephyrix",
		"evolve_level": 16, "egg": "sky", "skill": "buff", "power": 10, "srange": 5.0,
		"cooldown": 10.0, "lore": "A flying seed searching for new soil.",
		"drops": [{"id": "fiber", "chance": 0.6}, {"id": "seeds", "chance": 0.3}]})
	_species("zephyrix", "Zephyrix", "Wind", "floater", 2, ["#a7dcc4", "#eef9f1", "#7fd1b0", "#23322c"], {
		"hp": 50, "atk": 11, "def": 5, "spd": 5.7, "catch": 0.2, "scale": 1.25, "rideable": true,
		"biomes": ["frost"], "ability": "glide", "egg": "sky", "skill": "buff",
		"power": 16, "srange": 6.0, "cooldown": 10.0,
		"lore": "A wind bird carrying news from the peaks.",
		"drops": [{"id": "fiber", "chance": 0.8, "min": 2, "max": 3}, {"id": "monster_core", "chance": 0.08}]})
	_species("skitter", "Skitter", "Toxic", "insect", 1, ["#7e3d48", "#c9666e", "#b8e05a", "#241417"], {
		"hp": 18, "atk": 10, "def": 1, "spd": 4.7, "catch": 0.55, "scale": 0.5,
		"biomes": ["desert", "meadow"], "time": "night", "aggro": true,
		"ability": "gathering", "evolve": "venomaw", "evolve_level": 13, "egg": "shadow",
		"skill": "dash", "power": 9, "srange": 4.0, "cooldown": 7.0,
		"lore": "Its tiny legs quiver before it strikes.",
		"drops": [{"id": "fiber", "chance": 0.5}, {"id": "amber", "chance": 0.2}]})
	_species("venomaw", "Venomaw", "Toxic", "insect", 2, ["#5f2e37", "#b05059", "#a4cc4d", "#1d1012"], {
		"hp": 40, "atk": 16, "def": 4, "spd": 4.8, "catch": 0.28, "scale": 0.9,
		"biomes": ["desert"], "time": "night", "aggro": true, "ability": "gathering",
		"egg": "shadow", "skill": "dash", "power": 18, "srange": 5.0, "cooldown": 8.0,
		"lore": "Its jaws hold venom that freezes the veins.",
		"drops": [{"id": "leather", "chance": 0.4}, {"id": "crystal", "chance": 0.15}]})
	_species("golett", "Golett", "Stone", "golem", 1, ["#9a9c92", "#c9bfa7", "#70b8b0", "#262b29"], {
		"hp": 52, "atk": 8, "def": 13, "spd": 2.1, "catch": 0.35, "scale": 1.0,
		"biomes": ["meadow", "frost", "ash"], "time": "any", "ability": "hauler",
		"evolve": "titangolem", "evolve_level": 20, "egg": "stone", "skill": "aoe",
		"power": 11, "srange": 4.0, "cooldown": 10.0,
		"lore": "A chunk of stone that learned to walk.",
		"drops": [{"id": "stone", "chance": 0.9, "min": 2, "max": 3}, {"id": "iron_ore", "chance": 0.2}]})
	_species("titangolem", "Titangolem", "Stone", "golem", 2, ["#777d74", "#b5a889", "#70e0d4", "#1c2120"], {
		"hp": 100, "atk": 15, "def": 19, "spd": 2.5, "catch": 0.15, "scale": 1.6, "rideable": true,
		"biomes": ["frost"], "ability": "hauler", "egg": "stone", "skill": "aoe",
		"power": 20, "srange": 5.0, "cooldown": 12.0,
		"lore": "It has guarded crystal veins for thousands of years.",
		"drops": [{"id": "iron_ore", "chance": 0.6, "min": 2, "max": 3}, {"id": "monster_core", "chance": 0.1}]})
	_species("snowmaw", "Snowmaw", "Frost", "quad", 1, ["#d8e6e9", "#b1ccd4", "#e76f76", "#2b3437"], {
		"hp": 58, "atk": 13, "def": 8, "spd": 3.6, "catch": 0.35, "scale": 1.15,
		"biomes": ["frost"], "aggro": true, "ability": "guard", "evolve": "frostmaw",
		"evolve_level": 18, "egg": "frost", "skill": "projectile", "power": 14, "srange": 7.0,
		"cooldown": 9.0, "lore": "A snow bear that sleeps through winter.",
		"drops": [{"id": "leather", "chance": 0.7, "min": 2, "max": 3}, {"id": "snow", "chance": 0.4}]})
	_species("frostmaw", "Frostmaw", "Frost", "quad", 2, ["#bfd5da", "#9ab9c2", "#e05c66", "#222b2e"], {
		"hp": 92, "atk": 17, "def": 12, "spd": 4.0, "catch": 0.16, "scale": 1.5, "rideable": true,
		"biomes": ["frost"], "aggro": true, "ability": "guard", "egg": "frost",
		"skill": "projectile", "power": 21, "srange": 8.0, "cooldown": 9.0,
		"lore": "Its cold roar shakes the valley.",
		"drops": [{"id": "leather", "chance": 1.0, "min": 2, "max": 4}, {"id": "monster_core", "chance": 0.12}]})
	_species("lumino", "Lumino", "Light", "floater", 1, ["#f5e3a6", "#fff6d8", "#ffc95c", "#3a3324"], {
		"hp": 20, "atk": 4, "def": 3, "spd": 4.1, "catch": 0.55, "scale": 0.55,
		"biomes": ["mushroom"], "time": "night", "ability": "healing", "egg": "glow",
		"skill": "heal", "power": 16, "srange": 8.0, "cooldown": 10.0,
		"lore": "A soft orb of light that guides travelers.",
		"drops": [{"id": "crystal", "chance": 0.3}, {"id": "fiber", "chance": 0.4}]})
	_species("gloomcap", "Gloomcap", "Shadow", "biped", 1, ["#6d5678", "#9c7f9f", "#c77dd6", "#221927"], {
		"hp": 38, "atk": 11, "def": 6, "spd": 3.2, "catch": 0.38, "scale": 0.9,
		"biomes": ["mushroom"], "aggro": true, "ability": "spore", "egg": "spore",
		"skill": "aoe", "power": 12, "srange": 4.0, "cooldown": 9.0,
		"lore": "Its cap releases nightmare spores.",
		"drops": [{"id": "mush_cap", "chance": 0.8}, {"id": "amber", "chance": 0.25}]})
	_species("aurorae", "Aurorae", "Frost", "serpent", 1, ["#a8e6e1", "#e8f6ff", "#d39cf0", "#2c3841"], {
		"hp": 42, "atk": 11, "def": 6, "spd": 4.8, "catch": 0.2, "scale": 1.0,
		"biomes": ["frost"], "time": "night", "ability": "glow", "egg": "frost",
		"skill": "heal", "power": 20, "srange": 8.0, "cooldown": 11.0,
		"lore": "A serpent of light that appears only under northern skies.",
		"drops": [{"id": "crystal", "chance": 0.6, "min": 2, "max": 3}, {"id": "monster_core", "chance": 0.2}]})

	_species("warden_stone", "Grand Warden", "Stone", "golem", 4, ["#5d6159", "#9f987e", "#6fe4d4", "#131a17"], {
		"hp": 300, "atk": 24, "def": 20, "spd": 3.0, "catch": 0.03, "scale": 2.0,
		"biomes": [], "aggro": true, "ability": "guard", "egg": "stone", "boss": true,
		"wild": false, "skill": "aoe", "power": 30, "srange": 6.0, "cooldown": 8.0,
		"lore": "The guardian of the depths beneath Emerald Vale.",
		"drops": [{"id": "monster_core", "chance": 1.0, "min": 2, "max": 3}, {"id": "crystal", "chance": 1.0, "min": 3, "max": 5}]})
	_species("vulcanyx", "Vulcanyx", "Fire", "serpent", 4, ["#7e3325", "#e08a4b", "#ffdb6a", "#1c0e0c"], {
		"hp": 340, "atk": 31, "def": 16, "spd": 3.7, "catch": 0.03, "scale": 2.2,
		"biomes": [], "aggro": true, "ability": "guard", "egg": "ember", "boss": true,
		"wild": false, "skill": "projectile", "power": 34, "srange": 10.0, "cooldown": 7.0,
		"lore": "A caldera dragon guarding the Primordial Forge.",
		"drops": [{"id": "monster_core", "chance": 1.0, "min": 2, "max": 4}, {"id": "gold_ore", "chance": 1.0, "min": 4, "max": 6}]})
	_species("glacira", "Glacira", "Frost", "serpent", 4, ["#9ccdd8", "#e6f4f7", "#b892ea", "#223037"], {
		"hp": 320, "atk": 27, "def": 19, "spd": 3.5, "catch": 0.03, "scale": 2.1,
		"biomes": [], "aggro": true, "ability": "guard", "egg": "frost", "boss": true,
		"wild": false, "skill": "projectile", "power": 30, "srange": 10.0, "cooldown": 7.0,
		"lore": "The ice dragon at the heart of Frozen Peaks.",
		"drops": [{"id": "monster_core", "chance": 1.0, "min": 2, "max": 4}, {"id": "crystal", "chance": 1.0, "min": 4, "max": 6}]})
	_species("riftmaw", "Riftmaw", "Void", "serpent", 4, ["#3b2d53", "#8e6fc8", "#f09de8", "#100c16"], {
		"hp": 620, "atk": 38, "def": 24, "spd": 4.2, "catch": 0.01, "scale": 2.4,
		"biomes": [], "aggro": true, "ability": "guard", "egg": "shadow", "boss": true,
		"wild": false, "skill": "aoe", "power": 40, "srange": 7.0, "cooldown": 6.0,
		"lore": "A being from beyond the World Rift. The final trial.",
		"drops": [{"id": "monster_core", "chance": 1.0, "min": 5, "max": 8}, {"id": "crystal", "chance": 1.0, "min": 5, "max": 8}]})

	for id in SPECIES:
		var sp: Dictionary = SPECIES[id]
		sp["desc"] = "%s • %s" % [ELEMENTS.get(sp.element, {}).get("name", sp.element),
			ability_name(sp.ability)]

# ---------------------------------------------------------------- biomes

func _biome(id: String, name: String, surface: int, sub: int, tree: String, sky: String,
		horizon: String, fog: String, grass: String, opts: Dictionary) -> void:
	var d := {
		"id": id, "name": name, "surface": surface, "sub": sub, "tree": tree,
		"sky": Color(sky), "horizon": Color(horizon), "fog": Color(fog),
		"map_color": Color(grass), "desc": "",
	}
	for k in opts:
		d[k] = opts[k]
	BIOMES[id] = d

func _build_biomes() -> void:
	_biome("meadow", "Emerald Vale", GRASS, DIRT, "oak", "#79c8d9", "#dff1e3", "#b6d9d0", "#6fbf5e", {
		"desc": "A fertile vale of forests, rivers, and villages."})
	_biome("desert", "Amber Desert", SAND, SANDSTONE, "cactus", "#f0d49a", "#ffe9c0", "#e8caa0", "#ddc38a", {
		"desc": "Hot dunes, cacti, and burrowing monsters."})
	_biome("frost", "Frozen Peaks", SNOW, STONE, "pine", "#b8d6e8", "#eef6f8", "#d4e4e8", "#e7f0f3", {
		"desc": "Snowy mountains, pine woods, and frozen lakes."})
	_biome("mushroom", "Sporewood", MYCELIUM, DIRT, "giant_mushroom", "#8b7bb8", "#e6d7f2", "#cbb8d8", "#9a7ba6", {
		"desc": "A forest of giant mushrooms that glows at night."})
	_biome("ash", "Ashen Reach", ASH, BASALT, "dead", "#7d5f5b", "#d9a681", "#b08072", "#59504c", {
		"desc": "A volcanic plain of lava lakes and fire monsters."})

# ---------------------------------------------------------------- quests / objectives

func _build_quests() -> void:
	OBJECTIVES = [
		{"id": "wood", "title": "Touch the Forest", "desc": "Collect 10 Logs.",
			"type": "item", "target": "log", "goal": 10, "xp": 40, "amber": 10},
		{"id": "table", "title": "Crafting Table", "desc": "Craft and place a Crafting Table.",
			"type": "flag", "target": "table_placed", "goal": 1, "xp": 30, "amber": 8},
		{"id": "catch", "title": "First Friend", "desc": "Capture one wild monster.",
			"type": "capture", "target": "", "goal": 1, "xp": 80, "amber": 20},
		{"id": "stone", "title": "Deeper Down", "desc": "Mine 15 Stone.",
			"type": "item", "target": "stone", "goal": 15, "xp": 40, "amber": 10},
		{"id": "ranch", "title": "Monster Home", "desc": "Build a Ranch Banner and open it.",
			"type": "flag", "target": "ranch_built", "goal": 1, "xp": 120, "amber": 30},
		{"id": "evolve", "title": "Evolution!", "desc": "Evolve a monster.",
			"type": "flag", "target": "evolved", "goal": 1, "xp": 100, "amber": 25},
		{"id": "dungeon", "title": "Shadow Below", "desc": "Defeat a dungeon boss.",
			"type": "boss", "target": "", "goal": 1, "xp": 250, "amber": 60},
		{"id": "rift", "title": "Rift Warden", "desc": "Clear 5 waves of the World Rift.",
			"type": "rift", "target": "", "goal": 5, "xp": 600, "amber": 150},
		{"id": "collector", "title": "Collector", "desc": "Register 12 species in the Codex.",
			"type": "codex", "target": "", "goal": 12, "xp": 300, "amber": 80},
	]
	QUEST_TEMPLATES = [
		{"kind": "gather", "items": ["fiber", "log", "stone", "berry", "wheat", "crystal"],
			"count": [4, 12], "xp": 60, "amber": [12, 30]},
		{"kind": "hunt", "count": [2, 5], "xp": 80, "amber": [15, 35]},
		{"kind": "capture", "count": [1, 2], "xp": 100, "amber": [20, 45]},
	]
	VILLAGE_NAMES = ["Sprout Hollow", "Amber Village", "Rice Hamlet", "Ember Home", "Mist Lodge",
		"Root Village", "Stone Village", "Moon Valley", "Snow Hamlet", "Clear Coast",
		"Painted Hill", "Spore Village", "Far Village", "Sunfield", "Breeze Lodge"]
	NPC_NAMES = ["Rowan", "Mira", "Bram", "Elara", "Finn", "Lena", "Orin", "Nia", "Rook", "Sage",
		"Talia", "Bran", "Isla", "Dain", "Maeve", "Kael", "Poppy", "Rhea", "Ash", "Nell",
		"Gideon", "Wren", "Arlo", "Selene", "Marlow", "Greta", "Hazel", "Owen", "Lyra", "Aden"]

func _build_merchant() -> void:
	MERCHANT_STOCK = [
		{"id": "orb", "n": 1, "price": 12},
		{"id": "feed", "n": 2, "price": 8},
		{"id": "seeds", "n": 4, "price": 6},
		{"id": "torch", "n": 6, "price": 5},
		{"id": "pick_iron", "n": 1, "price": 45},
		{"id": "potion", "n": 1, "price": 18},
		{"id": "saddle", "n": 1, "price": 60},
	]
	MERCHANT_BUY = [
		{"id": "fiber", "price": 2}, {"id": "log", "price": 2}, {"id": "stone", "price": 1},
		{"id": "coal", "price": 3}, {"id": "iron_ore", "price": 5}, {"id": "crystal", "price": 9},
		{"id": "amber", "price": 5}, {"id": "wheat", "price": 3}, {"id": "mush_cap", "price": 4},
		{"id": "leather", "price": 6},
	]

# ---------------------------------------------------------------- helper API

func get_item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id.capitalize())

func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

func get_block(id: int) -> Dictionary:
	return BLOCKS.get(id, BLOCKS[STONE])

func is_solid(id: int) -> bool:
	if id == AIR:
		return false
	return BLOCKS.get(id, {}).get("solid", true)

func is_opaque(id: int) -> bool:
	if id == AIR:
		return false
	return BLOCKS.get(id, {}).get("opaque", true)

func is_liquid(id: int) -> bool:
	return id == WATER or id == LAVA

func is_plant(id: int) -> bool:
	return BLOCKS.get(id, {}).get("plant", false)

func block_for_item(item_id: String) -> int:
	return int(ITEMS.get(item_id, {}).get("block", -1))

func _as_color(v) -> Color:
	if v is Color:
		return v
	return Color(str(v))

func get_icon(item_id: String) -> Texture2D:
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]
	var item: Dictionary = ITEMS.get(item_id, {})
	if item.is_empty():
		return null
	var img: Image
	if item.get("type", "") == "block":
		var tile_idx := int(item.get("icon_tile", 0))
		var rect := Rect2i((tile_idx % TILE_COLUMNS) * PixelArt.T, (tile_idx / TILE_COLUMNS) * PixelArt.T, PixelArt.T, PixelArt.T)
		var tile_img := atlas_image.get_region(rect)
		var flat := item_id in ["torch", "flower_red", "flower_yellow", "flower_blue", "ranch_banner", "door", "glass"]
		img = PixelArt.block_icon(tile_img, flat)
	else:
		img = PixelArt.icon(str(item.get("icon", "ore")),
			_as_color(item.get("color", "#cccccc")),
			_as_color(item.get("color2", "#ffffff")),
			_as_color(item.get("color3", "#ffe2a8")))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[item_id] = tex
	return tex

func get_held_texture(item_id: String) -> Texture2D:
	if _held_cache.has(item_id):
		return _held_cache[item_id]
	var it: Dictionary = ITEMS.get(item_id, {})
	var tex: Texture2D = null
	if str(it.get("tool_kind", "")) == "sword":
		tex = ImageTexture.create_from_image(PixelArt.held_sword(int(it.get("tier", 1)),
			_as_color(it.get("color", "#cccccc"))))
	else:
		tex = get_icon(item_id)
	_held_cache[item_id] = tex
	return tex

func get_block_icon(block_id: int) -> Texture2D:
	var key := _block_item_key(block_id)
	if ITEMS.has(key):
		return get_icon(key)
	return atlas_texture

func block_color(block_id: int) -> Color:
	if _color_cache.has(block_id):
		return _color_cache[block_id]
	var bd: Dictionary = BLOCKS.get(block_id, BLOCKS[STONE])
	var tile_idx: int = int(bd.get("icon_tile", bd.get("side", 0)))
	var rect := Rect2i((tile_idx % TILE_COLUMNS) * PixelArt.T, (tile_idx / TILE_COLUMNS) * PixelArt.T, PixelArt.T, PixelArt.T)
	var img := atlas_image.get_region(rect)
	var sum := Color(0, 0, 0, 1)
	var count := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.2:
				sum.r += c.r
				sum.g += c.g
				sum.b += c.b
				count += 1
	if count > 0:
		sum.r /= float(count)
		sum.g /= float(count)
		sum.b /= float(count)
	_color_cache[block_id] = sum
	return sum

func get_tile_texture(tile_name: String) -> AtlasTexture:
	var idx := int(TILES.get(tile_name, 0))
	var at := AtlasTexture.new()
	at.atlas = atlas_texture
	at.region = Rect2((idx % TILE_COLUMNS) * PixelArt.T, (idx / TILE_COLUMNS) * PixelArt.T, PixelArt.T, PixelArt.T)
	return at

func get_monster_portrait(species_id: String) -> Texture2D:
	if _portrait_cache.has(species_id):
		return _portrait_cache[species_id]
	var sp: Dictionary = SPECIES.get(species_id, {})
	if sp.is_empty():
		return null
	var palette: Dictionary = sp.colors
	var img := PixelArt.portrait(str(sp.shape), palette.body, palette.belly, palette.accent, palette.eye)
	var tex := ImageTexture.create_from_image(img)
	_portrait_cache[species_id] = tex
	return tex


func _pattern_value(pattern: String, x: int, y: int) -> float:
	match pattern:
					"fur":
									return 0.55 if ((x * 7 + y * 13) % 9) == 0 else (-0.4 if ((x + y * 3) % 11) == 0 else 0.0)
					"scale":
									var off := 0 if (y / 3) % 2 == 0 else 2
									return -0.6 if ((x + off) % 4 == 0 or y % 3 == 0) else 0.25
					"crack":
									return -0.85 if ((x * 3 + y * 5) % 17) == 0 or ((x + y) % 23) == 0 else 0.2
					"ember":
									return 0.9 if ((x * 2 + y) % 7) == 0 else (-0.5 if ((x + y * 2) % 13) == 0 else 0.0)
					"spark":
									return 1.0 if ((x * 5 - y * 3) % 19) == 0 else 0.0
					"spore":
									return 0.7 if ((x * x + y * y) % 11) < 2 else -0.3
					"sand":
									return -0.35 if y % 4 == 0 else 0.15
					"crystal":
									return 0.8 if ((x + y) % 6) == 0 else -0.4
					"void":
									return 0.9 if ((x * 13 + y * 7) % 29) == 0 else 0.0
	return 0.0

func monster_texture(color: Color, pattern: String) -> ImageTexture:
	var key := "%s_%s" % [color.to_html(), pattern]
	if _monster_tex_cache.has(key):
					return _monster_tex_cache[key]
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var top := color.lightened(0.17)
	var bottom := color.darkened(0.24)
	for y in size:
					var t := float(y) / float(size - 1)
					var base := bottom.lerp(top, 1.0 - t)
					for x in size:
									var shade := _pattern_value(pattern, x, y)
									var c := base
									if shade > 0.0:
													c = base.lightened(0.11 * shade)
									elif shade < 0.0:
													c = base.darkened(0.14 * -shade)
									img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_monster_tex_cache[key] = tex
	return tex

func monster_material(color: Color, emissive: bool = false, alpha: float = 1.0,
					pattern: String = "") -> StandardMaterial3D:
	var key := "%s_%s_%s_%s" % [color.to_html(), emissive, alpha, pattern]
	if _monster_mat_cache.has(key):
					return _monster_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if alpha < 1.0:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
					mat.emission_enabled = true
					mat.emission = color
					mat.emission_energy_multiplier = 0.7
	elif pattern != "":
					mat.albedo_color = Color(1, 1, 1, alpha)
					mat.albedo_texture = monster_texture(color, pattern)
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					mat.uv1_scale = Vector3(1.7, 1.7, 1.7)
					mat.uv1_triplanar = false
	_monster_mat_cache[key] = mat
	return mat

func element_color(element: String) -> Color:
	return ELEMENTS.get(element, {}).get("color", Color.WHITE)

func element_name(element: String) -> String:
	return ELEMENTS.get(element, {}).get("name", element)

func ability_name(ability: String) -> String:
	var names := {
		"farming": "Farming", "mining": "Miner", "smelting": "Smelter",
		"speed": "Nimble", "glow": "Light", "healing": "Healer",
		"gathering": "Gatherer", "harvest": "Harvester", "glide": "Glider",
		"hauler": "Hauler", "guard": "Guardian", "fishing": "Angler",
		"spore": "Spore",
	}
	return names.get(ability, ability)

func ability_desc(ability: String) -> String:
	var desc := {
		"farming": "Periodically gathers wheat and seeds while at your side.",
		"mining": "Mines stone and ore on its own while you explore caves.",
		"smelting": "Smelts ore into ingots without a furnace.",
		"speed": "Increases your movement speed while at your side.",
		"glow": "Radiates light around your partner.",
		"healing": "Slowly restores your HP.",
		"gathering": "Gathers fiber and amber for you.",
		"harvest": "Harvests mature crops around you.",
		"glide": "Softens your fall when you jump.",
		"hauler": "Extends item pickup range.",
		"guard": "Attacks nearby enemies and boosts defense.",
		"fishing": "Produces water materials and crystals.",
		"spore": "Releases spores that slow enemies.",
	}
	return desc.get(ability, "")

func monster_stats(mon: Dictionary) -> Dictionary:
	var sp: Dictionary = SPECIES.get(mon.get("species", ""), {})
	var lvl: int = int(mon.get("level", 1))
	var lmul := 1.0 + float(lvl - 1) * 0.085
	var v: Dictionary = VARIANTS.get(mon.get("variant", "normal"), VARIANTS["normal"])
	var vm: float = float(v.mult)
	return {
		"hp": int(float(sp.get("hp", 20)) * lmul * vm),
		"atk": int(float(sp.get("atk", 5)) * lmul * vm),
		"def": int(float(sp.get("def", 3)) * lmul * vm),
		"spd": float(sp.get("spd", 3.5)) * (1.0 + (vm - 1.0) * 0.3),
	}

func monster_max_hp(mon: Dictionary) -> int:
	return int(monster_stats(mon).hp)

func new_monster(species_id: String, level: int = 1, variant: String = "normal") -> Dictionary:
	var stats := monster_stats({"species": species_id, "level": level, "variant": variant})
	return {
		"species": species_id, "level": level, "xp": 0, "hp": stats.hp,
		"bond": 0, "variant": variant, "nickname": "", "uid": "%s%d" % [species_id, randi()],
	}

func xp_to_next(level: int) -> int:
	return 24 + level * 18

func catch_chance(species_id: String, level: int, hp_ratio: float, orb_mult: float) -> float:
	var sp: Dictionary = SPECIES.get(species_id, {})
	var base: float = float(sp.get("catch", 0.3))
	var weakened := 1.0 + (1.0 - clampf(hp_ratio, 0.0, 1.0)) * 1.6
	var lvl_pen := clampf(1.0 - maxf(0.0, level - 5) * 0.02, 0.35, 1.0)
	var boss_pen := 0.35 if sp.get("boss", false) else 1.0
	return clampf(base * weakened * lvl_pen * orb_mult * boss_pen, 0.02, 0.95)

func roll_drops(species_id: String) -> Array:
	var out: Array = []
	var sp: Dictionary = SPECIES.get(species_id, {})
	for d in sp.get("drops", []):
		if randf() <= float(d.get("chance", 1.0)):
			out.append({"id": d.id, "n": randi_range(int(d.get("min", 1)), int(d.get("max", 1)))})
	return out

func base_form(species_id: String) -> String:
	var cur := species_id
	var guard := 0
	while guard < 10:
		guard += 1
		var found := ""
		for id in SPECIES:
			if SPECIES[id].get("evolve", "") == cur:
				found = id
				break
		if found == "":
			return cur
		cur = found
	return cur

func evolution_line(species_id: String) -> Array:
	var base := base_form(species_id)
	var line: Array = [base]
	var cur := base
	var guard := 0
	while guard < 10:
		guard += 1
		var nxt: String = SPECIES.get(cur, {}).get("evolve", "")
		if nxt == "":
			break
		line.append(nxt)
		cur = nxt
	return line

func species_for_biome(biome: String, is_night: bool, weather: String) -> Array:
	var out: Array = []
	for id in SPECIES:
		var sp: Dictionary = SPECIES[id]
		if sp.get("boss", false) or not sp.get("wild", true):
			continue
		if not (biome in sp.get("biomes", [])):
			continue
		if sp.get("time", "any") == "night" and not is_night:
			continue
		if sp.get("time", "any") == "day" and is_night:
			continue
		var weight := 1.0
		match int(sp.get("stage", 1)):
			1: weight = 1.0
			2: weight = 0.22
			3: weight = 0.05
		if sp.get("ability", "") == "speed" and weather == "storm":
			weight *= 2.0
		out.append({"id": id, "weight": weight})
	return out

func random_species_for_biome(biome: String, is_night: bool, weather: String) -> String:
	var pool := species_for_biome(biome, is_night, weather)
	if pool.is_empty():
		return "spriggle"
	var total := 0.0
	for p in pool:
		total += p.weight
	var r := randf() * total
	for p in pool:
		r -= p.weight
		if r <= 0.0:
			return p.id
	return pool[0].id

func dungeon_for_biome(biome: String) -> Dictionary:
	match biome:
		"ash":
			return {"id": "ember", "name": "Forge Purba", "boss": "vulcanyx",
				"brick": DUNGEON_BRICK, "accent": Color("#ff8a4c"), "rarity": 0.5}
		"frost":
			return {"id": "frost", "name": "Hollow Peak", "boss": "glacira",
				"brick": DUNGEON_BRICK, "accent": Color("#9adcf0"), "rarity": 0.5}
		_:
			return {"id": "stone", "name": "Kripta Akar", "boss": "warden_stone",
				"brick": DUNGEON_BRICK, "accent": Color("#6fe4d4"), "rarity": 0.5}

func make_quest(village_id: String, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(village_id) + day * 7919
	var t: Dictionary = QUEST_TEMPLATES[rng.randi_range(0, QUEST_TEMPLATES.size() - 1)]
	var q := {"id": "%s_%d" % [village_id, day], "kind": t.kind, "target": "",
		"count": rng.randi_range(t.count[0], t.count[1]), "progress": 0, "done": false,
		"claimed": false, "reward_xp": int(t.xp), "reward_amber": rng.randi_range(t.amber[0], t.amber[1]),
		"giver": village_id}
	match t.kind:
		"gather":
			q.target = t.items[rng.randi_range(0, t.items.size() - 1)]
			q.title = "Supplies for %s" % "the Village"
			q.desc = "Collect %d %s." % [q.count, get_item_name(q.target)]
		"hunt":
			var biome: String = ["meadow", "desert", "frost", "mushroom", "ash"][rng.randi_range(0, 4)]
			var sp: String = random_species_for_biome(biome, rng.randf() < 0.5, "clear")
			q.target = sp
			q.title = "Clear the Path"
			q.desc = "Defeat %d %s." % [q.count, SPECIES[sp].name]
		"capture":
			var biome2: String = ["meadow", "desert", "frost", "mushroom", "ash"][rng.randi_range(0, 4)]
			var sp2: String = random_species_for_biome(biome2, rng.randf() < 0.5, "clear")
			q.target = sp2
			q.title = "A New Friend"
			q.desc = "Capture %d %s." % [q.count, SPECIES[sp2].name]
	return q


# ------------------------------------------------------------------ rare species

func _build_rare_species() -> void:
	_species("prismawing", "Prismawing", "Light", "floater", 3,
		["#f7f0d2", "#9fe8ff", "#ffe9a8", "#2a3550"], {
		"hp": 74, "atk": 20, "def": 11, "spd": 4.6, "catch": 0.07, "scale": 1.15, "rare": true, "wild": true,
		"biomes": ["meadow", "frost"], "ability": "guard", "egg": "plant",
		"skill": "projectile", "power": 24, "srange": 9.0, "cooldown": 8.0,
		"lore": "Its wings split daylight into seven quiet colours. Few wanderers ever see one twice.",
		"drops": [{"id": "crystal", "chance": 0.7}, {"id": "amber", "chance": 0.3}]})
	_species("voidwhisk", "Voidwhisk", "Void", "serpent", 3,
		["#2c2440", "#8a6bd1", "#6fe4d4", "#0e0a16"], {
		"hp": 88, "atk": 24, "def": 9, "spd": 4.4, "catch": 0.06, "scale": 1.2, "rare": true, "wild": true,
		"biomes": ["frost", "ash"], "ability": "guard", "egg": "stone", "aggro": true,
		"skill": "aoe", "power": 26, "srange": 5.0, "cooldown": 11.0,
		"lore": "It swims through the space between shadows and leaves a faint ripple of stars.",
		"drops": [{"id": "monster_core", "chance": 0.5}, {"id": "coal", "chance": 0.4}]})
	_species("cindermane", "Cindermane", "Fire", "biped", 3,
		["#d2603c", "#ffcf6b", "#ff8a4d", "#2a1410"], {
		"hp": 96, "atk": 26, "def": 13, "spd": 4.8, "catch": 0.07, "scale": 1.35, "rare": true, "wild": true,
		"biomes": ["ash"], "ability": "smelting", "egg": "ember", "rideable": true, "aggro": true,
		"skill": "projectile", "power": 28, "srange": 8.0, "cooldown": 8.5,
		"lore": "A mane of living cinders. Villagers say it walks out of wildfires to watch the sunrise.",
		"drops": [{"id": "coal", "chance": 0.9, "min": 2, "max": 3}, {"id": "amber", "chance": 0.35}]})
	_species("glaciermaw", "Glaciermaw", "Frost", "golem", 3,
		["#cfe9f2", "#8fc7de", "#7be0ff", "#1b2b38"], {
		"hp": 120, "atk": 22, "def": 20, "spd": 2.8, "catch": 0.06, "scale": 1.55, "rare": true, "wild": true,
		"biomes": ["frost"], "ability": "guard", "egg": "stone",
		"skill": "aoe", "power": 24, "srange": 4.0, "cooldown": 12.0,
		"lore": "A glacier that learned to breathe. Its footsteps freeze the grass into glass.",
		"drops": [{"id": "crystal", "chance": 0.6}, {"id": "stone", "chance": 1.0, "min": 3, "max": 5}]})
	_species("mycelord", "Mycelord", "Toxic", "golem", 3,
		["#7c6bb0", "#d7c6f0", "#b6ff8a", "#1d1828"], {
		"hp": 104, "atk": 18, "def": 16, "spd": 3.2, "catch": 0.07, "scale": 1.3, "rare": true, "wild": true,
		"biomes": ["mushroom"], "ability": "farming", "egg": "plant",
		"skill": "aoe", "power": 22, "srange": 5.5, "cooldown": 10.0,
		"lore": "An elder mushroom wearing a crown of spores. The whole grove listens when it hums.",
		"drops": [{"id": "fiber", "chance": 0.9, "min": 2, "max": 4}, {"id": "monster_core", "chance": 0.3}]})
	_species("dunestrider", "Dunestrider", "Sand", "quad", 3,
		["#e2c48d", "#f6e5c0", "#ffd166", "#3a2c1e"], {
		"hp": 92, "atk": 21, "def": 12, "spd": 5.0, "catch": 0.07, "scale": 1.28, "rare": true, "wild": true,
		"biomes": ["desert", "meadow"], "ability": "guard", "egg": "stone", "rideable": true,
		"skill": "dash", "power": 20, "srange": 6.0, "cooldown": 7.0,
		"lore": "It crosses dunes without leaving prints, as if the desert forgets it every night.",
		"drops": [{"id": "leather", "chance": 0.6}, {"id": "wheat", "chance": 0.4}]})
	_species("stormcaller", "Stormcaller", "Spark", "floater", 3,
		["#b9d8ff", "#f3f6ff", "#ffe66b", "#22243d"], {
		"hp": 78, "atk": 25, "def": 8, "spd": 5.4, "catch": 0.06, "scale": 1.1, "rare": true, "wild": true,
		"biomes": ["meadow", "ash"], "ability": "mining", "egg": "ember",
		"skill": "projectile", "power": 27, "srange": 10.0, "cooldown": 7.5,
		"lore": "A knot of thunder with eyes. Storms follow it like a loyal dog.",
		"drops": [{"id": "crystal", "chance": 0.5}, {"id": "coal", "chance": 0.5}]})
	_species("thornback", "Thornback", "Nature", "quad", 3,
		["#4c7a4a", "#c7dfa2", "#8affc1", "#16241a"], {
		"hp": 110, "atk": 20, "def": 18, "spd": 3.4, "catch": 0.07, "scale": 1.45, "rare": true, "wild": true,
		"biomes": ["meadow", "mushroom"], "ability": "guard", "egg": "plant",
		"skill": "aoe", "power": 21, "srange": 4.5, "cooldown": 10.5,
		"lore": "Older than the village walls. Its back carries an entire garden of rare blooms.",
		"drops": [{"id": "fiber", "chance": 1.0, "min": 3, "max": 5}, {"id": "berry", "chance": 0.5}]})

func rare_species() -> Array:
	var out: Array = []
	for id in SPECIES:
		var sp: Dictionary = SPECIES[id]
		if bool(sp.get("rare", false)) and bool(sp.get("wild", true)):
			out.append(str(id))
	return out
