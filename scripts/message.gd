extends RichTextLabel

var _tween: Tween

@onready var din = $message 

func display_text(new_text: String, show_time: float = 0.5, wait_time: float = 5.0, hide_time: float = 0.5):
    din.play()
    if _tween:
        _tween.kill()
    _tween = create_tween()
    self.modulate.a = 0
    self.text = new_text
    _tween.tween_property(self, "modulate:a", 1.0, show_time).set_trans(Tween.TRANS_SINE)
    _tween.tween_interval(wait_time)
    _tween.tween_property(self, "modulate:a", 0.0, hide_time).set_trans(Tween.TRANS_SINE)
