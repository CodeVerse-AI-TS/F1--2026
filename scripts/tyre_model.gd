extends RefCounted
## Tyre compounds, wear, temperature and grip for one car.
## wear is 0..1 per wheel (FL, FR, RL, RR); grip_multiplier() turns compound,
## temperature and wear into the fraction of nominal grip the car actually has.
## Past 80% wear the tyre falls off a "cliff" and the car starts to slide.

const SOFT := 0
const MEDIUM := 1
const HARD := 2
const INTER := 3
const WET := 4

## short: HUD badge, name: full label, color: sidewall stripe and HUD colour.
## grip: dry baseline, wear_rate: fraction per second at neutral load,
## wet_grip: grip in full rain, temp_low/temp_high: working window in C.
const COMPOUNDS := [
	{"short": "S", "name": "SOFT", "color": Color(0.95, 0.18, 0.14), "grip": 1.06,
		"wear_rate": 0.00135, "wet_grip": 0.8, "temp_low": 78.0, "temp_high": 108.0},
	{"short": "M", "name": "MEDIUM", "color": Color(0.98, 0.85, 0.2), "grip": 1.0,
		"wear_rate": 0.00092, "wet_grip": 0.86, "temp_low": 76.0, "temp_high": 112.0},
	{"short": "H", "name": "HARD", "color": Color(0.92, 0.93, 0.95), "grip": 0.95,
		"wear_rate": 0.00058, "wet_grip": 0.9, "temp_low": 74.0, "temp_high": 116.0},
	{"short": "I", "name": "INTERMEDIATE", "color": Color(0.25, 0.85, 0.35), "grip": 0.9,
		"wear_rate": 0.0012, "wet_grip": 1.02, "temp_low": 60.0, "temp_high": 90.0},
	{"short": "W", "name": "WET", "color": Color(0.25, 0.55, 0.95), "grip": 0.84,
		"wear_rate": 0.0011, "wet_grip": 1.06, "temp_low": 50.0, "temp_high": 78.0},
]

var compound := MEDIUM
var wear := 0.0                                  # average of the four wheels
var wheels: Array[float] = [0.0, 0.0, 0.0, 0.0]  # FL, FR, RL, RR
var temp := 70.0

func info() -> Dictionary:
	return COMPOUNDS[compound]

func reset(c := -1) -> void:
	if c >= 0:
		compound = clampi(c, 0, COMPOUNDS.size() - 1)
	wear = 0.0
	wheels = [0.0, 0.0, 0.0, 0.0]
	temp = 70.0

func short() -> String:
	return String(info()["short"])

func name() -> String:
	return String(info()["name"])

func colour() -> Color:
	return info()["color"]

func wear_pct() -> int:
	return clampi(int(round(wear * 100.0)), 0, 100)

## 0 = cold, 1 = in the window, 2 = overheating (drives the HUD temperature colour).
func temp_state() -> int:
	var d := info()
	if temp < float(d["temp_low"]):
		return 0
	if temp > float(d["temp_high"]):
		return 2
	return 1

## One physics step. All inputs are 0..1 except wetness (0 dry .. 1 heavy rain).
func update(delta: float, corner: float, brake: float, throttle: float,
		speed_frac: float, boost: float, kerb: float, wetness: float) -> void:
	var d := info()
	# fronts take the braking load, rears take the traction load
	var front_load := 1.0 + 1.15 * corner + 0.85 * brake + 0.25 * throttle
	var rear_load := 1.0 + 1.05 * corner + 0.3 * brake + 0.85 * throttle * (1.0 - speed_frac)
	var dry_mismatch := 1.0 + wetness * 1.6 if compound <= HARD else 1.0
	var hot := 1.45 if temp > float(d["temp_high"]) else 1.0
	var base: float = float(d["wear_rate"]) * dry_mismatch * hot * (1.0 + 0.35 * boost + 0.3 * kerb)
	wheels[0] = clampf(wheels[0] + base * front_load * delta, 0.0, 1.0)
	wheels[1] = clampf(wheels[1] + base * front_load * delta, 0.0, 1.0)
	wheels[2] = clampf(wheels[2] + base * rear_load * delta, 0.0, 1.0)
	wheels[3] = clampf(wheels[3] + base * rear_load * delta, 0.0, 1.0)
	wear = (wheels[0] + wheels[1] + wheels[2] + wheels[3]) * 0.25
	# temperature: cornering and braking heat the tyre, air speed and rain cool it
	var work := 0.45 * corner + 0.4 * brake + 0.15 * throttle
	var target := 55.0 + 62.0 * work + 12.0 * speed_frac - 24.0 * wetness
	var rate := 0.9 if target > temp else (0.5 + 0.8 * speed_frac)
	temp = move_toward(temp, clampf(target, 20.0, 160.0), rate * 26.0 * delta)

func temperature_grip() -> float:
	var d := info()
	var lo := float(d["temp_low"])
	var hi := float(d["temp_high"])
	if temp < lo:  # cold tyres: graining, less grip
		return lerpf(0.8, 1.0, clampf((temp - 30.0) / maxf(lo - 30.0, 1.0), 0.0, 1.0))
	if temp > hi:  # overheating: the surface goes off
		return lerpf(1.0, 0.76, clampf((temp - hi) / 26.0, 0.0, 1.0))
	return 1.0

## Fraction of nominal grip available right now (0.18 broken .. 1.15 fresh, warm, dry).
func grip_multiplier(wetness := 0.0) -> float:
	var d := info()
	var base: float = float(d["grip"])
	var w := clampf(wetness, 0.0, 1.0)
	if compound <= HARD:
		base *= lerpf(1.0, 0.42, w)          # dry rubber on a wet track
	else:
		base *= lerpf(0.88, float(d["wet_grip"]), w)
	var worn := 1.0 - 0.18 * wear
	if wear > 0.8:
		worn -= 0.55 * ((wear - 0.8) / 0.2)  # the cliff
	return clampf(base * worn * temperature_grip(), 0.18, 1.15)
