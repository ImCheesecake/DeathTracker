local _, ns = ...
local R = ns.Recap

local ROASTS = {
    start = {
        { "Spoiler: not well.", function(f) return f.deaths >= 10 end },
        { "Brace yourself.", function(f) return f.deaths >= 10 end },
        { "The Spirit Healer has notes.", function(f) return f.deaths >= 10 end },
        { "It could have been worse.", function(f) return f.deaths < 10 end },
    },
    count = {
        { "Practice makes worse.", function(f) return f.diff and f.diff > 0 end },
        { "Going for a record?", function(f) return f.diff and f.diff > 0 end },
        { "Growth. Slow, but growth.", function(f) return f.diff and f.diff < 0 end },
        { "Consistent, at least.", function(f) return f.diff == 0 end },
        { "A strong start. For the Spirit Healer.", function(f) return f.first end },
    },
    worst = {
        { "Should have logged off after the third.", function(f) return f.deaths >= 4 end },
        { "Some days the graveyard is just closer." },
        { "The Spirit Healer knew you by name." },
        { "That's not a bad day. That's a lifestyle.", function(f) return f.deaths >= 9 end },
    },
    most = {
        { "{name} carried the team. To the graveyard." },
        { "{name} took one for the team. {deaths} times.", function(f) return f.deaths >= 2 end },
        { "{name} did most of the dying. Teamwork.", function(f) return f.half end },
        { "{full}: the team's designated corpse." },
    },
    life = {
        { "A personal best. It didn't last." },
        { "Blink and you missed it.", function(f) return f.seconds < 3600 end },
        { "Long enough to get comfortable. Big mistake.", function(f) return f.seconds >= 3600 end },
    },
    nemesis = {
        { "{killer} has a favorite. It's you." },
        { "{killer} is starting to enjoy this." },
        { "{kills} kills. {killer} is keeping count. So are we." },
        { "Not a fight. A routine." },
    },
    roadCount = {
        { "The graveyard kept a seat for you.", function(f) return f.deaths >= 50 end },
        { "That's a lot of corpse runs.", function(f) return f.deaths >= 20 end },
        { "Level {level} was a bad time.", function(f) return f.worst >= 3 end },
        { "Careful. Mostly.", function(f) return f.deaths < 20 end },
    },
    first = {
        { "Everyone starts somewhere. You started early.", function(f) return f.level <= 5 end },
        { "It took a while. Then it didn't.", function(f) return f.level >= 10 end },
        { "{killer} got there first." },
    },
    zone = {
        { "{zone} wants you back. Don't go." },
        { "Never going back to {zone}." },
    },
    type = {
        { "Wear it with pride." },
    },
    dead = {
        { "That's a lot of walking." },
        { "The Spirit Healer saw more of you than your guild did." },
    },
    friends = {
        { "Leading from the front. The graveyard front.", function(f) return f.half end },
        { "Somebody has to make them look good.", function(f) return f.half end },
        { "Your friends could learn a thing or two from you.", function(f) return not f.half end },
    },
    none = {
        { "Who are you, and what have you done with the real you?" },
        { "The Spirit Healer misses you." },
        { "Suspicious." },
    },
}
R.ROASTS = ROASTS

function R.RoastChoices(pool, facts)
    local out = {}
    for _, entry in ipairs(ROASTS[pool]) do
        local when = entry[2] --[[@as fun(f: table): boolean?]]
        if not when or when(facts) then
            out[#out + 1] = (entry[1]:gsub("{(%a+)}", function(k) return facts[k] and tostring(facts[k]) end))
        end
    end
    return out
end

function R.Roast(pool, facts)
    local choices = R.RoastChoices(pool, facts)
    return choices[1] and choices[math.random(#choices)] or nil
end
