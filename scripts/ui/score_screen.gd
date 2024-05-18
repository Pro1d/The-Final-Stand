class_name ScoreScreen
extends Control

signal menu_clicked()

var _score : int

func _ready() -> void:
	(%TemplateNameLabel as Control).visible = false
	(%TemplateScoreLabel as Control).visible = false
	(%BackButton as Button).pressed.connect(menu_clicked.emit)
	visibility_changed.connect(func() -> void:
		if visible:
			_on_show()
	)

func _show_leaderboard_only(lb_only: bool) -> void:
	(%ScorePanelContainer as Control).visible = not lb_only

func set_score(t: int) -> void:
	_score = maxi(t, 1)
	(%ScoreLabel as Label).text = "Your score: %s" % [_score]
	_show_leaderboard_only(t < 0)

func _on_show() -> void:
	if %LeaderboardGridContainer.get_child_count() > 2:
		(%LeaderboardScrollContainer as ScrollContainer).ensure_control_visible(
			%LeaderboardGridContainer.get_child(2) as Control
		)

func update_leaderboard(submit_score: bool) -> void:
	if submit_score:
		await Hyplay.submit_score_leaderboard(
			Config.hyplay["leaderboard-id"] as String,
			Config.hyplay["leaderboard-key"] as String,
			_score
		)

	# reload leaderboard
	var data := await Hyplay.get_leaderboard(Config.hyplay["leaderboard-id"] as String) as Dictionary
	
	var scores: Array[Dictionary] = []
	if data != null and data.has("scores") and data["scores"] is Array:
		scores.assign(data["scores"] as Array)
	
	make_leaderboard(scores)

func make_leaderboard(scores: Array[Dictionary]) -> void: # scores: Optional[Array]
	var container := %LeaderboardGridContainer as Container
	
	# Fill
	var templates : Array[Label] = [
		%TemplateNameLabel as Label,
		%TemplateScoreLabel as Label
	]
	var child_count := container.get_child_count()
	var node_index := 2
	for s in scores:
		var score := int("%s" % [s["score"]])
		for text: String in [s.get("username", "anonymous"), str(score)]:
			var label : Label
			if node_index < child_count: # Re-use existing label if possible
				label = container.get_child(node_index)
			else:
				label = templates[node_index % 2].duplicate()
				label.visible = true
				container.add_child(label)
			label.text = text
			node_index += 1
	
	# not useful in practice because leaderboard should only increase in size
	while container.get_child_count() > node_index:
		container.remove_child(container.get_child(container.get_child_count() - 1))
