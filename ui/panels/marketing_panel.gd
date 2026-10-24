extends VBoxContainer
## The rival, ad campaigns, the happy-hour discount and tournaments.

var title := "MARKETING"
var ui: GameUI


func refresh() -> void:
	UiKit.clear(self)
	var s := Game.state
	var b := Data.db.balance
	_rival(s, b)

	add_child(UiKit.section("AD CAMPAIGNS"))
	var running := s.campaign and s.campaign.days_left > 0
	if running:
		var c := s.campaign.def
		add_child(UiKit.label("Running %s %s — +%d%% footfall, %d day(s) left." % [c.emoji, c.display_name, _pct(c.foot_mul), s.campaign.days_left], &"", true))
	else:
		add_child(UiKit.label("No campaign running. Launch one to draw a bigger crowd — best timed before the weekend.", &"DimLabel", true))
	for c in Data.db.campaigns:
		add_child(UiKit.card(c.emoji, "%s  +%d%% · %dd" % [c.display_name, _pct(c.foot_mul), c.days], c.blurb,
			UiKit.button(GameMath.money(c.cost), _do.bind(Game.actions.start_campaign.bind(s, c)), &"", not running and s.cash >= c.cost)))

	add_child(UiKit.section("PROMOTION"))
	add_child(UiKit.card("🏷️", "Happy Hour" + ("  • ON" if s.discount_on else ""),
		"+%d%% footfall, −%d%% takings. Toggle anytime." % [_pct(b.discount_foot_mul), GameMath.js_round((1.0 - b.discount_earn_mul) * 100.0)],
		UiKit.button("STOP" if s.discount_on else "START", func() -> void:
			Game.actions.toggle_discount(Game.state)
			Sfx.click()
			EventBus.state_changed.emit())))

	add_child(UiKit.section("🏆 TOURNAMENTS"))
	if s.tournament:
		var t := s.tournament.def
		add_child(UiKit.label("Booked %s %s — happens in %d day(s). Your rep %d / %d needed." % [t.emoji, t.display_name, s.tournament.days_until, GameMath.js_round(s.rep), t.rep_req], &"", true))
		return
	for t in Data.db.tournaments:
		add_child(UiKit.card(t.emoji, "%s  rep %d+" % [t.display_name, t.rep_req], "%s +%d%% crowd · ~%d entrants · in %dd" % [t.blurb, _pct(t.foot_mul), t.entrants, t.lead_days],
			UiKit.button(GameMath.money(t.cost), _do.bind(Game.actions.schedule_tournament.bind(s, t)), &"", s.cash >= t.cost)))


func _rival(s: GameState, b: GameBalance) -> void:
	if s.rival == null:
		add_child(UiKit.label("No rival yet — one tends to open across town once you're established (day %d+)." % b.rival_appear_day, &"DimLabel", true))
		return
	var me := Game.day_cycle.player_strength(s)
	var them := GameMath.js_round(s.rival.strength)
	var lead := me - them
	var foot := _pct(GameData.rival_foot_mul(me, them))
	add_child(UiKit.section("🆚 RIVAL: %s" % s.rival.display_name))
	var strength := UiKit.bar(me, me + them, Color("4fd8ff"))
	strength.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(UiKit.hbox([UiKit.label("You %d" % me), strength, UiKit.label("%d them" % them)]))
	add_child(UiKit.label("Leading by %d — +%d%% footfall" % [lead, foot] if lead >= 0 else "Behind by %d — %d%% footfall" % [-lead, foot], &"DimLabel", true))
	add_child(UiKit.button("💢 PRICE WAR (−%d rival, %s)" % [b.undercut_hit, GameMath.money(b.undercut_cost)], _do.bind(Game.actions.undercut_rival.bind(s)), &"DangerButton", s.cash >= b.undercut_cost))


static func _pct(mul: float) -> int:
	return GameMath.js_round((mul - 1.0) * 100.0)


func _do(action: Callable) -> void:
	if action.call():
		EventBus.state_changed.emit()
