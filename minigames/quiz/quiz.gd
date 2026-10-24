extends MiniGame
## Quiz King: five timed multiple-choice questions from a retro-arcade bank.
## Faster answers score more and a streak adds a bonus. The original put the
## answer buttons under its canvas; here they're tappable boxes on the board.

## [question, four options, index of the right one]
const BANK := [
	["Which 1972 game was the first big arcade hit?", ["Pong", "Asteroids", "Pac-Man", "Frogger"], 0],
	["What year did Pac-Man first appear?", ["1976", "1980", "1984", "1988"], 1],
	["Who climbs the scaffolding in Donkey Kong?", ["Luigi", "Sonic", "Jumpman", "Q*bert"], 2],
	["Space Invaders (1978) was made in which country?", ["USA", "Japan", "France", "UK"], 1],
	["Which company founded by Nolan Bushnell made Pong?", ["Sega", "Namco", "Taito", "Atari"], 3],
	["What do you smash in Breakout?", ["Bricks", "Barrels", "Ghosts", "Asteroids"], 0],
	["Pac-Man dodges how many ghosts?", ["2", "3", "4", "5"], 2],
	["Which ghost is NOT in Pac-Man?", ["Blinky", "Pinky", "Clyde", "Sparky"], 3],
	["Galaga (1981) was made by…", ["Namco", "Capcom", "Konami", "Midway"], 0],
	["Street Fighter II launched in…", ["1987", "1989", "1991", "1994"], 2],
	["Dance Dance Revolution is a … game.", ["racing", "rhythm", "fighting", "puzzle"], 1],
	["DDR was created by…", ["Sega", "Nintendo", "Konami", "Atari"], 2],
	["How many letters in a classic high-score name?", ["2", "3", "4", "5"], 1],
	["In Space Invaders, fewer aliens means they get…", ["slower", "bigger", "faster", "friendlier"], 2],
	["Tetris was created in…", ["the USSR", "Japan", "the USA", "Germany"], 0],
	["Asteroids (1979) used what display style?", ["raster", "vector", "LCD", "LED"], 1],
	["Frogger's goal: get the frog…", ["home", "fed", "famous", "fast"], 0],
	["Which game stars a yellow dot-muncher?", ["Q*bert", "Pac-Man", "Dig Dug", "Pengo"], 1],
	["Out Run (1986) was made by…", ["Sega", "Namco", "Taito", "SNK"], 0],
	["What does a pinball TILT do?", ["adds a ball", "doubles the score", "kills your flippers", "opens a ramp"], 2],
	["A slot machine's nickname: the one-armed…", ["wonder", "bandit", "king", "goblin"], 1],
	["Mortal Kombat (1992) came from…", ["Capcom", "Konami", "Midway", "Namco"], 2],
	["The Konami Code starts…", ["↓↓↑↑", "↑↑↓↓", "←→←→", "BABA"], 1],
	["Pole Position (1982) is a … game.", ["racing", "maze", "shooter", "sports"], 0],
	["Skee-ball: roll the ball into…", ["pockets", "rings", "cups", "lanes"], 1],
	["Pac-Man's designer was inspired by a…", ["pizza", "donut", "moon", "cookie"], 0],
	["Centipede (1981) was co-created by…", ["Dona Bailey", "Roberta Williams", "Carol Shaw", "Ada Lovelace"], 0],
	["Which is a light-gun series?", ["Time Crisis", "Tekken", "Gradius", "Puyo Puyo"], 0],
	["Air hockey pucks float on…", ["magnets", "water", "air", "ice"], 2],
	["Arcade golden age peaked in the early…", ["1970s", "1980s", "1990s", "2000s"], 1],
	["The message before you pay:", ["GAME ON", "PLAY NOW", "INSERT COIN", "PRESS FIRE"], 2],
	["Whack-A-Mole debuted in the…", ["1950s", "1960s", "1970s", "1990s"], 2],
	["Gauntlet (1985) warned: \"… needs food badly.\"", ["Wizard", "Valkyrie", "Elf", "Any hero"], 3],
	["Q*bert hops on a pyramid of…", ["cubes", "spheres", "stairs", "cones"], 0],
	["Dig Dug defeats enemies by…", ["jumping", "inflating them", "shooting lasers", "freezing them"], 1],
	["Defender (1981) was made by…", ["Williams", "Atari", "Nintendo", "Sega"], 0],
]
const QUESTIONS := 5
const Q_TIME := 6 * 60
const LOCK := 55
const BUTTON := Vector2(160, 62)
const BUTTONS_TOP := 236.0
const RIGHT := Color("06d6a0")
const WRONG := Color("b3324f")

var questions: Array = []
var index := 0
var streak := 0
var correct := 0
var verdict := ""
var verdict_good := true
var _timer := Q_TIME
var _lock := 0
## Answer index → highlight colour once the question is settled.
var _marks := {}


func _setup() -> void:
	questions = BANK.duplicate()
	questions.shuffle()
	questions.resize(QUESTIONS)


func _button_rect(i: int) -> Rect2:
	return Rect2(BOARD.x / 2 - BUTTON.x - 4 + (i % 2) * (BUTTON.x + 8), BUTTONS_TOP + floori(i / 2.0) * (BUTTON.y + 8), BUTTON.x, BUTTON.y)


func _pointer_pressed(at: Vector2) -> void:
	if _lock > 0 or index >= QUESTIONS:
		return
	for i in 4:
		if _button_rect(i).has_point(at):
			_pick(i)
			return


func _pick(i: int) -> void:
	var answer: int = questions[index][2]
	if i == answer:
		streak += 1
		correct += 1
		var points := 20 + GameMath.js_round(30.0 * _timer / Q_TIME)
		if streak >= 3:
			points += 10
		score += points
		_settle("+%d" % points, true)
	else:
		streak = 0
		_settle("WRONG", false)
		_marks[i] = WRONG
	_marks[answer] = RIGHT


func _settle(label: String, good: bool) -> void:
	verdict = label
	verdict_good = good
	_lock = LOCK


func _tick() -> void:
	if _lock > 0:
		_lock -= 1
		if _lock == 0:
			index += 1
			if index >= QUESTIONS:
				end_round("QUIZ KING!" if correct >= 4 else "%d / %d RIGHT" % [correct, QUESTIONS], correct >= 3)
				return
			_timer = Q_TIME
			verdict = ""
			_marks.clear()
		return
	_timer -= 1
	if _timer <= 0:
		streak = 0
		_settle("TOO SLOW", false)
		_marks[questions[index][2]] = RIGHT


## Splits text into lines no wider than `width` at the given size.
func _wrap(value: String, width: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in value.split(" "):
		var attempt := word if line.is_empty() else line + " " + word
		if not line.is_empty() and PIXEL_FONT.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = word
		else:
			line = attempt
	if not line.is_empty():
		lines.append(line)
	return lines


func _draw_board() -> void:
	text("QUESTION %d / %d" % [mini(index + 1, QUESTIONS), QUESTIONS], Vector2(BOARD.x / 2, 50), 11, DIM)
	if index >= QUESTIONS:
		return
	var q: Array = questions[index]
	var lines := _wrap(q[0], BOARD.x - 40, 15)
	for i in lines.size():
		text(lines[i], Vector2(BOARD.x / 2, 100 + i * 26), 15, CREAM)
	# Time left on this question.
	var left := maxf(0, _timer) / Q_TIME
	board.draw_rect(Rect2(40, 200, BOARD.x - 80, 14), Color("241a0e"))
	board.draw_rect(Rect2(40, 200, (BOARD.x - 80) * left, 14), RIGHT if left > 0.4 else GOLD if left > 0.2 else Color("ff006e"))
	# The four answers.
	for i in 4:
		var rect := _button_rect(i)
		board.draw_rect(rect, _marks.get(i, Color("2b364d")))
		board.draw_rect(rect, Color("86857f"), false, 1.0)
		var words := _wrap(q[1][i], rect.size.x - 12, 13)
		var top := rect.get_center().y - (words.size() - 1) * 9.0 + 5
		for w in words.size():
			text(words[w], Vector2(rect.get_center().x, top + w * 18), 13, CREAM)
	if verdict:
		text(verdict, Vector2(BOARD.x / 2, 418), 14, RIGHT if verdict_good else Color("ff006e"))


func _hud_text() -> String:
	return "SCORE %d    STREAK %d" % [score, streak]
