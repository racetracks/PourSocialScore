POUR SOCIAL SCORE AND CHAT SPAM FILTER
Version 2.0.34 - by Boaties

Pour Social Score is a quality-of-life addon with an unlimited, account-wide
ignore list, a guild ignore list, and a chat/spam filter engine. It removes
gold sellers, boosting spam, guild and community recruitment, non-latin text
and anything else you write a filter for. Built with the WoW API only (no
libraries).

Type /pss gui (or open your Friends window) to open the interface, and /pss
for the chat command list.


== FEATURES

Player Ignore List
* Unlimited size, shared across all your characters, factions and servers
* Ignore players, NPCs and whole servers
* Notes and expiry times (entries remove themselves after N days)
* Per-player exclusions W I G P C (see EXCLUSIONS below)
* Character names with a space ("First Last-Realm") are supported
* Per-player overrides for ignore response, declines, duels and trades
* Player detail window: double-click an entry (see THE WINDOWS below)
* Warnings when you invite, or are grouped with, someone on your list
* Automatic decline of duels, trades and party invites from ignored players
* Ignore from right-click menus on targets, raid frames and the LFG list

Guild Ignore List
* Ignore whole guilds. Members are captured by guild Scan (a /who sweep of
  the guild, one search per click: the whole guild first, then every answer
  capped at 50 is split by level bracket, class and single level until each
  search is under the cap), Scan All (the same sweep across every guild row,
  A-Z; also on a key binding), Custom Scan (your own /who filter;
  Scan Fields start as 1-60), guild invites, and any /who you run yourself
  whose results include members of a saved guild. Each scan reports in chat
  how many players it found and captured.
* Per-guild exclusions W I G P C, and the same W I G P C on every member so
  you can opt each player in or out individually; members also get a note
* Default guild lists (read only): groups of guilds shipped with the addon
  (PSS_GuildIgnore_Managed.lua), e.g. "Olympus". Each group has a guild rule
  on the Chat Filters tab (e.g. "Influencer Guilds - Asmongold",
  InfluencerGuild=Olympus) that switches the whole group on or off - off by
  default, like every built-in filter - and a collapsible entry on the Guild
  Ignore List with its guilds and their members. Shipped guilds can't be
  removed; their W I G P C exclusions, Scan Fields and scans work like any
  guild. Only your changes are saved: members your scans find that aren't
  in the shipped list (kept in the group), shipped members you edit or that
  have block history, and shipped members that left the guild.
* Guild Search: /who for part of a guild name and add any guilds it finds;
  everyone the search saw in a guild you add becomes a member of its rule
* Block counters per guild and per type, with full block history

Chat Filters
* Built-in filters for the most common spam (read only; turn them on or off,
  or copy one to make your own version)
* Write your own filters with tags and and/or/not logic (see HOW TO CREATE
  CHAT FILTERS below), test them against sample text, and view what each
  filter has blocked

Also
* Every list can be sorted by any column, and every column can be resized:
  drag the right edge of a column header (right-click the edge to reset).
  Widths are remembered.
* Links in Block History messages (items, recipes, professions, spells,
  achievements...) work like in chat: hover for the tooltip, click to open,
  shift-click to paste into chat
* Import/Export of your lists, filters and options as a text string
* Light on the game: chat filters are compiled once, every list lookup is
  O(1), nothing is scanned in combat, and memory is tidied up in small
  steps (never a full collection) after login, a /who scan, an import or
  closing the window, and otherwise every 10 minutes. Never in combat,
  within 5 minutes of leaving combat, or inside a dungeon, raid,
  battleground or arena. /pssguild status shows the cleanup state.
* Block history is ONE shared log of the last 2,000 blocked lines across
  every player, guild member and chat filter (Options > "Block history lines
  kept in total" 100-20000). Memory has a hard ceiling however many people
  you block: about 0.7 MB at 2,000 lines. The views (a player, a guild, a
  member, a filter, "all ...") are filtered from the log; the blocked counts
  are totals kept per person/filter and are never cut. A player's lines
  follow them when they are moved to another guild rule.
  When a person's lines leave the log, each player and guild member still
  keeps their newest 10 chat lines, 5 emotes, 5 party invites and 5 guild
  invites (moved, not copied, so nothing is stored or counted twice). Their
  history shows those together with any lines still in the log.
  /pss mem shows what the addon is using (/pss mem full: who has the most
  history lines).
* Options apply to every character on the account; some can also be set
  per guild or per player


== EXCLUSIONS: W I G P C

The same five tickboxes appear on the Player Ignore List, on each guild of
the Guild Ignore List, and on each member in a guild's members window.
Ticked = ALLOWED from that player / guild / member; unticked = blocked.
Adding a player or a guild to a list opts them IN to blocking: everything
from them is blocked. The boxes are per-player / per-guild EXCLUSIONS from
that, so they start unticked; tick one to let that one thing through.
(Built-in chat filters are different: each one starts off, tick the ones
you want.)

By default PSS does all the blocking itself and leaves Blizzard's ignore
list alone. Option "Also put listed players on Blizzard's ignore list" (off
by default) syncs them to it as well - but Blizzard's list blocks everything
and ignores these exclusions. The "You are being ignored" auto-reply is also
off by default.

  W  Whispers (including Battle.net whispers)
  I  Party invites (auto-declined)
  G  Guild invites (auto-declined)
  P  Party/Raid chat, including raid warnings, instance and battleground chat
  C  Chat channels (Trade, General, LFG, community channels) and public
     chat (say, yell, emotes)

Guild members follow their guild's tickboxes until you change one: a dimmed
box is following the guild; click it to set it for that player (ticked or
not), right-click it to go back to the guild's setting. A member can be
blocked even when their guild has every box ticked (allowed).

Upgrading from 2.0.3 or earlier keeps existing behaviour: C starts unticked
(public chat was always blocked), the old guild Filter / Guild Inv / Group
Inv boxes and the members' Allow boxes are converted automatically.


== THE WINDOWS

Block metrics - the blocked counts per type (Whispers, Party Invites,
Party/Raid, World Chat, Guild Invites) - look the same wherever a player or
guild is reported on: as columns on the Player Ignore List, the Guild Ignore
List and the guild members window, and as a small table (plus Total) at the
top right of the player detail, guild members and Block History windows.
Every metrics column sorts.

Every page and window shares one design (the Player Ignore List's): a
summary at the top (title, total, per-type breakdown), Blizzard-style column
headers, 20-pixel rows that highlight on hover and stay highlighted when
selected, and the buttons on the bar under the panel. Wherever W I G P C
appears it is the same header and the same tickboxes.

All windows can be moved by dragging and resized with the grip in their
bottom-right corner. Right-click the grip to reset a window to its default
size. Sizes are remembered.

Main window tabs: Player Ignore List, Guild Ignore List, Chat Filters,
Import/Export, Options.

Sorting works the same on every list: click a column header to sort by it,
click it again to reverse the order. An arrow shows the sorted column. Ties
are ordered by name, A-Z.

Player Ignore List
  Opens sorted by name, A-Z; any column can be sorted, including each of
  W I G P C. Click a player then Block History to see their history (with
  no player selected you see every player's history, newest first).
  Double-click an entry (or right-click > Details and note) to open the
  player detail window: details, guild info, expiry, note, exclusions,
  overrides, block counts and history, Add Guild for their current guild,
  and Remove.

Guild Ignore List
  Opens sorted by guild name, A-Z. The Whispers / Party Invites /
  Party/Raid / World Chat / Guild Invites columns are the guild's block
  metrics; W I G P C are the guild's exclusions. Click a guild, then Remove Guild or Block History on the bar;
  double-click a guild to open its members window. Right-click a guild for
  more options. Removing a guild rule removes its captured members only;
  your Player Ignore List is never changed by it.

Guild members window
  Each member has their own W I G P C (dimmed = following the guild). Click
  a member, then Remove Member or Block History on the bar (no member
  selected = the whole guild's history); double-click a member for their
  history; right-click for per-player overrides.

Chat Filters
  Built-in filters always stay at the top; each group is sorted by the
  chosen column (Description A-Z by default). Double-click a filter to edit
  it (built-in filters open read only). Click a filter then Block History
  to see what it blocked. Right-click for on/off, copy, remove, block
  history and reset counts.

Block History (the same on every list)
  Players, guilds (per member) and chat filters all keep the same history:
  time, player, type (W I G P C category), channel and message, newest
  first, the last 100 lines each, plus counts per type. Block History
  shows it in place of the list: with something selected you see only
  that player / guild / filter, otherwise everything. On the bar: Close,
  Reset Block History (clearing everything asks first), All Players /
  All Guilds / All Filters, and Player Details / Show Members / Edit
  Filter. Every column sorts; hover a line for the full message and where
  it came from; right-click a line to add the sender to (or remove them
  from) the Player Ignore List.

Removing
  Removing a player, guild, guild member or NPC/server entry happens
  straight away - there is no confirmation. Prune asks only how many days.


== NOTES AND KNOWN LIMITATIONS

* Guild rules only block characters PSS has captured (by a scan or a guild
  invite). Blizzard does not include a sender's guild in chat messages, so
  an uncaptured member of an ignored guild is not recognised until a scan
  finds them. /pssguild check Name-Realm shows whether a character is stored.

* /who is hardware-event protected, so guild scans only run from a real
  button click or key press (Key Bindings > AddOns > Pour Social Score >
  Scan All), and all scan buttons share a short cooldown. Hover a Scan
  button for the sweep status: searches sent and queued, players found and
  captured, the next search, and when the next click is allowed.

* /who returns at most 50 players. Scan splits a capped answer on its own;
  a search that is still capped at one level and one class is reported in
  the tooltip ("still capped"). Custom and the Scan Fields remain for any
  filter of your own (e.g. 85-90, or 90 c-"Mage").
  Only players who are online and visible to /who can be captured.

* Options > Whois Scan Options > Enable scan level cap (with the cap in the
  field next to it, required to tick it): no scan searches above that level.
  Scan and Scan All search 1-cap first and stop their level brackets at the
  cap; Custom and Guild Search have their levels cut to the cap (or get
  1-cap added when they have none).

* Character names that contain a space ("First Last-Realm") are supported
  everywhere: Add Player, Player Search, /pss add, remove and expire, and
  chat blocking. Spaces inside the realm are ignored ("Area 52" = "Area52").

* WoW sometimes reports every ignore list entry as "Unknown" during login,
  which stops PSS synchronising your character's ignore list. If that
  happens PSS prints a message and syncs again when you open the interface.
  You can also run /pss sync.

* When you ignore someone from chat, WoW does not always report their server.
  PSS checks your group, raid and recent chat to find it, and otherwise
  assumes they are on your server.

* Blizzard's own ignore list holds 50 entries per character. PSS fills it
  with the best 50 for each character, so account-wide blocking (their alts
  too) covers the people most likely to matter, and blocks everyone else
  itself.


== HOW TO CREATE CHAT FILTERS

PSS ships with built-in filters that are updated as new spam turns up, and
lets you create your own. Every built-in filter starts off - tick the
ones you want on the Chat Filters tab. They include "Filter Asmon"
([contains=asmon]) and "Filter Olympus" ([word=olympus]). Create, copy and remove filters with the buttons
on the Chat Filters tab; double-click one to edit it.

A filter is made of tags in square brackets that describe what to look for
in a chat message. When the filter as a whole is TRUE, the message is
hidden. Tags can be combined with logic (see USING LOGICAL EVALUATION).

[word]

The word tag looks for a whole word within the chat message. The word to search
for must be provided within the tag with an equals sign such as: "[word=anal]".

Word and partial word matches are case insensitive, so ANAL anal and AnAL will
all match the tag shown above. Punctuation at either end of a word is
ignored, so [word=olympus] also matches "<Olympus>", "(olympus" and
"Olympus!", but not "OlympusTycoons".

[contains]

The contains tag is similar to the word filter, but performs a partial match of
a word instead of a whole word match. If for example, you see people spamming
analanalanal [Thunderfury], then you might want to add a tag with something like
[contains=analan] so that it will catch people who do that sort of spam.

[link]

The link tag matches if the chat contains any linked content at all, which can
mean a spell, item, achievement, etc.

[spell]

The spell tag allows one to filter out specific spell links or all spell links
from chat. If the spell tag exists with no equals, then it will filter when
the message contains ANY spell link at all. For example "[spell]". If the
equals sign is provided and followed by a Spell ID, then only that specific
spell ID will be filtered. Such as "[spell=17]" would filter any message with
the Power Word Shield spell linked in it.

[item]

The item tag allows one to filter out all item links or specific item links.
This tag works in the same way that the spell tag does. For example "[item]"
will filter if any item at all is linked, whereas "[item=19019]" would filter
any chat message that contained a link for Thunderfury.

[talent]

The talent tag works just the same as the spell and item tags.

[achievement]

The achievement tag works just the same as the spell and item tags. See the item and spell examples above.

[pet]

The pet tag works just the same as the spell and item tags. See the item and spell examples above.

[icon]

The icon tag allows filtering based on raid icons in the chat text. The
"[icon]" tag by itself will result in a filtered message if the chat message
has any icon at all in the text. A number can also be provided to filter
based on if a message has a specific number or greater of raid icons. For
example "[icon=3]" would filter if the message has 3 or more raid icons in
it.

[community]

This tag allows filters to be created to filter out community Join requests.
No other data is used for this tag; If you wish to filter anything that
contains a Join request, simply include this tag

[trade]

This tag allows filters to be created to filter out tradeskill links.
No other data is used for this tag; If you wish to filter anything that
contains a tradeskill link, simply include this tag.

[journal]

This tag allows filters to be created to filter out dungeon journal links.
No other data is used for this tag; If you wish to filter anything that
contains a journal link, simply include this tag.

[mount]

This tag allows filters to be created to filter out mount links.
No other data is used for this tag; If you wish to filter anything that
contains a mount link, simply include this tag.

[guild]

This tag allows filters to be created to filter out guild links.
No other data is used for this tag; If you wish to filter anything that
contains a guild link, simply include this tag.

[outfit]

This tag allows filters to be created to filter out outfit links.
No other data is used for this tag; If you wish to filter anything that
contains an outfit link, simply include this tag.

[nonlatin]

This tag filters messages that contain Chinese/Japanese/Korean characters
for those who play on English servers that have a strong native Asian speaking
community

[cyrillic]

This tag filters messages that contain Cyrillic letters (Russian, Ukrainian,
Belarusian, Bulgarian, Serbian, Kazakh ...). It also catches English spam
that swaps in Cyrillic lookalike letters to get past word filters
("sellіng" with a Cyrillic "і"). [cyrillic=3] only matches when there are at
least 3 Cyrillic letters, which lets a single stray lookalike through.
The built-in rule "Filter Cyrillic (Russian etc.)" uses [cyrillic] and is
off by default.

[words]

This tag allows filters to test that a line of text contains only a specific number
of words.  For example: [words=2] would be true only if the text contained only two
words.

[channel]

This tag allows filters to test that a line of text sourced from a specific channel
number.  For example, channel 1 would be zone, 2 would be city/trade, and so on.  If
you wanted a filter to apply only to trade chat you could do "[channel=2]" somewhere
in your filter.

[chname=name]

This tag allows filters to test that a line of text sourced from a specific channel
name.  When the text sourced from a channel that does not have a chat channel name
PSS will set the name to a value that corresponds to the type of chat it is, as
follows:  say, yell, whisper, officer, guild, party, raid, raid_leader,
instance_chat, instance_chat_leader, battleground, battleground_leader.

As with other filter tags, spaces must be escaped with the backslash character. For
example to create a filter that only applies to Trade chat you would use a tag with
the spaces escaped: [chname=Trade\ -\ City].  If you want to apply a filter only to guild
chat you would use [chname=guild].

The "Never filter party, guild, yourself, private messages" options still apply here,
so if those are enabled even a filter with a channel name will not apply to those
channels as they are configured to never be filtered.

== SPECIAL CHARACTERS IN FILTERS

Spaces can be used in a [Contains] tag by escaping the character with a backslash
before the space (\).  Other characters can be escaped the same
way: parenthesis (), brackets [], and backslash.  For example:

  [contains=filter\ this]

Here are some other examples:

   \( would mean (
   \) would mean )
   \[ would mean [
   \] would mean ]
   \\ would mean \

== USING LOGICAL EVALUATION

Chat filters can include some logical evaluations by enclosing tags within
parenthesis and using boolean "and or not" keywords. This is really what can
tie everything together and allow for some pretty nice filters to be created.

For example, here is the built-in "Anal" spam filter:

([word=anal] or [contains=analan]) and ([link] or [words=2])

The message is filtered when it contains the whole word "anal" OR the partial
match "analan", AND it either contains a link (item, spell, achievement and
so on) OR is exactly two words long.

Order: "not" is applied first, then "and", then "or" - the usual order. So

[word=a] or [word=b] and [word=c]

means [word=a] or ([word=b] and [word=c]). Writing two tags side by side with
no keyword means "and". Use brackets whenever you mix "and" with "or" to make
the meaning obvious. (Before 2.0.9 "or" was applied before "and", so a custom
filter that mixes them without brackets may now behave differently.)


== CHAT COMMANDS

/pss                      Show the command list
/pss gui                  Open the interface (also /pss ui)
/pss list [days|server]   List entries; optionally only those listed for
                          [days] or more, or from one server
/pss add name [days] [note]
                          Add a player (also /pss ignore), e.g.
                          /pss add mytoon-Area52 30 spams trade
                          A name with a space needs its realm or quotes:
                          /pss add John Smith-Area52 note
                          /pss add "John Smith" note
/pss remove name|number   Remove an entry by name or by its /pss list
                          number (also /pss delete)
/pss expire name days     Remove [name] automatically after [days]
                          (names with a space work the same way as add)
/pss defexpire days       Default expiry for newly ignored players (0 = never)
/pss prune days           Remove everyone listed for [days] or more days
                          (straight away)
/pss npc name             Add or remove an NPC ignore
/pss server name          Add or remove a whole-server ignore
/pss sync                 Synchronise the ignore list now
/pss mem [full]           Memory: addon total, block history lines / cap and
                          size, list sizes, shipped guild index, cleanup
                          state; "full" adds the top 10 history owners
/pss showmsg on|off       Print what happens during synchronisation
/pss sameserver on|off    Only sync same-server characters to Blizzard's
                          ignore list
/pss asknote on|off       Ask for a note when ignoring someone
/pss clear                Clear the whole list on every character (asks you
                          to confirm with /pss clear confirm). You may need
                          to clear on each character, or PSS will re-add
                          entries from that character's Blizzard list.

Guild diagnostics:

/pssguild                 Status: filter registered, lines checked and
                          hidden this session, and each guild rule
/pssguild test Name-Realm Dry run: would this character be blocked, and why
                          (or target them and type /pssguild test)
/pssguild check Name-Realm Is this character stored under a guild rule?
/pssguild chat            Check the chat pipeline and other chat addons
/pssguild debug [all]     Report chat lines from listed people (all = every
                          line checked, for 2 minutes)


== VERSION HISTORY

See history.txt.
