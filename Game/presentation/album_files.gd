extends RefCounted
const Memories=preload("res://farm/garden_memories.gd")
var directory: String
func _init(farm_directory: String) -> void:
	directory=farm_directory.path_join("album").simplify_path()
func safe(id: String="") -> bool:
	if not directory.is_absolute_path() or (not id.is_empty() and not Memories.valid_id(id)): return false
	var cursor: String=directory
	while cursor!=cursor.get_base_dir():
		var parent:=DirAccess.open(cursor.get_base_dir())
		if parent!=null and parent.is_link(cursor): return false
		cursor=cursor.get_base_dir()
	var folder:=DirAccess.open(directory)
	if folder==null: return not FileAccess.file_exists(directory)
	for suffix: String in [".png","-thumb.png","-pending.png"]:
		if folder.is_link(id+suffix): return false
	return true
func save(image: Image,id: String) -> Error:
	if image==null or image.is_empty() or not safe(id): return ERR_INVALID_DATA
	var error: Error=DirAccess.make_dir_recursive_absolute(directory)
	if error!=OK: return error
	var final: String=directory.path_join(id+".png")
	if FileAccess.file_exists(final): return ERR_ALREADY_EXISTS
	var pending: String=directory.path_join(id+"-pending.png")
	error=image.save_png(pending)
	if error!=OK: return error
	var verified:=Image.new()
	error=verified.load(pending)
	if error!=OK or verified.get_size()!=image.get_size(): return ERR_FILE_CORRUPT
	error=DirAccess.rename_absolute(pending,final)
	if error!=OK: return error
	var width: int=mini(384,verified.get_width())
	verified.resize(width,maxi(1,roundi(width*float(image.get_height())/image.get_width())),Image.INTERPOLATE_LANCZOS)
	return verified.save_png(directory.path_join(id+"-thumb.png"))
func texture(id: String,thumb: bool=false) -> Texture2D:
	if not safe(id): return null
	var path: String=directory.path_join(id+("-thumb.png" if thumb else ".png"))
	if not FileAccess.file_exists(path): return null
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>67108864: return null
	file.close()
	var image:=Image.new()
	if image.load(path)!=OK or image.is_empty(): return null
	return ImageTexture.create_from_image(image)
func open_folder() -> Error:
	if not safe(): return ERR_INVALID_DATA
	var error: Error=DirAccess.make_dir_recursive_absolute(directory)
	return OS.shell_open(directory) if error==OK else error
