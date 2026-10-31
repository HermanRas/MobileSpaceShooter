extends Node
## SFX and music by ID, through `data/audio.json` (PLAN.md 14.1, 14.2). SoundBank (`src/model/`)
## reads the table and decides what may play; this plays it.
##
## - `play_sfx(id)` plays a sound flat (UI, the player's own events); `play_at(id, point)` plays it
##   in the world, panned and fading with distance from the camera. `shot(weapon, point, team)` is
##   a gun firing: `fire.<weapon id>`, quieter from an enemy.
## - `loop(id, parent)` makes a looping player under `parent` for its owner to steer (the
##   engine, a beam); it goes when the parent does.
## - Every Button clicks (`ui.click`, or `ui.back` for one saying Back) without being told to.
## - `play_music(id)` crossfades to a track; each scene Router opens picks its own
##   (`music_for_scene`), and a flight switches to combat music and back.
##
## Calls are always safe: an unknown ID is a no-op, not an error. The Music and SFX buses are at
## the volumes in Settings (6.4). On the Dummy driver (headless tests, the drives' container)
## nothing plays, but `played` still counts what would have, so the drives can check it.

const MUSIC := &"Music"
const SFX := &"SFX"
## Players kept ready, flat and in the world: more than this many sounds at once wait their turn.
const FLAT_VOICES := 12
const WORLD_VOICES := 24

var bank: SoundBank
## Sound ID -> how many times it has started (or would have, on the Dummy driver).
var played := {}
var _silent := false
var _flat: Array[AudioStreamPlayer] = []
var _world: Array[AudioStreamPlayer2D] = []
## Player -> the sound ID it's playing.
var _playing := {}
var _streams := {}
var _music: Array[AudioStreamPlayer] = []
var _music_id := &""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # clicks and music go on under the pause menu
	for bus in [MUSIC, SFX]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
	_apply(&"music_volume")
	_apply(&"sfx_volume")
	Settings.changed.connect(_apply)
	bank = SoundBank.from_table(Data.table(&"audio"))
	_silent = AudioServer.get_driver_name() == "Dummy"
	for message in bank.errors:
		push_warning("audio.json: " + message)
	for i in FLAT_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = SFX
		add_child(player)
		player.finished.connect(_done.bind(player))
		_flat.append(player)
	for i in WORLD_VOICES:
		var player := AudioStreamPlayer2D.new()
		player.bus = SFX
		player.max_distance = bank.max_distance_u * ShipMesh.PX_PER_U
		player.attenuation = bank.attenuation
		add_child(player)
		player.finished.connect(_done.bind(player))
		_world.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = MUSIC
		add_child(player)
		_music.append(player)
	get_tree().node_added.connect(_on_node_added)


## A sound, flat, `db` louder (or quieter) than its row says.
func play_sfx(id: StringName, db := 0.0) -> void:
	_start(id, _free(_flat), db)


## A sound at a world point (pixels), heard from the camera.
func play_at(id: StringName, point: Vector2, db := 0.0) -> void:
	var player := _free(_world) as AudioStreamPlayer2D
	if player != null:
		player.global_position = point
	_start(id, player, db)


## A gun of `weapon_id` firing at `point`, from a ship of `team` (the player's is 0).
func shot(weapon_id: StringName, point: Vector2, team: int) -> void:
	play_at(StringName("fire." + weapon_id), point, 0.0 if team == 0 else bank.enemy_db)


## A looping player for `id` under `parent` (in the world if `spatial`), stopped; or null for an
## unknown ID (or on the Dummy driver). Its owner starts it, steers its volume and pitch, and
## stops it.
func loop(id: StringName, parent: Node, spatial := false) -> Node:
	var entry := bank.entry(id)
	if entry == null:
		return null
	played[id] = int(played.get(id, 0)) + 1
	if _silent:
		return null
	var player: Node
	if spatial:
		var world := AudioStreamPlayer2D.new()
		world.max_distance = bank.max_distance_u * ShipMesh.PX_PER_U
		world.attenuation = bank.attenuation
		world.stream = _stream(entry.files[0], true)
		world.volume_db = entry.db
		world.bus = SFX
		player = world
	else:
		var flat := AudioStreamPlayer.new()
		flat.stream = _stream(entry.files[0], true)
		flat.volume_db = entry.db
		flat.bus = SFX
		player = flat
	player.name = "Loop_" + String(id).replace(".", "_")
	parent.add_child(player)
	return player


## Crossfades to track `id` (&"" for silence); the one already playing carries on.
func play_music(id: StringName) -> void:
	if id == _music_id:
		return
	_music_id = id
	if _fade != null:
		_fade.kill()
	var old := _music[0]
	var new := _music[1]
	_music.reverse()
	var track: Dictionary = bank.music.get(id, {})
	var starts := not track.is_empty() and not _silent
	if not old.playing and not starts:
		return
	_fade = create_tween().set_parallel()
	if old.playing:
		_fade.tween_property(old, ^"volume_db", -60.0, bank.music_fade_s)
		_fade.chain().tween_callback(old.stop)
	if starts:
		new.stream = _stream(track["file"], true)
		new.volume_db = -60.0
		new.play()
		_fade.tween_property(new, ^"volume_db", float(track["db"]), bank.music_fade_s)


## The music for the scene at `scene_path` (Router calls it on every scene change).
func music_for_scene(scene_path: String) -> void:
	play_music(bank.music_for(scene_path))


func music_id() -> StringName:
	return _music_id


func _start(id: StringName, player: Node, db: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if not bank.may_play(id, now):
		return
	played[id] = int(played.get(id, 0)) + 1
	if player == null or _silent:
		return
	var entry := bank.entry(id)
	var file := bank.started(id, now)
	player.set(&"stream", _stream(file, entry.loop))
	player.set(&"volume_db", entry.db + db)
	player.set(&"pitch_scale", bank.pitch_for(id, randf()))
	_playing[player] = id
	player.call(&"play")


func _free(players: Array) -> Node:
	for player: Node in players:
		if not _playing.has(player):
			return player
	return null


func _done(player: Node) -> void:
	if _playing.has(player):
		bank.finished(_playing[player])
		_playing.erase(player)


func _stream(path: String, looped := false) -> AudioStream:
	var key := path + ("#loop" if looped else "")
	if not _streams.has(key):
		var stream := load(path) as AudioStream
		if stream != null and looped:
			stream = stream.duplicate()
			if stream is AudioStreamWAV:
				var wav := stream as AudioStreamWAV
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
		_streams[key] = stream
	return _streams[key]


func _on_node_added(node: Node) -> void:
	var button := node as Button
	if button != null and not button.has_meta(&"clicks"):  # once, though it may re-enter the tree
		button.set_meta(&"clicks", true)
		button.pressed.connect(_click.bind(button))


func _click(button: Button) -> void:
	play_sfx(&"ui.back" if button.text.strip_edges().to_lower() == "back" else &"ui.click")


## A volume setting (0..1) onto its bus; 0 mutes it.
func _apply(key: StringName) -> void:
	var bus := {&"music_volume": MUSIC, &"sfx_volume": SFX}.get(key, &"") as StringName
	if bus == &"":
		return
	var index := AudioServer.get_bus_index(bus)
	var level := clampf(float(Settings.get_value(key)), 0.0, 1.0)
	AudioServer.set_bus_mute(index, level <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.001)))


func _exit_tree() -> void:
	_streams.clear()  # nothing left holding the sounds when the game quits
	for player: Node in _flat + _world + _music:
		player.call(&"stop")
		player.set(&"stream", null)
