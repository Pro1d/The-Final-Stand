class_name Menu
extends Control

signal play_clicked
signal ranking_clicked

func _ready() -> void:
	(%PlayButton as Button).pressed.connect(play_clicked.emit)
	(%RankingButton as Button).pressed.connect(ranking_clicked.emit)
