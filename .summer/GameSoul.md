# Apex Rush

## Vision

This is a high-speed F1 racing game built around precision and momentum. The player sits inches behind a matte black open-wheel car, feeling every kerb clip and every braking zone through a close-trailing third-person camera. Speed readouts, lap splits, and a glowing boost meter fill the periphery while the track demands full attention.

Playing it feels like threading a needle at 300 kilometres per hour. The car responds instantly, grip is absolute, and braking is a weapon rather than a risk. The core fantasy is the clean lap: no mistakes, every apex hit, the boost held just long enough through the straight to gain those final tenths.

## Genre and Style

- **Type**: Arcade racing with simulation presentation. Fast, readable car handling wrapped inside a photoreal visual shell.
- **Inspirations**: The official F1 game series, taken for its authentic circuits, cockpit-adjacent camera angles, and the weight a real race weekend carries.
- **What makes it theirs**: They want the look of a simulation but the feel of an arcade game. Instant response, forgiving grip, and a boost mechanic the official games never offer. That contrast between visual seriousness and playful momentum is the defining choice here.

## Look and Feel

- **Art style**: Photoreal high-fidelity 3D. Physically based materials on carbon fibre, tarmac, and barrier concrete. HDR cinematic lighting shifts between strong directional sunlight and cool night-blue ambient tones. Tight depth of field keeps the car sharp while the world behind blurs into motion. The palette runs from deep asphalt grey through vivid livery colours, with warm gold light at the circuit edges.
- **Mood and sound**: Real engine noise is the heartbeat of every moment. The idle growl builds through the rev range into a high-pitched scream at top speed. Boost adds a layered intake surge and a brief glow wash over the car. Between sessions the atmosphere is tense and quiet, pit lane ambience, tyre sounds, distant crowd noise. No music during racing; the engine carries everything.

## The Hero, the World, the Moment

The car is a matte black F1 machine with a finish that pulls shadow into it. No reflections announce its presence, no bright livery marks its line through a corner. It moves like a rumour and vanishes into every unlit section of tarmac.

The circuit is Monaco: street barriers close enough to touch, steep elevation through the tunnel exit, no room for error anywhere. The harbour district sits at the edge of the track and the sky shifts between golden afternoon and deep blue evening depending on session time.

The defining moment is the chicane sequence. Gaps appear for half a second and the correct line through them is only rewarded by perfect input timing. Boost used here carries risk; the speed gain is real but the margin for error narrows to almost nothing.

## Core Mechanics

The player accelerates, steers, and brakes through timed laps. Acceleration is immediate, cornering grip holds without sliding unless the player drastically overdrives, and braking stops the car in a short, controlled distance. The Overtake Boost meter fills passively over time and depletes while Spacebar is held, raising top speed and adding a visual glow effect. The HUD shows current speed in km/h, a running lap timer, and the boost meter. Winning means posting the fastest lap time or finishing championship rounds in the highest position. Losing is a slower lap, a missed speed target, or a collision penalty added to the timer. _Assumption: barrier collisions cause a brief slow-down penalty rather than a full restart._

## First Playable Version

One lap of the Monaco street circuit in time trial mode. The matte black car, the close trailing camera, real engine audio, and the full HUD are present from the first run. Boost works, the lap timer records splits, and the player can restart immediately. _Assumption: three ghost lap targets give the player something to beat from the start._

## Open Questions

- Should championship mode include rival AI drivers with distinct behaviours, or is position determined by time alone?
- Does the boost meter recharge at a fixed rate or faster when the player takes a clean racing line?
- Are barrier collisions a time penalty, a speed cut, or a full lap restart?
- Which real circuits beyond Monaco are included in the first championship season?

## Board pictures
The concept board's pictures are saved in their assets (My Assets). Look at one when you need the look of the hero, the world or a moment; there is no need to import them all.
- The midnight carbon ghost (hero, asset 1f1ddfd6-de09-42ac-af5c-9f2bbfa6f642): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241646-0_1792301241646_kane2kno.png
- Weave through tight chicanes (moment, asset b324fccd-d4a7-470a-a848-840c72194a3a): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241810-0_1792301241810_sulawagr.png
- Monaco harbour street circuit (world, asset 8679bd42-d92a-46cd-b782-56f4083a0028): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241962-0_1792301241962_lp7rhesx.png
- The titanium speed machine (hero, asset 9040bb7c-819a-4abf-b90d-8a6e832a657a): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301242464-0_1792301242464_jxy1dikn.png
- The scarlet apex predator (hero, asset ebfb5545-b683-40f3-a34f-e20bcc5a74df): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301241/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241433-0_1792301241433_93o157sq.png
- Japanese mountain canyon circuit (world, asset b0948abd-ea26-4000-aa6c-8af1fb286b6d): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241514-0_1792301241514_sk6z0mkn.png
- Desert night racing complex (world, asset 3b15d335-1e90-41cf-9d74-830059c04ce5): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241887-0_1792301241887_e43e8w4i.png
- Hold the racing line on sweeping curves (moment, asset 4b0ec743-c028-465e-832d-4818d78edcf2): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301242036-0_1792301242036_6pqnsujg.png
- Blast past rival cars on straights (moment, asset 61081b18-4842-4fa9-acb7-48f769bce295): https://res.cloudinary.com/dol86wsz1/image/upload/v1792301242/summer_art/img-be8a4fe4-4c8b-4124-a566-10fd4845f6c3-1792301241730-0_1792301241730_hkypjs7l.png
