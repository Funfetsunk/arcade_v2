extends Node
## Autoload "EventBus": game-wide signals the view layer listens to.
## The systems' own signals are relayed through here by the Game autoload.
@warning_ignore_start("unused_signal")

signal logged(message: String, kind: Sim.LogKind)
signal toast_requested(message: String, kind: Sim.LogKind)
## Sound cues relayed from the systems (see GameSystem).
signal purchased
signal refused
signal celebrated

## The state changed in a way the HUD and panels should redraw for.
signal state_changed
signal game_started
signal game_loaded
signal day_ended

## The floor's crowd resets at the start of each day.
signal customers_reset
signal coin_spawned(machine_id: int, value: int)
signal repair_worker_spawned(machine_id: int, is_senior: bool)
signal machine_broke
## A VIP left a tip on the way out (floor position, amount).
signal tip_received(position: Vector2, amount: int)
## The player tapped a machine on the floor (-1 = tapped empty floor).
signal machine_selected(machine_id: int)
## The player tapped a visitor (null = tapped something else).
signal visitor_selected(visitor: Node2D)
signal jackpot_hit(machine_id: int, amount: int)
## A machine was bought, sold or moved: recompute zones and walking paths.
signal machines_changed
signal staff_changed

## A pre-day choice the player must answer via Game.choose_decision().
signal decision_offered(event: DecisionEventDef)
signal goal_completed(goal: GoalDef)
## Every goal done: offer prestige.
signal empire_completed
signal achievement_unlocked(achievement: AchievementDef)
signal scenario_won(scenario: ScenarioDef, stars: int)
signal daily_finished(score: int, best: int, new_best: bool)
signal contract_resolved(contract: ContractDef, delivered: bool)
signal tournament_resolved(tournament: TournamentDef, success: bool)
