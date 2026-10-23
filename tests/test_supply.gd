extends GutTest
## Port of tests/supply.test.ts: shelves deplete, perishables spoil.

const H := preload("res://tests/sim_test_helper.gd")


func _slot(m: MachineInstance, id: StringName) -> StockSlot:
	for slot in m.stock:
		if slot.item.id == id:
			return slot
	return null


func test_vending_depletes_as_it_sells() -> void:
	var s := H.make_state({ cash = 5000.0, rep = 30.0 })
	var m := H.machine(s, &"vending")
	s.machines.append(m)
	var before := _slot(m, &"cola").qty
	H.sim(777).run_day(s)
	assert_lt(_slot(m, &"cola").qty, before)


func test_empty_shelf_stays_empty() -> void:
	var s := H.make_state({ cash = 5000.0, rep = 50.0 })
	var m := H.machine(s, &"vending")
	for slot in m.stock:
		slot.qty = 0.0
	s.machines.append(m)
	H.sim(777).run_day(s)
	assert_true(m.stock.all(func(slot: StockSlot) -> bool: return slot.qty == 0.0))


func test_perishables_spoil_packaged_goods_do_not() -> void:
	var s := H.make_state({ cash = 5000.0, rep = 5.0 })
	var food := H.machine(s, &"food_counter")
	var vend := H.machine(s, &"vending")
	for slot in food.stock + vend.stock:
		slot.price *= 5.0
	s.machines.append_array([food, vend])
	H.sim(777).run_day(s)
	assert_lt(_slot(food, &"burger").qty, 40.0, "fresh food spoiled")
	assert_gt(_slot(vend, &"gum").qty, 38.0, "packaged goods intact")


func test_unlimited_slots_stay_unlimited() -> void:
	var s := H.make_state({ cash = 5000.0, rep = 30.0 })
	var m := H.machine(s, &"vending")
	for slot in m.stock:
		slot.qty = -1.0
	s.machines.append(m)
	H.sim(777).run_day(s)
	assert_true(m.stock.all(func(slot: StockSlot) -> bool: return not slot.is_limited()))
