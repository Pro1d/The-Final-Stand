extends Node
# normally I'd use a static class for global API stuff like this, but since I need to use node apis, it's an autoload
# (see request() for more detail)

const token_path := "user://token.txt"

var app_id := ""
var app_details: Variant = null

var auth := ""
var app_auth := ""
var session_auth := ""
var user_details: Variant = null

var is_logged_in: bool:
	get: return user_details != null

var is_initialised := false
var initialise_called := false

var initialisation_failed: bool:
	get: return is_initialised && app_details == null

signal initialised

# call this as early as possible
func initialise(_app_id: String) -> void:
	if initialise_called :
		print("Hyplay can only be initialised once")
		return
	initialise_called = true

	print("Hyplay initialising..")

	app_id = _app_id

	await get_app_details()

	if app_details != null :
		if OS.has_feature("web") :
			var url_frag: String = JavaScriptBridge.eval("window.location.hash")

			if url_frag.begins_with("#token=") :
				session_auth = url_frag.substr("#token=".length())
				JavaScriptBridge.eval("window.location.hash = \"\"")

		if session_auth == "" :
			read_auth()

		if session_auth != "":
			await get_user_details()

	is_initialised = true
	initialised.emit()
	print("Hyplay initialisation " + ("success" if !initialisation_failed else "failed"))


#region top-level APIs

func submit_score_leaderboard(id: String, secret: String, score: int):
	if app_id == "" :
		print("Hyplay: Can't submit to leaderboard without an app ID")
		return
	if id == "" :
		print("Hyplay: Can't submit to leaderboard without a leaderboard ID")
		return
	if user_details == null :
		print("Hyplay: Can't submit to leaderboard without user details")
		return

	# this rounds it to 3dp, but isn't a perfect solution in the case of float imprecision
	#score = snappedf(score, 0.001)

	# this bit at the end ensures the float is stringified to 3dp, and then removes unecessary 0's and . if there are no decimal places
	var to_hash = secret + ":" + user_details.id + ":" + str(score) #("%.3f" % score).rstrip("0").rstrip(".")

	return await rest_api("apps/%s/leaderboards/%s/scores" % [app_id, id], HTTPClient.METHOD_POST, {"score": score, "hash": to_hash.sha256_text()})

func get_leaderboard(id: String):
	if app_id == "" :
		print("Hyplay: Can't get leaderboard without an app ID")
		return null
	if id == "" :
		print("Hyplay: Can't get leaderboard without a leaderboard ID")
		return null
	
	return await rest_api("apps/%s/leaderboards/%s/scores" % [app_id, id]) #, HTTPClient.METHOD_GET, "", {"limit": limit})

func logout():
	user_details = null
	erase_auth()

func real_login():
	if app_id == "" :
		print("Hyplay: Can't login without an app ID")
		return

	if OS.has_feature("web") :
		JavaScriptBridge.eval("""window.top.location = "https://hyplay.com/oauth/authorize/?appId=%s&chain=HYCHAIN&responseType=token&redirectUri=" + window.location.href""" % app_id)
	else :
		# could potentially open a web browser here
		# not sure how you'd pass the auth code back to the game from there though
		print("Hyplay: Unable to do real login outside web")

func guest_login():
	if app_id == "" :
		print("Hyplay: Can't login without an app ID")
		return null

	var json = await rest_api("sessions", HTTPClient.METHOD_POST, {"chain": "HYCHAIN", "isGuest": "true", "responseType": "token", "appId": app_id,
		"deadline": Time.get_unix_time_from_system() + 3600 * 24 * 2,
		"nonce": str(randi())})

	if json != null :
		session_auth = json.accessToken

func get_user_details():
	if session_auth == "" :
		print("Hyplay: Can't get user details unless user is logged in")
		return null
	
	user_details = await rest_api("users/me")
	
	# save token if it works, else erase token
	if user_details != null : save_auth()
	else : erase_auth()

	return user_details

func get_background_image() -> Image:
	if app_details == null :
		print("Hyplay: Need to be initialised to get images")
		return

	var asset_details = app_details.backgroundImageAsset
	
	return await load_image(asset_details.cdnUrl, asset_details.extension)
	
func get_icon_image() -> Image:
	if app_details == null :
		print("Hyplay: Need to be initialised to get images")
		return

	var asset_details = app_details.iconImageAsset
	
	return await load_image(asset_details.cdnUrl, asset_details.extension)

func get_app_details():
	if app_id == "" :
		print("Hyplay: Can't get app details without an app ID")
		return null
	
	app_details = await rest_api("apps/" + app_id)
	return app_details

#endregion


#region underlying APIs

func rest_api(path: String, method := HTTPClient.METHOD_GET, body: Variant = "") -> Variant:
	var headers = ["content-type: application/json"]
	if auth != "" : headers.append("x-authorization: "+auth)
	if app_auth != "" : headers.append("x-app-authorization: "+app_auth)
	if session_auth != "" : headers.append("x-session-authorization: "+session_auth)
	
	if body is not String : body = JSON.stringify(body)

	var res := await request("https://api.hyplay.com/v1".path_join(path), method, body, headers, 15.0)

	# we can reasonably assume the API will always respond with JSON and UTF8
	var json = JSON.parse_string(res.body.get_string_from_utf8())

	if res.result_code == 0 :
		if res.http_code >= 200 && res.http_code <= 299 :
			print("Hyplay API `", path,"` success")
			return json
		else :
			print("Hyplay API `", path, "` failure; Response Error. Result code: ", res.result_code, " HTTP code: ", res.http_code, " Headers: ", res.headers)
			print_json(json)
			return null
	else :
		print("Hyplay API `", path, "` failure; Request Error. Result code: ", res.result_code, " HTTP code: ", res.http_code, " Headers: ", res.headers)
		print(json)
		return null

func load_image(url: String, ext: String) -> Image:
	var res := await request(url)

	var rtn := Image.new()

	if res.result_code == 0 && res.http_code >= 200 && res.http_code <= 299 :
		match ext.to_lower() :
			"png": rtn.load_png_from_buffer(res.body)
			"svg": rtn.load_svg_from_buffer(res.body)
			"tga": rtn.load_tga_from_buffer(res.body)
			"webp": rtn.load_webp_from_buffer(res.body)
			"jpg", "jpeg": rtn.load_jpg_from_buffer(res.body)

	return rtn

func request(url: String, method := HTTPClient.METHOD_GET, body: String = "", headers := [], timeout := 0.0) -> Dictionary:
	# to do HTTP requests you need to make a HTTPClient instance and poll it every frame, which means you need node apis
	# the HTTPRequest class is a node that does this for us, and this Hyplay class needs to be a node to hold HTTPRequest children

	# each HTTPRequest can only handle one request at once, so the easiest thing is to have 1 node = 1 request and free them when done
	# if performance is a big concern, it would be more efficient to just keep one or two around but that's more annoying to code,
	# since if they're all busy you'd have to wait until one was available to do the next request
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	
	req.request(url, headers, method, body)
	
	# godot will complain if the number of args don't match 🙄 hence the callback with 4 unused args
	req.request_completed.connect(func(_1, _2, _3, _4): req.queue_free(), CONNECT_ONE_SHOT)

	# res is the response; it will match the parameters of request_completed, just put into an array
	var res: Array = await req.request_completed

	return {
		"result_code": res[0] as HTTPRequest.Result, # Godot-specific enum
		"http_code": res[1] as HTTPClient.ResponseCode, # standard HTTP response codes
		"headers": res[2] as PackedStringArray,
		"body": res[3] as PackedByteArray
	}

func read_auth():
	if FileAccess.file_exists(token_path) :
		session_auth = FileAccess.get_file_as_string(token_path)

func save_auth():
	FileAccess.open(token_path, FileAccess.WRITE).store_string(session_auth)

func erase_auth():
	session_auth = ""
	save_auth()

func print_json(json: Variant):
	print(JSON.stringify(json, "\t"))

#endregion
