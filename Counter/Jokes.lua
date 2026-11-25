-- The death's joke: lines per cause, and lines that fit the death itself (the mob's kind, the killer,
-- the killing blow), picked for each death, which the card shows and the Streamer.bot line carries.
local _, ns = ...

-- Ten per cause. Filled in from the death: {killer}, {kills} (its kills on you), {name} (your first
-- name), {faction}, {spell}, {amount}, {overkill}, {killerLevel}, {level}, {gap} and {alive}.
ns.JOKES = {
    mob = { "{killer} {kills}, {name} 0.", "{killer} wins this round.", "Outplayed by {killer}.",
        "{killer} didn't even break a sweat.", "That's {kills} for {killer}.", "Should have pulled one at a time.",
        "{killer} wants a rematch. You don't.", "Back to the graveyard, {name}.", "{killer} is getting good at this.",
        "Aggro range: underestimated." },
    player = { "For the {faction}. Nothing personal.", "Should have checked the minimap.", "Should have stayed in town.",
        "Ganked.", "{killer} says hi. With a weapon.", "{killer} needed that honor.", "World PvP is alive and well.",
        "Revenge is on the to-do list.", "Contested territory, as advertised.", "GG, {killer}." },
    fall = { "Gravity remains undefeated.", "Took the short way down.", "The ground came up fast.",
        "Slow Fall was right there.", "Calculated. Wrongly.", "Fell for it.", "That ledge looked shorter.",
        "Didn't stick the landing.", "You can't fly. Now you know.", "Should have taken the flight path." },
    drown = { "Forgot to breathe.", "The fish send their regards.", "Breath bar: ignored.", "Gills not included.",
        "Deep water, short story.", "Should have brought water breathing.", "Air was optional, apparently.",
        "Sank like a stone.", "Held your breath. Not long enough.", "One more chest wasn't worth it." },
    lava = { "The floor was lava.", "Warm, then very warm.", "Hot tub too hot.", "Your boots melted first.",
        "Took a dip in the wrong pool.", "Medium rare.", "Lava: still hot.", "Should have watched the floor.",
        "Swimming in lava: not recommended.", "That glow was a warning." },
    fire = { "Fire is not a buff.", "Don't stand in the fire.", "Too close to the campfire.", "Crispy.",
        "Smelled smoke, ignored it.", "Toasted.", "Not a fire-resistant build.", "The fire won.", "Well done.",
        "That's not how you warm up." },
    fatigue = { "Map edge: confirmed.", "The edge of the map bites back.", "No flight path out here.",
        "Next stop: nowhere.", "Should have turned back sooner.", "The world ends here. So did {name}.",
        "Explorer spirit, swimmer's body.", "Should have taken the boat.", "Not even murlocs swim this far.",
        "Turns out the ocean has a border." },
    slime = { "Should have stayed out of the green.", "Slimed.", "Green means stop.", "That puddle had plans.",
        "Gross way to go.", "Toxic relationship with the floor.", "Sticky situation.", "Ooze-proof boots sold separately.",
        "Ooze 1, {name} 0.", "Never step in the glowing stuff." },
    self = { "Friendly fire.", "Own goal.", "Self-inflicted.", "{name}'s worst enemy: {name}.",
        "Did that on purpose. Probably.", "Didn't need any help dying.", "Top damage dealer, on self.", "That one's on {name}.",
        "Read the tooltip next time.", "A risky spell, as it turns out." },
    unknown = { "Case closed. Unsolved.", "Blame lag.", "Cause of death: yes.", "Not even the Spirit Healer knows.",
        "File under: mysterious.", "The recap shrugs.", "Something out there doesn't like {name}.",
        "The coroner is baffled.", "Death by ???", "Even the game doesn't know." },
}
-- Lines that only fit some deaths: "repeat" once the mob has killed you as often as a nemesis
-- needs, "world" only out in the world, never in a battleground or an arena.
ns.JOKES_WHEN = {
    ["{killer} is getting good at this."] = "repeat",
    ["Should have stayed in town."] = "world", ["Ganked."] = "world",
    ["World PvP is alive and well."] = "world", ["Contested territory, as advertised."] = "world",
}
-- Lines that fit what a death records beyond its cause (the killer's rank and level, the killing blow,
-- a short life), filled in from it.
ns.FIT_JOKES = {
    elite = { "Meant for a group. Met by you.", "The gold dragon was a warning.",
        "Main character energy. Not enough health.", "Soloing that was optional.", "Party of one: denied.",
        "{killer} is elite for a reason.", "LFG next time.", "Brave. Not smart.",
        "Bold of you to read Elite as a suggestion.", "Elite was not a compliment to you." },
    rare = { "Found a rare. The rare found you back.", "Rare spawn, common outcome.", "The silver dragon was a hint.",
        "Rares drop loot. This one dropped you.", "Found the rare first. Died first too.",
        "Worth it for the loot? Nobody knows.", "Lucky find. Unlucky fight.", "Somebody else gets the loot now." },
    higher = { "Level {killerLevel} vs level {level}. Fair fight.", "Come back at level {killerLevel}.",
        "{gap} levels up. Ambitious.", "Wrong zone, wrong level.", "Outleveled and outplayed.",
        "Should have come back in a few levels.", "Red name, red flag.", "Punching way above your level." },
    lower = { "Lost to a level {killerLevel}. Ouch.", "{gap} levels lower. Still won.", "A lowbie did this. Let that sink in.",
        "Even the easy ones bite.", "Don't tell anyone about this one.", "This was meant to be the easy one.",
        "Underestimated, then under the ground.", "That one goes in the blooper reel." },
    short = { "Back so soon?", "Corpse run, then another corpse run.", "The Spirit Healer knows you by name.",
        "Revived and re-died.", "{alive}. A record. The wrong kind.", "Déjà vu, the deadly kind.",
        "Speedrunning the graveyard.", "Blink and you missed that life." },
    fire = { "Grilled, no sauce.", "{spell}. Sizzling.", "Melted.", "Someone's cooking, and it's you.",
        "Ran out of health and eyebrows.", "Burned down to the boots." },
    frost = { "Frozen solid.", "{spell}. Chill.", "Put on ice.", "Brain freeze, then body freeze.",
        "Cold. Very cold. Dead.", "Should have brought a scarf." },
    nature = { "Struck by lightning.", "Poisoned, then done.", "{spell}. Nature wins.", "Mother Nature says no.",
        "Shocked. Not surprised.", "Nature always wins in the end." },
    shadow = { "Lights out.", "{spell}. Dark.", "Consumed by darkness.", "Shadow-boxed and lost.",
        "The void says hi.", "Should have stayed in the light." },
    arcane = { "Abracadabra. You're gone.", "{spell}. Purple everywhere.", "Blasted by sparkles.", "Purple is not your color.",
        "Arcane: hard to spell, harder to dodge.", "Nobody understands arcane. Including you." },
    holy = { "Smitten.", "Holy damage. Unholy outcome.", "The Light disagrees with you.", "Judged and sentenced.",
        "Prayers answered. Not yours.", "Holy smokes. Literally." },
    ranged = { "Shot from forty yards.", "Never got close.", "Pinned from a distance.",
        "Should have zigzagged.", "Long range, short life." },
    crit = { "That crit had your name on it.", "Crit for {amount}. Goodbye.", "Critical. Like your condition.",
        "Rolled a crit. You rolled over.", "Unlucky you, lucky crit." },
    overkill = { "Overkill by {overkill}. Rude.", "Dead twice over.", "The extra damage was personal.",
        "Killed you, then kept going.", "That was more than enough." },
}
-- A player killer's class: only about the class, never a school or one ability.
ns.CLASS_JOKES = {
    WARRIOR = { "Warriors don't do subtle.", "Should have kited.", "Rage well spent.", "Hit by a wall of plate.",
        "All rage, no regrets." },
    PALADIN = { "Plate, a hammer and opinions.", "Righteously flattened.", "Blessed with a beating.",
        "Smug, shiny and right.", "Too holy to die. Unlike you." },
    HUNTER = { "Their pet did half the work.", "Feed pet: you.", "Kited to death.",
        "Survival of the fittest. Not you.", "Tamed a beast. Then you." },
    ROGUE = { "Didn't see that one coming. Nobody does.", "Cheap shot. Very cheap.", "Stealth 1, awareness 0.",
        "Out of nowhere, into the ground.", "Never saw them. Never will." },
    PRIEST = { "Killed by the healer. Embarrassing.", "Mind over matter. Their mind.", "Holier than thou, and deadlier.",
        "Prayed over, then preyed on.", "Should have killed the healer first." },
    SHAMAN = { "Out-totemed.", "Earth, wind and you on fire.", "The elements picked a side.",
        "Should have killed the totems first.", "Spirits consulted. You lost." },
    MAGE = { "Should have closed the distance.", "Cloth armor, iron results.", "Glass cannon. Still a cannon.",
        "Free food and a free funeral.", "Robes beat armor today." },
    WARLOCK = { "Their demon says thanks.", "Soul shard acquired.", "Dotted and done.",
        "Should have killed the pet. Or the warlock.", "Deals with demons. Wins." },
    DRUID = { "Mauled by a cat. Or a bear. Or a tree.", "Shapeshifted into your problem.", "Bear with it.",
        "Never trust a tree.", "Hugs trees, hits people." },
}
-- Lines for a mob of a known kind, chosen by its body (not its name: Sunscale Screecher is a raptor).
ns.KIND_JOKES = {
    spider = { "Eight legs, zero mercy.", "Somehow the spider had better footwork.", "Webbed, wrapped and saved for later.",
        "Arachnophobia: justified.", "Should have brought a bigger boot.",
        "More scared of you? Apparently not.", "Got caught on the web.", "More legs, more problems.",
        "Now the spider has a snack and a story.", "Eight eyes, and all of them saw you coming.",
        "Follow the spiders, they said." },
    wolf = { "Who's a good boy? Not that one.", "Pulled one wolf. Got the family.",
        "Played fetch. You were the stick.", "The pack says thanks for dinner.", "Big bad wolf, small sad hero.",
        "The bite was worse than the bark.", "Outrun a wolf? Bold plan.", "Should have packed a squeaky toy.",
        "Now the pack howls about you.", "Ran with the wolves. Briefly.", "The pack survives." },
    murloc = { "Mrglglglgl!", "There's never just one murloc.", "The whole beach came running.",
        "Lost to a fish with legs.", "Gurgled at, then gutted.", "Should have brought tartar sauce.", "Speared by a fish.",
        "Hooked, lined, sunk.", "Pulled one. The ocean answered.", "Beach day: cancelled.",
        "Smelled fishy. Was fishy." },
    gnoll = { "Yipped to death.", "A hyena that learned to walk.", "Gnolls hit harder than they smell.",
        "Kibble for the pack.", "Another tally mark for the gnolls.", "Beaten by a dog in a loincloth.",
        "No plan, still worked.", "Fleas and a funeral.", "Went around the camp. Into the other camp.",
        "Bad dog. Very bad dog.", "Release the hounds." },
    kobold = { "You no take candle!", "Taken out by a candle hat.", "Tiny, many, rude.",
        "Candle on top, trouble below.", "Never underestimate a pickaxe.", "Death by small angry miner.",
        "Should have taken the candle and run.", "Dug your grave for free.", "Waxed by a kobold.",
        "Their candle outlasted you.", "Not one of the seven dwarfs." },
    raptor = { "Clever girl.", "Fast, toothy, done.", "Should have checked the tall grass.",
        "All teeth, no manners.", "Dinner for a dinosaur.", "The raptor didn't even stop running.", "Outrun by a lizard.",
        "Some lizards bite back.", "Should have looked behind you.", "Extinction is for other people." },
    quilboar = { "Got the point.", "Skewered by a pig on two legs.", "Bacon 1, hero 0.", "Hogtied.", "Gored.",
        "A prickly welcome.", "Turns out you were on the menu.", "Quilboar hospitality.",
        "Bristles first, questions later.", "Should have stayed out of the brambles.", "That'll do, pig. That'll do." },
    centaur = { "Trampled.", "Half horse, all trouble.", "Never race a centaur.", "Hoofprints on your back.",
        "Four legs beat two.", "Lost to a horse with arms.", "Galloped over.", "Horsing around: over.",
        "Run down in the open.", "Hold your horses. Too late.", "Hi-yo, Silver. Away from you." },
    undead = { "Joined the club.", "The dead fight dirty.", "Killed by someone already dead.", "Now you're both corpses.",
        "Rotten luck.", "Bones beat flesh today.", "Should have brought holy water.", "Dead tired. Then just dead.",
        "See you on the other side. Again.", "Lost to someone with no pulse.", "They're coming to get you." },
    ooze = { "Dissolved.", "Lost to a puddle.", "Death by goo.", "The ooze was mostly acid.", "You'll need more than a bath.",
        "Stepped in it.", "Acid wash, no rinse.", "Became part of the ooze.", "Ate your armor first.",
        "Beaten by something with no bones.", "Attack of the puddle." },
    ogre = { "Ogre smash. You squish.", "Big club, small brain, still won.", "Outsmarted by an ogre.",
        "Flattened, then forgotten.", "Ogre-whelmed.", "Brute force wins again.",
        "One swing. One corpse run.", "Can't count, but counted you out.", "Thick skull, heavy hands.",
        "Should have brought a bigger friend.", "Ogres have layers. You had one." },
    dragonkin = { "Scales beat skin.", "Whelp, that happened.", "Lizard with a grudge.",
        "Never trust anything with scales.", "Dragon food.", "Wings and teeth win again.",
        "Regards from the dragonflight.", "Should have brought a dragonslayer.", "Tail, claws, curtains.",
        "Ancient bloodline, fresh corpse.", "Dracarys." },
    furbolg = { "Hugged by the wrong bear.", "Big, furry and not friendly.", "Lost to a walking rug.",
        "Furry, angry and organized.", "Mauled by a teddy with opinions.", "Corrupted and cranky.",
        "The forest folk said no.", "Should have brought honey.", "Paws, claws, game over.",
        "Furbolg diplomacy: failed." },
    naga = { "Hissed at, then hit.", "Azshara's finest, sadly.", "The tide turned on you.",
        "Sunk by a snake from the deep.", "Ssssorry about that.", "Slithered over you.", "Drowned in scales.",
        "Should have stayed on the beach.", "Hissy fit, fatal edition.", "The ocean sent a bouncer.",
        "Snakes on a plain." },
    satyr = { "Horned and dangerous.", "Hooves, horns and bad intentions.", "Party in the woods. You weren't invited.",
        "The kid gloves came off.", "Lost to a demon with goat legs.", "Butted out.", "Cloven hooves, clean kill.",
        "Smelled like goat and fel.", "The satyr plays, you pay.", "Never dance with a satyr.", "Mr. Tumnus went bad." },
    bigcat = { "Curiosity killed you, not the cat.", "Nine lives. You had one.", "Pounced.", "Stalked, then served.",
        "Here, kitty kitty. Big mistake.", "Big cat, small chance.", "Clawed and done.", "You were the ball of yarn.",
        "The cat didn't even purr first.", "Feline fine. You're not.", "Hakuna matata. Not today." },
    trogg = { "Evolution lost this one.", "Lost to a cave goblin with rocks.", "Ambushed by the underground.",
        "Hit with the oldest weapon: a rock.", "Should have stayed out of the cave.", "Grunt, swing, gone.",
        "There's always another trogg.", "Smashed by a pebble enthusiast.", "Dug up and dropped.", "Rock beats you." },
    bogbeast = { "Swamped.", "Death by compost heap.", "The bog bit back.", "Mud, moss and murder.",
        "Stepped into the wrong swamp.", "Should have kept your boots dry.", "Composted.", "Slow, green and right on time.",
        "The marsh claims another.", "Beaten by wet plants.", "Get out of my swamp!" },
    bear = { "Bear hug: fatal.", "Wrong picnic.", "Mauled.", "Should have played dead earlier.", "Unbearable.",
        "Big paws, short fight.", "Woke the wrong bear.", "Hibernation over. So are you.",
        "The bear wanted honey. You were in the way.", "Grizzly ending." },
    harpy = { "Clawed from above.", "Lost to a bird with a bad attitude.", "Feathers, talons, screaming.",
        "Should have looked up.", "Plucked.", "The nest was occupied.", "Winged and wiped.",
        "Shrieked at, then shredded.", "Harpies don't do warnings.", "Dive-bombed.", "Hitchcock was right about birds." },
    earthelemental = { "The mountain moved. Onto you.", "Lost to a walking quarry.", "Bedrock bottom.",
        "The ground stood up.", "Hard as rock. Made of rock.", "Crushed under a hillside.",
        "Should have brought a pickaxe.", "Grounded. Permanently.", "Landslide.", "Pebbles hurt in bulk.",
        "You shall not pass." },
    scorpid = { "Stung.", "The tail end of a bad day.", "Pinched, then stung.", "Should have shaken out your boots.",
        "Poison was the punchline.", "Clicked to death.", "Never trust a lobster in the desert.",
        "Armored, angry, venomous.", "Two claws and a needle.", "That tail was not for show.", "Get over here!" },
    boar = { "Tusked.", "Charged and charged again.", "Hamstrung by a ham.", "Lost to dinner.", "Tusk, tusk.",
        "Pork chop, reversed.", "Never corner a boar.", "Run over by bacon.", "Squealed, then won.",
        "The pig was the hunter.", "Pumbaa had a bad day." },
    carrionbird = { "The vultures were early.", "Circled, then served.", "Picked clean.", "The vultures were waiting for this.",
        "Lunch arrived on foot.", "Never ignore a circling bird.", "Scavenged before you were done.", "Beak first.",
        "Too hungry to wait.", "Bones for the buzzards.", "Quoth the buzzard: nevermore." },
    crocolisk = { "Death roll.", "Snapped up.", "Should have crossed somewhere else.", "See you later, adventurer.",
        "All jaws, no mercy.", "Lunch by the riverbank.", "The log had teeth.", "Never smile at a crocolisk.",
        "Dragged under.", "Toothy grin, short fight." },
    kodo = { "Stomped.", "Too big to go around.", "Stepped on, not around.", "Flattened by a beast of burden.",
        "Should have moved. The kodo wasn't going to.", "Kodo crossing. You didn't.", "Slow, huge, unstoppable.",
        "Ground into the dirt.", "The kodo barely noticed you.", "Big feet, bad day." },
    zhevra = { "Kicked by a striped horse.", "Stripes and hooves.", "Outrun and out-kicked.", "Lost to a fancy horse.",
        "Should have watched the back legs.", "Hoof to the face.", "Fast, striped and rude.",
        "Ran circles around you. Then over you.", "Horse with a barcode.", "Never stand behind a zhevra.",
        "Marty from Madagascar went rogue." },
    spirit = { "Haunted to death.", "Killed by something you could see through.", "Spooked to the bone.",
        "Now you can haunt {killer} back.", "Lost to a bedsheet with anger issues.", "Boo. Done.",
        "{killer} walked through walls. And you.", "The cold spot was a warning.", "Ghosted, the hard way.",
        "Laid to rest. By a ghost.", "Should have called the Ghostbusters.", "I see dead people. Now you're one." },
    worgen = { "Used to be a man. Now a problem.", "Full moon, empty health bar.", "Half man, half wolf, all teeth.",
        "Howled at, then mauled.", "The curse took a bite of you.", "A wolf in a man's clothes.",
        "Clawed by a werewolf. Classic.", "Should have carried silver.", "Feral, then fatal.",
        "Fur, fangs and a bad temper." },
    waterelemental = { "Drowned on dry land.", "Washed away.", "A lake with a bad temper.", "Splashed to death.",
        "Hydrated, then terminated.", "Too much water in one place.", "Soaked through.", "A wave with fists.",
        "Wet, cold and final.", "You can't punch water." },
    fireelemental = { "Burned by a bonfire with arms.", "Too hot to handle.", "Flame on. You off.",
        "Flames, fists, funeral.", "Charred.", "Walked into a walking fire.", "Smoke and ashes.",
        "Burning, walking, winning.", "Well done. Too well done.", "Stop, drop and respawn." },
    airelemental = { "Gone with the wind.", "Blown away.", "Lost to thin air.", "Swept off your feet.",
        "A breeze with bad intentions.", "Whirled, then hurled.", "Air quality: deadly.", "Breezy. Then deadly.",
        "Airborne, briefly.", "Hard to hit, easy to die to." },
    basilisk = { "Stared down.", "Stoned by a lizard's look.", "Never look a basilisk in the eye.",
        "Crystal back, sharp teeth.", "Scared stiff. Very stiff.", "A lizard wearing rocks.", "Bitten by a geode.",
        "Turned to stone, then to dust.", "One look was enough.", "Rock solid. Unlike you." },
    windserpent = { "Zapped from above.", "Bad weather, with fangs.", "Lightning breath, quick death.",
        "Sky noodle, big voltage.", "The serpent flew. You fell.", "Feathers and fangs.",
        "Struck by a serpent in the sky.", "Never trust a snake with wings.", "Coiled in the clouds.",
        "Hiss, flap, zap. Corpse run." },
    hyena = { "Cackle, bite, repeat.", "The pack thought you were funny.", "First come, first eaten.",
        "The last laugh was theirs.", "Hyenas don't share.", "Giggling and gnawing.", "Spotted, then eaten.",
        "The hyena laughed. You didn't.", "Run down by a laughing dog.", "Leftovers." },
    giant = { "Stepped on.", "Big. Very big. Too big.", "You were the size of a giant's foot.", "Squashed like a bug.",
        "Looked up. Too late.", "David lost this time.", "Fee, fi, foe, you.", "Mistook you for a doormat.",
        "Crushed under a walking mountain.", "Small hero, giant problem." },
    yeti = { "Abominable.", "Mauled in the snow.", "Cave dweller, grave filler.", "Frozen, then flattened.",
        "The yeti was real.", "Big hands, no hugs.", "Cold hands, warm grave.", "Grabbed, shaken, dropped.",
        "Fur and fury.", "Yeti, set, go." },
    turtle = { "Shell shocked.", "Slow and steady won.", "Beak like a bear trap.", "Turtle power.",
        "Out-armored by a turtle.", "The turtle was in no hurry.", "Shell 1, sword 0.",
        "Bitten by something slower than you.", "Hard shell, sharp beak.", "Should have walked away. Slowly." },
    crab = { "Pinched.", "Sideways and deadly.", "Clawed by the seafood.", "Dinner fought back.",
        "Cracked the wrong shell.", "Snip snap.", "Shellfish behavior.", "The beach bites.", "Claws out, you out.",
        "Not today, butter sauce." },
    golem = { "Somebody built this to hurt you.", "Stone and steel, no feelings.", "Built to win.",
        "Flattened by engineering.", "Golems don't get tired.", "Out-built.", "A wall that hits back.",
        "Constructed to destroy.", "No off switch.", "The golem wasn't even trying." },
    silithid = { "Bugged.", "Pest control failed.", "Swarmed.", "Too many legs, too many bugs.",
        "Bug spray not included.", "Exoskeleton beats skeleton.", "Chitin and chaos.", "The bug did the squashing.",
        "Stepped on the wrong bug.", "Crawled over." },
    ancient = { "Older than you. Tougher too.", "Old growth, new grave.", "Rooted to the spot. Then flattened.",
        "Picked a fight with a forest.", "Timber.", "Leafed you for dead.", "An old tree with a short temper.",
        "Splinters.", "A whole forest, one bad mood.", "Leaf the ancients alone." },
    owlbeast = { "Hoo did this?", "Half owl, half bear, all angry.", "Bird body, bear arms.", "Feathers and fists.",
        "Mauled by a giant bird.", "Owl be back. You won't.", "Wise? No. Angry? Yes.", "Not the cuddly kind of owl.",
        "Too big for an owl.", "Night owl, bad night." },
    grell = { "Lost to a tiny demon.", "Small, ugly and effective.", "Pestered to death.", "Pint-sized, full of hate.",
        "Gremlin behavior.", "Ugly little nightmare.", "Too small to take seriously. Mistake.", "Demon, pocket sized.",
        "Annoying, then lethal.", "Nibbled." },
    abomination = { "Stitched together, tore you apart.", "Fresh meat.", "Hooked.",
        "Too many arms, all of them on you.", "Smelled the abomination first.", "A patchwork problem.",
        "Bile and bad news.", "Sewn shut. You, that is.", "Big, green and hungry.", "Made of spare parts. Still won." },
    gorilla = { "Gone ape.", "Monkey business.", "Pounded.", "Jungle rules apply.",
        "Silverback. You: flat on your back.", "Went bananas.", "Chest-thumped to death.", "Don't poke the ape.",
        "Out-muscled.", "Didn't monkey around." },
    thunderlizard = { "Thunderstruck.", "Heavy feet, high voltage.", "Zapped by a dinosaur.", "Stomped and shocked.",
        "Storm on legs.", "A lizard that brings the weather.", "Charged.", "Lightning did strike twice.",
        "Never pet a storm.", "Big lizard, bigger bolt." },
    demon = { "Summoned, then unleashed.", "Evil, with extra steps.", "Fel bad, died.",
        "From the Twisting Nether, with hate.", "Your soul looked tasty.", "The Legion thanks you.",
        "Pure evil, pure damage.", "Bad company.", "That was a demon. Should have known.", "Demons don't fight fair." },
    hydra = { "More heads than you.", "Cut one, two bit back.", "All heads on you.", "Every head was angry.",
        "Bitten twice at once.", "Too many mouths.", "A snake with options.", "Head count: not in your favor.",
        "Swallowed whole.", "Multiple bites, one death." },
    chimera = { "Two heads, one goal.", "Bad breath, times two.", "Bitten in stereo.", "One body, two appetites.",
        "Winged and two-faced.", "Left head, right head, dead.", "Doubled over.", "Twice the heads, half the chance.",
        "Both heads agreed on you.", "Both heads saw you coming." },
    cryptfiend = { "Nerubian, and not friendly.", "Dug up something that bit.", "Undead spider, very much alive.",
        "Webbed in a tomb.", "Legs from the grave.", "The crypt had a guard.", "Webs, fangs and a burial.",
        "Entombed.", "Buried, then bitten.", "Up from below, down you go." },
    owl = { "Night vision, killer instinct.", "Taloned.", "Out-witted by a bird.", "Silent wings, sharp claws.",
        "Plucked from above.", "The owl saw everything.", "Wise enough to win.", "Wise and deadly.", "Feathered fury.",
        "Beaked." },
    lasher = { "Whipped by a weed.", "Flower power.", "Weeded out.", "Killer houseplant.", "Thorny situation.",
        "Stopped to smell the flowers. Mistake.", "Lashed.", "Gardening gone wrong.", "Petals and pain.", "Pruned." },
    thresher = { "Bitten in the deep.", "Fish food.", "Thrashed.", "Swim at your own risk.", "Teeth in the water.",
        "Not a fish you can catch.", "Swimming was a mistake.", "Lunch below the surface.",
        "Something big in the water.", "Jaws, the sequel." },
    larva = { "Eaten by a worm.", "A maggot with ambition.", "Lost to a grub.", "Wriggled, then won.", "Maggot food.",
        "Small, soft and somehow deadly.", "Burrowed into.", "The worm turned.", "Grubbed.", "Gross and effective." },
    wyvern = { "Flew like a bird. Stung like a bee.", "Wings, claws and a stinger.", "Lion, bat, scorpion. All angry.",
        "Venom with a wingspan.", "Flying, furry and venomous.", "Winged scorpion. Unfair.",
        "The wyvern was not a taxi.", "Venom from the sky.", "Swooped.", "Tail up means trouble." },
    hippogryph = { "Majestic. Also murderous.", "Landed on you. Hooves first.", "Feathered hooves, heavy hits.",
        "Not the friendly kind.", "Clawed and kicked.", "Hip, hip, game over.", "Pretty wings, mean kick.",
        "Beak and hoof.", "Never surprise a hippogryph.", "Grounded by a flyer." },
    salamander = { "Lava-skinned and angry.", "Scorched by a lizard man.", "Flame waker, you sleeper.", "Molten.",
        "Hot-blooded.", "Burned by a fire lizard.", "Fire walks. You burn.", "Too hot to touch, too mad to stop.",
        "Seared.", "Too hot for armor." },
    plainstrider = { "Pecked to death by a big bird.", "Lost to a chicken on stilts.",
        "Knees backwards, kicks forward.", "Peck, peck, gone.", "Kicked by a bird.", "Feathers up, health down.",
        "The strider ran. You died.", "Tall, feathered, furious.", "Never chase a strider.", "Stilts and spite." },
    gargoyle = { "Pretty ugly. Pretty deadly.", "Ambushed by a statue.", "The gargoyle wasn't decoration.",
        "Dived on.", "Rooftop ambush.", "The statue moved.", "Cold stone, colder hit.", "Swooped from the shadows.",
        "Gargoyles: worse than pigeons.", "Stone cold killer." },
    wight = { "The dead got bigger.", "Wighted down.", "Hulking and hollow.", "Big, dead and angry.",
        "The dead stood up. You lay down.", "Bones and brute force.", "Too big to be this dead.", "Grave mistake.",
        "Dead weight.", "Crushed by the walking dead." },
}
-- Model files (creature/<folder>/*.m2) of each kind's bodies, from Forever's client data (build 70862).
local BODIES = {
    spider = { 124166, 124903, 124904, 126124 },
    wolf = { 126487, 126488, 123388, 123410, 123418 },
    murloc = { 125023, 125024 },
    gnoll = { 124173, 124186, 124192 },
    kobold = { 124691 },
    raptor = { 125559 },
    quilboar = { 125497, 125498, 125499 },
    centaur = { 123170, 123171, 123182, 123194 },
    undead = { 124160, 125942, 125948, 126570, 126571, 234639, 125947, 123120, 124779 },
    ooze = { 125957, 125958 },
    ogre = { 125263, 125264, 125293 },
    dragonkin = { 123543, 123544, 123553, 123554, 123577, 123636, 123610 },
    furbolg = { 124118 },
    naga = { 125078, 125069 },
    satyr = { 125796 },
    bigcat = { 126171, 124781, 124036, 124038, 124052 },
    trogg = { 126239 },
    bogbeast = { 123105 },
    bear = { 123040 },
    harpy = { 124329 },
    earthelemental = { 123747 },
    scorpid = { 125815 },
    boar = { 123090 },
    carrionbird = { 123137 },
    crocolisk = { 123324 },
    kodo = { 124694, 124695, 124696, 124697, 124711 },
    zhevra = { 126320 },
    spirit = { 124155, 123014, 125854 },
    worgen = { 126511 },
    waterelemental = { 126426 },
    fireelemental = { 123934, 1085582 },
    airelemental = { 122877 },
    basilisk = { 123020 },
    windserpent = { 126452 },
    hyena = { 124601 },
    giant = { 124952, 125830 },
    yeti = { 126444 },
    turtle = { 125837 },
    crab = { 123291, 124790 },
    golem = { 124247, 124248 },
    silithid = { 125931, 125892, 125902, 125891 },
    ancient = { 123756 },
    owlbeast = { 123990 },
    grell = { 124272 },
    abomination = { 123961 },
    gorilla = { 124263 },
    thunderlizard = { 126169 },
    demon = { 123878, 123870, 126081, 124637, 123441, 126369, 123348 },
    hydra = { 124581 },
    chimera = { 123205 },
    cryptfiend = { 123329 },
    owl = { 125378 },
    lasher = { 124753 },
    thresher = { 126153 },
    larva = { 124739 },
    wyvern = { 126530 },
    hippogryph = { 124387 },
    salamander = { 125777 },
    plainstrider = { 126117 },
    gargoyle = { 124131 },
    wight = { 126449 },
}
ns.JOKE_BODIES = BODIES
local KIND_OF = {}
for kind, files in pairs(BODIES) do
    for _, file in ipairs(files) do KIND_OF[file] = kind end
end

local probe

-- done(kind), or done(nil) for a mob of no kind here. Its body is saved by NPC ID once known; a model
-- that doesn't answer within a second gives nil and is asked again next time.
function ns.MobKind(npc, done)
    local known = ns.db.mobBodies[npc]
    if known then return done(KIND_OF[known]) end
    probe = probe or ns.UI.CreatureProbe(UIParent, 10)
    probe(npc, function(model) return model:GetModelFileID() end, function(file)
        if file then ns.db.mobBodies[npc] = file end
        done(file and KIND_OF[file])
    end)
end

-- The game gives a skull (10 or more levels above you) as level -1: far above, its number unknown.
local SKULL = -1
local function known(level) return level ~= SKULL and level or nil end

local SCHOOLS = { [2] = "holy", [4] = "fire", [8] = "nature", [16] = "frost", [32] = "shadow", [64] = "arcane" }

-- Every set of lines that fits this death; with none, the cause's own lines.
local function fitting(d, kind)
    local F, sets = ns.FIT_JOKES, {}
    local function take(list) if list then sets[#sets + 1] = list end end
    if d.cause == "mob" then
        take(ns.KIND_JOKES[kind])
        local rank = d.killerRank
        if rank == "elite" or rank == "rareelite" or rank == "worldboss" then take(F.elite) end
        if rank == "rare" or rank == "rareelite" then take(F.rare) end
    elseif d.cause == "player" then
        take(ns.CLASS_JOKES[d.killerClassFile])
    end
    if d.cause == "mob" or d.cause == "player" then
        local gap = known(d.killerLevel) and d.level and d.killerLevel - d.level
        if d.killerLevel == SKULL or (gap and gap >= 5) then
            take(F.higher)
        elseif gap and gap <= -3 then
            take(F.lower)
        end
        take(F[SCHOOLS[d.school]])
        if d.ranged then take(F.ranged) end
        if d.crit then take(F.crit) end
        if d.overkill and d.amount and d.overkill * 2 >= d.amount then take(F.overkill) end
    end
    if d.alive and d.alive < 60 then take(F.short) end
    if #sets > 0 and d.cause == "player" then take(ns.JOKES.player) end
    return sets
end

-- A line whose names can't all be filled in from this death is left out. Of the rest, one shown longest
-- ago (saved by line, across logins). name, kills: who died and how often, when it isn't you.
function ns.Joke(d, kind, name, kills)
    local cause = ns.JOKES[d.cause] and d.cause or "unknown"   -- "other" shares unknown's lines
    kills = kills or d.npc and #ns.Deaths({ npc = d.npc, char = d.char }) or 0
    local fill = { killer = d.killer or ns.DeathTitle(d), kills = d.npc and kills, name = name or (UnitName("player")),
        faction = d.killerFaction, spell = d.spell, amount = d.amount, overkill = d.overkill,
        killerLevel = known(d.killerLevel), level = d.level,
        gap = known(d.killerLevel) and d.level and math.abs(d.killerLevel - d.level),
        alive = d.alive and ns.UI.Count(d.alive, "second", "seconds") }
    local sets = fitting(d, kind)
    if #sets == 0 then sets = { ns.JOKES[cause] } end
    local battle = ns.InBattle()
    local shown, choices, oldest = ns.db.jokesShown, {}, math.huge
    for _, list in ipairs(sets) do
        for _, line in ipairs(list) do
            local when = ns.JOKES_WHEN[line]
            local filled = line:gsub("{(%a+)}", function(k) return fill[k] and tostring(fill[k]) end)
            if (when ~= "repeat" or kills >= ns.NEMESIS_KILLS) and not (when == "world" and battle)
                and not filled:find("{", 1, true) then
                local at = shown[line] or 0
                if at < oldest then choices, oldest = {}, at end
                if at == oldest then choices[#choices + 1] = { line = line, text = filled } end
            end
        end
    end
    local pick = choices[math.random(#choices)]
    if not name then
        ns.db.jokeTurn = (ns.db.jokeTurn or 0) + 1
        shown[pick.line] = ns.db.jokeTurn
    end
    return pick.text
end
