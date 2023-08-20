globals[
  time
  ;; output
  pass-car
  average-speed
  average-wait
  average-drive

  last-decision
  wait-time-list
  drive-time-list
  average-speed-list
]

breed [lights light]
lights-own[
  name
  state
  direction
]

breed [cars car]
cars-own[
  speed
  tips ;; each car will give reward to signal before it die
  wait-time
  drive-time
  speed-list
]

breed [gamers gamer]
gamers-own[
  reward-list
  state
]


to setup
  clear-all
  set time 0
  set wait-time-list []
  set drive-time-list []

  ;; set shape
  set-default-shape lights "circle"
  set-default-shape cars "car"
  set-default-shape gamers "person"

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;; Environment Setting ;;;;;;;;;;;;;;;;;;;;;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ;; Create the road
  ask patches[
    ifelse abs pxcor <= 1 or abs pycor <= 1
    [set pcolor black]
    [set pcolor green]

    if abs pxcor = 0 or abs pycor = 0 [set pcolor grey]
    if abs pxcor <= 1 and abs pycor <= 1 [set pcolor black]
  ]

  ;; Create lights
  ask patch 2 -1 [sprout-lights 1 [ set color green set state green set name "E2W" set direction "EW"] ]
  ask patch -2 1 [sprout-lights 1 [ set color green set state green set name "W2E" set direction "EW"] ]
  ask patch -1 -2 [sprout-lights 1 [ set color red set state red set name "S2N" set direction "NS"] ]
  ask patch 1 2 [sprout-lights 1 [ set color red set state red set name "N2S" set direction "NS"] ]

  ;; Add a gamer at top-left
  ask patch (min-pxcor + 3) (max-pycor - 3) [sprout-gamers 1 [set color red set size 3]]

end

to go
  set time 0
  set last-decision 0
  ask cars [die]
  set wait-time-list []
  set drive-time-list []
  set average-speed-list []
  set pass-car 0
  set average-wait 0

  if not random-switch? [
    while [time <= time-window] [
      if (time - last-decision >= cool-down) [
        switch
        set last-decision time
      ]
      env-go
    ]
  ]

  if random-switch? [
    while [time <= time-window] [
      if (time - last-decision >= cool-down) [
        let random-state random 100

        ifelse random-state <= switch-probability [NS-pass] [EW-pass]

        set last-decision time
      ]
      env-go
    ]
  ]


  ;; Calculate the global result
  set pass-car length drive-time-list
  set average-wait reduce [ [a b] -> a + b ] wait-time-list / length wait-time-list
  set average-drive reduce [ [a b] -> a + b ] drive-time-list / length drive-time-list
  set average-speed reduce [ [a b] -> a + b ] average-speed-list / length average-speed-list
  ;;print(pass-car)
  ;;print(average-drive)
  ;;print(average-speed)
end

;; do the simulation
to env-go
  ;; move cars
  ask cars [ move ]

  ;; update cars state
  ask cars with [speed = 0] [set wait-time wait-time + 1]
  ask cars with [speed > 0] [set drive-time drive-time + 1]


  ;; generate new cars
  ;; N-S
  make-new-car traffic-flow-from-north 1 max-pycor 180
  ;; S-N
  make-new-car traffic-flow-from-south -1 min-pycor 0
  ;; E-W
  make-new-car traffic-flow-from-east max-pxcor -1 270
  ;; W-E
  make-new-car traffic-flow-from-west min-pxcor 1 90

  set time time + 1
end


to switch
  ifelse signal-NS? [EW-pass] [NS-pass]
end

to NS-pass
  ask lights with [direction = "NS"] [set color green set state green]
  ask lights with [direction = "EW"] [set color red set state red]
  set signal-NS? true
end

to EW-pass
  ask lights with [direction = "EW"] [set color green set state green]
  ask lights with [direction = "NS"] [set color red set state red]
  set signal-NS? false
end


;; add car into system base on the traffic flow data
to make-new-car [freq x y h]
  ;; generate cars based on the freq. for example  if freq=50, it means it have 50% possibility to create a new car
  if (random-float 100 < freq) and not any? cars-on patch x y [
    create-cars 1 [
      setxy x y
      set heading h
      set color one-of base-colors
      set wait-time 0
      set speed-list []
      adjust-speed
    ]
  ]
end

;; let cars go
to move
  adjust-speed
  repeat speed [
    let target-patch patch-ahead 1
    if not is-blocked? target-patch [
      fd 1
    ]
    if not can-move? 1 [
      set drive-time-list fput drive-time drive-time-list
      set wait-time-list fput wait-time wait-time-list
      set average-speed-list fput ((reduce [ [a b] -> a + b ] speed-list) / length speed-list) average-speed-list
      die
    ] ;; clear the car when it go out of the system
  ]
end

;; car reporter calculate the min-stop distance
to-report breaking-distance-at [ speed-at-this-tick ]
  let min-speed-at-next-tick max (list (speed-at-this-tick - max-brake) 0)
  report speed-at-this-tick + min-speed-at-next-tick
end

;; get the next block patch
to-report next-blocked-patch
  let patch-to-check patch-here
  while [ patch-to-check != nobody and not is-blocked? patch-to-check ] [
    set patch-to-check patch-ahead ((distance patch-to-check) + 1)
  ]
  ; report the blocked patch or nobody if I didn't find any
  report patch-to-check
end

;; check stop or not
to-report is-blocked? [ target-patch ]
  report
    any? other cars-on target-patch or
    any? (lights-on target-patch) with [ color = red ]
end

;; adjust the speed to appropriate
to adjust-speed
  ; calculate the minimum and maximum possible speed I could go
  let min-speed max (list (speed - max-brake) 0)
  let max-speed min (list (speed + max-accel) speed-limit)

  let target-speed max-speed ; aim to go as fast as possible

  let blocked-patch next-blocked-patch
  if blocked-patch != nobody [
    ; if there is an obstacle ahead, reduce my speed
    ; until I'm sure I won't hit it on the next tick
    let space-ahead (distance blocked-patch - 1)
    while [
      breaking-distance-at target-speed > space-ahead and
      target-speed > min-speed
    ] [
      set target-speed (target-speed - 1)
    ]
  ]
  set speed target-speed
  set speed-list fput speed speed-list
end
@#$#@#$#@
GRAPHICS-WINDOW
7
10
330
334
-1
-1
15.0
1
10
1
1
1
0
0
0
1
-10
10
-10
10
0
0
1
ticks
30.0

BUTTON
377
22
446
55
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
378
73
449
106
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
549
77
769
110
traffic-flow-from-north
traffic-flow-from-north
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
549
118
769
151
traffic-flow-from-south
traffic-flow-from-south
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
549
159
771
192
traffic-flow-from-east
traffic-flow-from-east
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
549
201
772
234
traffic-flow-from-west
traffic-flow-from-west
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
810
78
982
111
max-brake
max-brake
0
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
811
122
983
155
max-accel
max-accel
0
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
810
36
982
69
speed-limit
speed-limit
0
10
5.0
1
1
NIL
HORIZONTAL

SWITCH
551
36
684
69
signal-NS?
signal-NS?
0
1
-1000

INPUTBOX
371
269
526
329
cool-down
15.0
1
0
Number

INPUTBOX
372
194
527
254
time-window
180.0
1
0
Number

TEXTBOX
372
167
522
185
Environment 
12
0.0
1

TEXTBOX
550
12
700
30
Traffic
12
0.0
1

TEXTBOX
812
11
962
29
Cars
12
0.0
1

SLIDER
372
381
528
414
switch-probability
switch-probability
0
100
50.0
1
1
NIL
HORIZONTAL

SWITCH
372
337
526
370
random-switch?
random-switch?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="notrandom" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="22"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="22"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_HH" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="30"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_HM" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_HL" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_MM" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="20"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_ML" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="pre_defined_LL" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>pass-car</metric>
    <metric>average-speed</metric>
    <metric>average-wait</metric>
    <metric>average-drive</metric>
    <enumeratedValueSet variable="traffic-flow-from-west">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="cool-down">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-accel">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="time-window">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-switch?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-south">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="switch-probability">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-north">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="signal-NS?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed-limit">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-brake">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="traffic-flow-from-east">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
