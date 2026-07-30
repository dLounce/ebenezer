# Ebenezer — submission writeup

**Scripture becomes geography.**

Roblox has around 80 million people in it every day, most of them nine to
sixteen — the exact audience YouVersion has the hardest time reaching, and the one
place where nothing faith-shaped exists that does not feel bolted on. Ebenezer
does not put a Bible app inside a game. It makes Scripture part of the ground.

When something real happens to a player — they die for the fifth time in the same
spot, they survive their first night with nobody else online, they come back after
a long stretch of failing at something — a stone rises out of the ground at those
exact coordinates with a verse cut into it. The verse is chosen for that moment,
and it appears in that player's own language without anyone selecting one.

Then it stays. The stones are public and they persist, so weeks later a different
player walks through that valley and finds one. They do not know whose night it
was. They only know that someone was here, and that this is what they needed to
read. The map slowly fills with other people's moments. Scripture stops being
broadcast and becomes something you come across — which is closer to how it
actually reaches people.

The mechanic is not invented. Roblox and Minecraft have already trained a hundred
million kids to stop and read found text in a world: lore books, engraved signs,
messages left by strangers. Ebenezer uses a reading habit that already exists
rather than asking for a new one.

**How the two APIs divide the work is the heart of the build.** Gloo AI reads the
emotional shape of a gameplay event and *selects* one passage reference out of a
curated pool of 35. It never writes text. YouVersion then supplies every actual
word, from a licensed translation, in the player's own language. If Gloo returns
anything outside the pool, the answer is discarded and a fallback reference is
used. The model's entire output surface is one reference and a theme label, which
means a twelve-year-old cannot be shown a hallucinated verse, a misattributed
verse, or anything unvetted — because the model is never the source of text. On a
platform full of children that is not a nice-to-have; it is the design.

Twelve languages ship, each verified against a live key rather than trusted from
the catalogue. `Player.LocaleId` routes automatically, and YouVersion returns the
reference already localized, so a Japanese player reads 詩篇 139:7-10 rather than
"Psalms". Russian and Korean were deliberately cut: the only entitled Russian text
is Church Slavonic, which reads like ritual language from another century to a
Russian kid, and Korean returns 403 despite appearing in the catalogue. English is
the Free Bible Version, chosen over KJV for a nine-to-sixteen reading level.

Technically it is a Roblox place calling a FastAPI service over HttpService.
Moment detection runs on real engine events, Gloo selection and YouVersion
retrieval run server-side behind a shared secret, stones persist in Roblox
DataStore with a backend mirror so a freshly booted server can repopulate a world
it has never seen, and a live web map at `/map` lets anyone watch the world fill
up without entering the game. Generative AI is disclosed to Roblox as *Limited*:
every Gloo call is stateless, no user context is ever loaded back into the model,
and nothing the model writes is stored, because the model never writes anything.

A stone left in a shared world is a conversation rather than a broadcast. That is
the point, and it is only possible because the world is persistent, public, and
already full of people.
