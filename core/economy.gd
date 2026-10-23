class_name Economy
extends RefCounted
## Economy formulas shared by the sim and the UI. Ported from state.ts; the
## numbers must stay identical to the original.


static func daily_elec(state: GameState, balance: GameBalance) -> int:
	var total := 0
	for m in state.machines:
		total += GameMath.js_round(m.def.electricity * balance.electricity_rate)
	return total


static func daily_wages(state: GameState) -> int:
	var total := 0
	for s in state.staff:
		total += s.def.wage
	return total


## Rent scales with floor area relative to the starting room.
static func daily_rent(state: GameState, balance: GameBalance) -> int:
	var start_area := balance.start_room.x * balance.start_room.y
	var area := state.room.x * state.room.y
	return GameMath.js_round(balance.base_rent * (float(area) / start_area))


static func base_footfall(state: GameState) -> int:
	var b := 12 + floori(state.rep * 1.1) + state.machines.size() * 2
	if state.has_upgrade(&"neon_signs"):
		b = GameMath.js_round(b * 1.20)
	if state.has_upgrade(&"wifi"):
		b = GameMath.js_round(b * 1.15)
	if state.has_upgrade(&"loyalty_card"):
		b = GameMath.js_round(b * 1.25)
	b = GameMath.js_round(b * audience_mix_mul(state))
	return maxi(2, b)


## Covering more audience segments (kids / teen / adult) draws a bigger crowd:
## all three +15%, two neutral, one -15%. Amenities serve everyone and don't count.
static func audience_mix_mul(state: GameState) -> float:
	var covered := {}
	for m in state.machines:
		var aud := m.def.audience
		if aud in [MachineDef.Audience.KIDS, MachineDef.Audience.TEEN, MachineDef.Audience.ADULT] and m.def.popularity > 0:
			covered[aud] = true
	match covered.size():
		3:
			return 1.15
		1:
			return 0.85
	return 1.0


## Plays fall as price rises above default. 1.0 at default price; revenue
## (ratio x this) peaks around 1.9x default.
static func price_demand_mul(price_ratio: float) -> float:
	return clampf(1.35 - 0.35 * price_ratio, 0.08, 1.35)


## A fresh machine with factory DIPs and, for amenities, a full shelf.
static func make_machine(def: MachineDef, state: GameState, data: GameData) -> MachineInstance:
	var balance := data.balance
	var m := MachineInstance.new()
	m.def = def
	m.id = state.new_instance_id()
	m.price_per_play = def.default_price
	for switch in def.dip_switches:
		m.dips[switch.id] = switch.default_index()
	if def.special == MachineDef.Special.JACKPOT:
		m.jackpot_pot = balance.jackpot_seed_pot
	for item in data.stock_catalog(def.type):
		var slot := StockSlot.new()
		slot.item = item
		slot.price = float(item.ticket_cost) if def.type == MachineDef.Type.PRIZES else item.default_price
		slot.qty = balance.stock_cap
		m.stock.append(slot)
	return m
