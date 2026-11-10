class_name Story
extends RefCounted
## Hand-authored narrative content: one main arc ("The Hollow Heart") plus side quests.
## Quest runtime state lives in Game.story; this file is data plus small helpers.

static var _cache: Dictionary = {}

static func all() -> Array:
	if not _cache.has("all"):
		_cache["all"] = _build()
	return _cache["all"]

static func by_id(id: String) -> Dictionary:
	for q in all():
		if str(q.id) == id:
			return q
	return {}

static func of_kind(kind: String) -> Array:
	var out: Array = []
	for q in all():
		if str(q.kind) == kind:
			out.append(q)
	return out

static func _q(id: String, kind: String, act: int, title: String, giver: String,
		story: String, steps: Array, xp: int, amber: int, marker: String,
		reward_item: String = "", reward_n: int = 0) -> Dictionary:
	return {"id": id, "kind": kind, "act": act, "title": title, "giver": giver,
		"story": story, "steps": steps,
		"reward": {"xp": xp, "amber": amber, "item": reward_item, "n": reward_n},
		"marker": marker}

static func _s(text: String, type: String, target: String, goal: int) -> Dictionary:
	return {"text": text, "type": type, "target": target, "goal": goal}

static func _build() -> Array:
	return [
		_q("main_1", "main", 1, "The Waking Vale", "Elder Rowan",
			"Something stirs beneath the valley. The Hollow Heart - the old rift the first settlers sealed - is bleeding again, and the wild ones are restless. Rowan asks you to cut timber for a ward totem, then hear what the village remembers.",
			[_s("Gather 8 Logs", "item", "log", 8),
				_s("Speak with a village Elder", "flag", "met_elder", 1)],
			80, 25, "village"),
		_q("main_2", "main", 1, "A Bond in the Wild", "Elder Rowan",
			"The old ward only answers to those the vale trusts. Weaken a wild creature and capture it with an orb, then gather fiber to bind the charm. A bonded companion is the first key to the Heart.",
			[_s("Capture 1 wild monster", "capture", "", 1),
				_s("Gather 6 Fiber", "item", "fiber", 6)],
			120, 40, "village"),
		_q("main_3", "main", 2, "Beneath the Roots", "Elder Rowan",
			"The first rift shard fell into a dungeon below the roots. Break the guardian that hoards it, and bring back stone to brace the collapsing tunnels.",
			[_s("Defeat a dungeon boss", "boss", "", 1),
				_s("Mine 20 Stone", "item", "stone", 20)],
			200, 70, "dungeon"),
		_q("main_4", "main", 2, "Shards of the Rift", "Elder Rowan",
			"The shard hums in time with the rift. Monsters pour through in waves - hold the line, then thin the wild packs so the vale can breathe again.",
			[_s("Clear 3 Rift waves", "rift", "", 3),
				_s("Defeat 5 wild monsters", "hunt", "", 5)],
			320, 110, "dungeon"),
		_q("main_5", "main", 3, "Heart of the Vale", "Elder Rowan",
			"Two guardians still anchor the Heart, and the vale's spirits have begun to gather. Break the guardians, learn every creature the valley holds, and Rowan believes the Heart can finally be sealed - not destroyed.",
			[_s("Defeat 2 dungeon bosses", "boss", "", 2),
				_s("Register 12 species in the Codex", "codex", "", 12)],
			600, 200, "dungeon", "rift_key", 1),

		_q("side_timber", "side", 1, "Timber for the Ward", "Farmer Tessa",
			"Tessa is rebuilding the palisade after the last monster surge. She pays well for straight, dry logs.",
			[_s("Gather 15 Logs", "item", "log", 15)], 70, 20, "village"),
		_q("side_stone", "side", 1, "Stone and Sinew", "Mason Orin",
			"Orin needs stone to shore up the mine shaft. Deep stone, not the crumbly surface kind.",
			[_s("Mine 30 Stone", "item", "stone", 30)], 90, 25, "dungeon"),
		_q("side_bond", "side", 1, "A Wilder Friend", "Beastkeeper Nia",
			"Nia swears every creature can be a friend if you are patient. Prove it twice.",
			[_s("Capture 2 wild monsters", "capture", "", 2)], 120, 35, "village"),
		_q("side_codex", "side", 1, "Scholar of the Vale", "Sage Lyra",
			"Lyra is writing the first natural history of the valley. She needs ten species recorded.",
			[_s("Register 10 species in the Codex", "codex", "", 10)], 140, 40, "village"),
		_q("side_hunt", "side", 1, "Hunter's Due", "Hunter Bram",
			"The pack near the old ruin is thinning the herds. Bram wants it thinned back.",
			[_s("Defeat 8 wild monsters", "hunt", "", 8)], 150, 45, "dungeon"),
		_q("side_harvest", "side", 1, "Golden Harvest", "Farmer Tessa",
			"Tessa's ovens are cold. Six bundles of wheat and the whole village eats tonight.",
			[_s("Harvest 6 Wheat", "item", "wheat", 6)], 100, 30, "village"),
		_q("side_explore", "side", 1, "Paths of the Vale", "Elder Rowan",
			"Rowan wants the old roads mapped again. Walk into three villages and mark them on your map.",
			[_s("Discover 3 villages", "village", "", 3)], 110, 35, "village"),
	]
