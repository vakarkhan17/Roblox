# Sound IDs to fill in

Paste the asset ID (numbers only) after the `=` on each line, save the file, and tell Claude Code "apply the sound ids". Leave a line empty to keep the stand-in sound.

How to find one: Studio → **Toolbox → Audio** → type the search words → press play to listen → right-click → **Copy Asset ID**.
Tip: sounds published by **Roblox** always work. Other people's sounds are often private and stay silent.

## Music (long tracks that loop)
| Name | Plays | Search words | 
|---|---|---|
| Menu | title and pause menu | 80s title theme, synthwave menu |
| Town | Hollow Creek | synthwave, retro 80s, chill synth |
| Undergrid | the Undergrid | dark ambient, horror ambience |
| Boss | Mind Warden, Carrier, WHCK van, the Listener | boss battle, intense synth, action |
| Storm | Chapter 5 storm in town | suspense, tense music |
| Site2 | Site 2 under the hotel | creepy drone, horror bunker |
| DeepGrid | the Deep Grid | epic dark, void ambience |
| Morning | the ending | calm morning, happy ending, peaceful |

```
Menu      =
Town      =
Undergrid =
Boss      =
Storm     =
Site2     =
DeepGrid  =
Morning   =
```

## Ambience (quiet loops under the music)
| Name | Plays | Search words |
|---|---|---|
| amb_Undergrid | the Undergrid | eerie wind loop, wind ambience |
| amb_Storm | Chapter 5 storm | storm wind, static noise loop |
| amb_Site2 | Site 2 | room tone, bunker hum, machine hum |
| amb_DeepGrid | the Deep Grid | deep drone, low hum, space ambience |

```
amb_Undergrid =
amb_Storm     =
amb_Site2     =
amb_DeepGrid  =
```

## Weapons
| Name | Plays | Search words |
|---|---|---|
| shot | Pulse Cannon and Arc Repeater | laser shot, blaster |
| shotHeavy | Scattergun and Lance | heavy laser, plasma cannon |
| baton | Shock Baton | electric zap, taser |
| reload | reloading | gun reload |
| empty | out of ammo | empty gun click |
| hit | your shot hits an enemy | hit marker, impact |
| kill | an enemy dies | monster death, poof |

```
shot      =
shotHeavy =
baton     =
reload    =
empty     =
hit       =
kill      =
```

## You
| Name | Plays | Search words |
|---|---|---|
| transform | suit up / robot ⇄ car | mech transform, robot transform |
| rift | crossing the rift | portal, teleport whoosh |
| hurt | you take damage | hurt, damage |
| robotStep | each step in robot mode | metal footstep, robot step (one step, not a loop) |
| engine | car mode | car engine loop (must loop smoothly) |

```
transform =
rift      =
hurt      =
robotStep =
engine    =
```

## Hotel
| Name | Plays | Search words |
|---|---|---|
| doorOpen | a room door opens | wooden door open, door creak |
| doorClose | a room door closes | door close, door shut |
| elevatorDing | you arrive on a floor | elevator ding, elevator bell |
| elevatorStuck | stuck elevator, locked door | error buzz, access denied |

```
doorOpen      =
doorClose     =
elevatorDing  =
elevatorStuck =
```

## Creatures and bosses
| Name | Plays | Search words |
|---|---|---|
| growl | a Hollower is near | monster growl, creature breathing |
| houndCrackle | a Static Hound is near | electric crackle, static |
| echoHum | an Echo is near | robot hum, dark synth hit |
| echoShot | an Echo shoots | enemy laser, sci-fi shot |
| bossOpen | the Mind Warden's head opens | monster roar, screech |
| bossSlam | the Mind Warden slams | ground slam, heavy impact |
| beamWarning | red circle before the Listener's beam | warning beep, alarm beep |
| beam | the Listener's beam hits | lightning strike, energy beam |

```
growl        =
houndCrackle =
echoHum      =
echoShot     =
bossOpen     =
bossSlam     =
beamWarning  =
beam         =
```

## Pickups, messages, menu
| Name | Plays | Search words |
|---|---|---|
| pickup | shard, file, keycard, ammo box, tapes | item pickup, collect |
| scrap | you get Scrap | coin, cash register |
| fanfare | achievement, quest, level up, chapter complete, daily reward | level up, achievement, victory jingle |
| alert | bad news (teammate down, out of ammo, too late) | alert, warning sound |
| notify | any other banner | notification, soft beep |
| ping | a ping marker | radar ping, sonar |
| prompt | using a prompt (E) | button press, interact |
| click | menu buttons | ui click, menu click |
| thunder | now and then in the storm | thunder |
| drip | now and then in Site 2 | water drip, single drop |

```
pickup  =
scrap   =
fanfare =
alert   =
notify  =
ping    =
prompt  =
click   =
thunder =
drip    =
```
