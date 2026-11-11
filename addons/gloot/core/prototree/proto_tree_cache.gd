@tool

static var _cache: Dictionary = {}
static var _empty: ProtoTree = ProtoTree.new()


static func get_cached(key: JSON) -> ProtoTree:
    if Engine.is_editor_hint():
        var result := ProtoTree.new()
        result.deserialize(key)
        return result

    if _cache.has(key):
        return _cache[key]
    else:
        var tree := Engine.get_main_loop() as SceneTree
        if tree != null and not tree.root.tree_exiting.is_connected(_clear_cache):
            tree.root.tree_exiting.connect(_clear_cache, CONNECT_ONE_SHOT)
        _cache[key] = ProtoTree.new()
        _cache[key].deserialize(key)
        return _cache[key]


static func get_empty() -> ProtoTree:
    return _empty


static func _clear_cache() -> void:
    # Release cached trees while the scripting VM can still run their cleanup.
    _cache.clear()
