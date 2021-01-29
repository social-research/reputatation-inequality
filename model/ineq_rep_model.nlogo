globals [
  gini-index-reserve
  partner-error
  behavior-error
  cooperative-types
  cc-payoff        ;; payoff for cooperating when partner cooperates
  cd-payoff        ;; payoff for cooperating when partner defects
  dc-payoff        ;; payoff for defecting when partner cooperates
  dd-payoff        ;; payoff for defecting when partner defects too
  init-coop        ;; probability of cooperating in initial round
  thresh-coop      ;; minimum level of cooperation to decide to cooperate
]

turtles-own [
  wealth           ;; the amount of wealth this turtle has
  cooperativeness  ;; 0 - defectors, 1 - conditional cooperators, 2 - altruists
  partners-choice  ;; set of others with whom the turtle would like to interact
  action-choice    ;; final decision whether to cooperate or not after possible error
  payoff           ;; the turtle's current payoff after the game has been played
  action-history   ;; list of actions in all periods until now
  payoff-history   ;; list of payoffs in all periods until now
  others-history   ;; list of average actions of neighbors in all periods until now
]


;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  set partner-error 0.005
  set behavior-error 0.005
  ;; assume PD with CC = 5*pC, CD = 0, DC = 8*pC, and DD = 2*(1-pC), as in Wang et al. (2012) but + 1 to avoid negative wealth
  set cc-payoff 5
  set cd-payoff 0
  set dc-payoff 8
  set dd-payoff 2

  ;; in first period, flip a coin to determine whether to cooperate
  set init-coop 0.15
  set thresh-coop 0.5

  ;; forward thinking in case of reputation: cooperation is more likely
  if reputation > 0
    [set init-coop init-coop + (0.1 * reputation)
     set thresh-coop thresh-coop - (0.05 * reputation)
  ]

  ;; assume 20% defectors, 65% reciprocators, 15% altruists (Kurzban and Houser 2005)
  set cooperative-types (list
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
    1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
    1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1
    1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2)

  create-turtles population-size [turtle-setup]
  network-setup
  layout
  if resize-nodes?
    [resize-nodes]
  update-gini
  reset-ticks
end

to turtle-setup
  set color white
  set shape "circle"
  ;; wealth is initially distributed according to income-distribution
  set wealth 0
  set cooperativeness one-of cooperative-types
  set action-history []
  set others-history []
  set payoff-history []
  ;; for visual reasons, we don't put any nodes *too* close to the edges
  setxy (random-xcor * 0.95) (random-ycor * 0.95)
end

to network-setup
  ifelse network = "rewired-clustered" or network = "strategic-clustered"
    [setup-spatially-clustered-network]
    [setup-random-network]
end

to setup-spatially-clustered-network
  ;; repeat until the network is connected
  while [min [count link-neighbors] of turtles = 0]
  [
    clear-links
    let num-links (avg-partners * population-size / 2)
    while [count links < num-links ]
    [
      ask one-of turtles
      [ ;; choose to connect to agent who is closest in space
        let choice (min-one-of (other turtles with [not link-neighbor? myself])
          [distance myself])
        if choice != nobody
        [
          create-link-with choice
        ]
      ]
    ]
  ]
end

to setup-random-network
  ;; repeat until the network is connected
  while [min [count link-neighbors] of turtles = 0]
  [
    clear-links
    let num-links (avg-partners * population-size / 2)
    while [count links < num-links ]
    [
      ask one-of turtles
      [ ;; choose to connect to an agent chosen completely at random
        let choice (one-of (other turtles with [not link-neighbor? myself]))
        if choice != nobody
        [
          create-link-with choice
        ]
      ]
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures ;;
;;;;;;;;;;;;;;;;;;;;;;;;


to go
  ask turtles [choose-action]
  ask turtles [play]
  update-wealth
  layout
  if resize-nodes? [resize-nodes]
  color-nodes
  update-gini

  ;; update network if required
  if network = "rewired-random" [
    clear-links
    setup-random-network
  ]
  if network = "rewired-clustered" [
    clear-links
    ask turtles [setxy (random-xcor * 0.95) (random-ycor * 0.95)]
    setup-spatially-clustered-network
  ]
  if network = "strategic-random" or network = "strategic-clustered" [
    update-network
  ]
  tick
end

to choose-action
  ;; action allows for errors

  let cooperate? if-cooperate
  if (random-float 1.0) < behavior-error
  [;; in case of behavior error, do the opposite of chosen action
    ifelse cooperate? = 1
      [set cooperate? 0]
      [set cooperate? 1]
  ]
  set action-choice cooperate?
end

to-report if-cooperate
  ;; action is determined by cooperative type and partners' previous actions

  ;; if defector, always choose to defect
  if cooperativeness = 0
    [report 0]

  ;; if cooperator, always choose to cooperate
  if cooperativeness = 2
    [report 1]

  ;; if conditional cooperator, choose depending on what others have done
  if cooperativeness = 1
  [
    ifelse empty? others-history
    [
      ifelse (random-float 1.0) < init-coop
        [report 1]
        [report 0]
    ]
    [
      ;; base decision on others' previous actions
      ifelse count link-neighbors > 0
      [
        let memory 0
        let t ticks
        ifelse reputation = 0
          [set memory last others-history] ;; base decision on last period's others-history
          [set memory mean [last action-history] of link-neighbors]   ;; base decison on current neighbors' action-history over last period
        ;; cooperate if more than half of others have cooperated in previous period
        ifelse memory > thresh-coop
          [report 1]
          [report 0]
      ]
      [
        ;; if excluded, cooperate with p = 0.5, equvalent to pick in random
        ifelse (random-float 1.0) < 0.5
          [report 1]
          [report 0]
      ]
    ]
  ]
end

to play
  ;; update payoffs and memory record
  set payoff 0
  let others-choice 0
  if count link-neighbors > 0
  [
    ;; payoff is a function of mean choice of others
    set others-choice mean [action-choice] of link-neighbors
    ifelse action-choice = 1
      [set payoff cc-payoff * others-choice + cd-payoff * (1 - others-choice)]
      [set payoff dc-payoff * others-choice + dd-payoff * (1 - others-choice)]
  ]
  ;; update action-history, others-history
  set action-history lput action-choice action-history
  set others-history lput others-choice others-history
end


to update-wealth
  ;; update payoff record and wealth
  ask turtles [
    set payoff-history lput payoff payoff-history
    set wealth wealth + payoff
  ]
end


to update-network
  ;; sever one link if partner defects in majority of reputation periods
  ask turtles [
    ;; get rid of one neighbor who is defecting
    ifelse reputation = 0
    [
      ;; if no reputation, base decison on neighbors' action-history over last period - equivalent to reputation=1
      let defectors [who] of link-neighbors with [last action-history < 1]
      ifelse empty? defectors
        [set partners-choice [who] of link-neighbors]
        [let to-drop one-of defectors
         set partners-choice [who] of link-neighbors with [who != to-drop]
        ]
    ]
    [
      ;; if reputation, base decison on neighbors' action-history over last reputation periods
      let t ticks
      let defectors [who] of link-neighbors with [ mean (sublist action-history (max (list 0 (t + 1 - reputation))) (t + 1)) < thresh-coop]
      ifelse empty? defectors
        [set partners-choice [who] of link-neighbors]
        [let to-drop one-of defectors
         set partners-choice [who] of link-neighbors with [who != to-drop]
        ]
    ]

    ;; replace missing partner only if not already too many partners
    let expected-partners 2 * avg-partners

    ;; noise: with small probability, don't change current network
    if (random-float 1.0) < partner-error
    [
      set partners-choice [who] of link-neighbors
      set expected-partners count link-neighbors
    ]

    ;; if desires new partners, nominate several; necessary to ensure network doesn't get too dense
    if length partners-choice < expected-partners
    [
      let random-choice []
      ifelse reputation = 0
      [
        ;; if no reputation, pick some at random
        set random-choice [who] of n-of (expected-partners - length partners-choice) other turtles with [not link-neighbor? myself]
      ]
      [
        ;; if reputation, base choice on turtles' action-history over last reputation periods
        let t ticks
        set random-choice [who] of n-of (expected-partners - length partners-choice) other turtles with [(not link-neighbor? myself) and (mean (sublist action-history (max (list 0 (t + 1 - reputation))) (t + 1)) > thresh-coop)]
      ]
      set partners-choice sentence partners-choice random-choice
    ]
  ]
  ;; if mutual partners-choice, make links
  clear-links
  ask turtles [
    let my-partners-choice partners-choice
    let me who
    let mutual other turtles with [(member? who my-partners-choice) and (member? me partners-choice) and (not link-neighbor? myself)]
    create-links-with mutual
  ]
end


;;;;;;;;;;;;;;;
;; Reporting ;;
;;;;;;;;;;;;;;;

to update-gini
  let sorted-wealths sort [wealth] of turtles
  let total-wealth sum sorted-wealths
  ifelse total-wealth = 0
  [
    set gini-index-reserve 0
  ]
  [
    let wealth-sum-so-far 0
    let index 0
    set gini-index-reserve 0
    let lorenz-points []
    repeat population-size [
      set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
      set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
      set index (index + 1)
      set gini-index-reserve
        gini-index-reserve +
        (index / population-size) -
        (wealth-sum-so-far / total-wealth)
    ]
  ]
end

;;;;;;;;;;;;
;; Layout ;;
;;;;;;;;;;;;

to resize-nodes
  ask turtles [ set size 0.2 + sqrt max (list 1 (wealth / 10)) ]  ;;log (max (list 1 wealth)) 10
end

to color-nodes
  ;; change color to blue if cooperate, red if defect
  ask turtles [
    ifelse action-choice = 1
      [set color blue]
      [set color red]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt population-size
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (50 / factor) (20 / factor)
    display  ;; for smooth animation
  ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end
@#$#@#$#@
GRAPHICS-WINDOW
300
10
708
419
-1
-1
8.0
1
10
1
1
1
0
0
0
1
0
49
0
49
1
1
1
ticks
30.0

BUTTON
10
280
90
320
NIL
setup
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
100
280
190
320
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
200
280
290
320
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
720
10
965
180
Wealth distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-histogram-num-bars 10\nset-plot-x-range 0 (max list (max [wealth] of turtles) 1)\nset-plot-pen-interval ((max [wealth] of turtles) / 10)"
PENS
"default" 1.0 1 -16777216 true "" "histogram ([wealth] of turtles)"

SLIDER
10
10
290
43
population-size
population-size
10
1000
100.0
10
1
NIL
HORIZONTAL

PLOT
720
190
965
355
Gini index vs. time
Time
Gini
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -955883 true "" "plot (gini-index-reserve / population-size) * 2"

SWITCH
10
340
152
373
resize-nodes?
resize-nodes?
1
1
-1000

CHOOSER
10
50
177
95
network
network
"rewired-random" "rewired-clustered" "strategic-random" "strategic-clustered"
3

SLIDER
10
100
182
133
reputation
reputation
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
10
140
182
173
avg-partners
avg-partners
1
20
5.0
1
1
NIL
HORIZONTAL

MONITOR
720
370
895
415
Average number of partners
2 * (count links) / population-size
1
1
11

PLOT
975
190
1220
355
Cooperation vs. time
Time
Proportion cooperate
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot mean [action-choice] of turtles"

PLOT
975
10
1220
180
Wealth vs. cooperation
NIL
NIL
0.0
1.0
0.0
10.0
true
false
"" "clear-plot"
PENS
"default" 1.0 2 -16777216 false "" "ask turtles [plotxy (mean action-history) wealth]"

@#$#@#$#@
## WHAT IS IT?

This model explores the effects of reputational information on inequality in dynamic networks. 


## HOW IT WORKS

The agents in the model use heuristics – they follow simple behavioural rules to adapt and respond to incentives and others’ actions. Agents play an N-person Prisoner’s Dilemma game in which they choose between cooperating (C) and defecting (D).

Following empirical research on behavioural proclivities in the general population, the model assumes that agents belong to three different cooperation types: 20% are defectors, 15% are altruists, and 65% – conditional cooperators. Altruists always cooperate, defectors never do, and conditional cooperators initially cooperate with probability 0.15, after which they reciprocate by choosing the action the majority of their previous interaction partners chose. To avoid stochastically unstable outcomes, the model further assumes a small probability for error ε=0.005 such that the agent executes an action that is opposite to the one they originally choose.

The model compares the effect of network dynamics by allowing two modes of network updating. For the randomly rewired networks, agents are placed in a new network every period. For the strategically updated networks, every period each agent is given the opportunity to replace one of their defecting neighbours with someone else. An existing link gets deleted if one of the two agents drops it, but for a new link to appear, both agents need to desire it. To simulate more realistic networks, the model restricts the maximum possible number of neighbours to 10. And similarly to action decisions, the model assume a small probability for error ε=0.005 such that the agent does not update their network even if they had decided to.

The model also allows to manipulate reputation – the information available about others and how agents react to it. In the case of reputation = 0, agents have knowledge of their neighbours’ behaviour only if they interacted directly with them, while when reputation > 0, others’ actions are a public knowledge. 

Without reputation, the conditional cooperators initially cooperate with probability 0.15 and then cooperate if at least 50% of their neighbours cooperated in the last period. When reputational information is available, the conditional cooperators initially cooperate with probability 0.15 + (0.1 * reputation) and then cooperate if at least 0.5 - (0.05 * reputation) of their neighbours cooperated over the last 1, or respectively 3, periods. These numbers reflect the fact that forward-looking individuals are more likely to cooperate when they are aware of the negative consequences from a reputation as a non-cooperator.
 
Reputational information also comes in play when agents select new partners. Without reputational information, agents pick new partners randomly from those with whom they are not yet linked. Otherwise, they pick only among those who have cooperated at least 50% in the past one/three periods.


## HOW TO USE IT

The POPULATION-SIZE slider sets how many agents are in the world.

The NETWORK chooser sets the structure of the initial network (random or spatially clustered) and how the network is updated (randomly reqired or strategically updated).

The REPUTATION slider determines the number of periods for which information is available for other agents' previous actions.

The AVG-PARTNERS slider sets the average number of partners agents have in the initial network.

Press SETUP to populate the world with agents. GO will run the simulation continuously, while GO ONCE will run one tick.

When RESIZE-NODES is selected, the agents with higher wealth will be represented with larger nodes.

The WEALTH-DISTRIBUTION histogram on the right shows the distribution of wealth.

The GINI INDEX VS. TIME plot shows a measure of the inequity of the distribution over time.  A GINI INDEX of 0 equates to everyone having the exact same amount of wealth, and a GINI INDEX of 1 equates to the most skewed wealth distribution possible, where a single person has all the wealth, and no one else has any.

The COOPERATION VS. TIME plot shows the proportion of agents who are cooperating over time.

The WEALTH VS. COOPERATION plot shows the current wealth of agents depending on the proportion of times they chose to cooperate out of all they actions they took until the current period.

## THINGS TO NOTICE

Even though reputational information affects cooperation in similar ways, it decreases inequality in randomly rewired networks but increases inequality in strategically updated networks. 

With random rewiring, the defectors always have higher payoffs than the cooperators but since reputation increases the number of cooperators, everyone’s payoffs increase and hence, the payoff gap between cooperators and defectors decreases. As a result, inequality lowers. 

With strategic updating, cooperators typically gain more than defectors. Reputation increases the level of cooperation but this happens at the expense of defectors who get excluded. Thus, the difference in payoffs between cooperators and defectors widens and inequality grows. 


## RELATED MODELS

The model uses code and features from the NetLogo Sugarscape models. 

For more explanation of the Lorenz curve and the Gini index, see the Info tab of the Wealth Distribution model.  (That model is also based on Epstein and Axtell's Sugarscape model, but more loosely.)


## HOW TO CITE

For the model itself:

* Tsvetkova, M. (2021). The effects of reputation on inequality in network cooperation games. 

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="100_0.15_init_frep_initboost_nothreshboost" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>(gini-index-reserve / population-size) * 2</metric>
    <metric>mean [action-choice] of turtles</metric>
    <metric>[wealth] of turtles</metric>
    <metric>[cooperativeness] of turtles</metric>
    <metric>[mean action-history] of turtles</metric>
    <enumeratedValueSet variable="avg-partners">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-size">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="resize-nodes?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network">
      <value value="&quot;rewired-random&quot;"/>
      <value value="&quot;rewired-clustered&quot;"/>
      <value value="&quot;strategic-random&quot;"/>
      <value value="&quot;strategic-clustered&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reputation">
      <value value="0"/>
      <value value="1"/>
      <value value="3"/>
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
1
@#$#@#$#@
