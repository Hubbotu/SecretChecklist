# Changelog

## 2.0.5

- **The Russian interface is now complete.** Every button, tab, tooltip and
  setting is translated — thanks again to ZamestoTV.

## 2.0.4

- **Mounts now use the name your Mount Journal shows.** On a non-English client
  they were the only category left in English — pets, toys and appearances were
  already translated. A few English names change as a result (Blanchy's Reins is
  now Sinrunner Blanchy), and the Overview sorts by the new names.
- **The theme and Guides tab style settings are translatable**, including the
  individual options. They were English on every client before.
- **The addon's website and bug-report links now work.** Both pointed at a
  repository that no longer exists, so anyone trying to report something from
  the CurseForge or Wago page hit a dead end.
- **The "a group member has a newer version" notice works again.** It had been
  misreading its own version number since it was added, so on most releases it
  simply never fired.

Thanks to ZamestoTV for the Russian translation and for reporting the
localisation gaps, and to claytonkimber for the dead links.

## 2.0.3

- **Radiant Singer** now says up front that you need the Gift of Oddsight buff:
  without it the Divine Flame cannot be targeted at all. The raid-setup step
  explains where the buff comes from and that only one person in the raid needs
  to own the item.

## 2.0.2

- **The Beledar assignment popup now matches your UI theme** instead of using
  a plain tooltip background, and follows ElvUI or EllesmereUI when you use
  them.
- Tidier layout: the title no longer overlaps the "via SecretChecklist" label,
  the close button sits properly in the header, and the emote button is easier
  to hit.
- The popup remembers where you drag it.

## 2.0.1

- **Fixed an error that fired every time you changed target**, introduced in
  2.0.0. It also tainted execution, which can cause problems in other addons
  and in Blizzard's own interface. Please update.

## 2.0.0

A large maintenance release. Everything below is something you can see or use.

### New

- **Search box in the Guides tab.** Finds a secret by its name, its zone, or
  anything mentioned in its steps — searching "Kosumoth" or "Tazavesh" works as
  well as searching the item name.
- **The whole Overview row is clickable**, not just the icon. Clicking a
  secret's name used to do nothing.
- **Checkmark and cross icons** for collected and missing, so status no longer
  depends on telling red from green.
- **The window remembers where you put it.** Dragging it worked before, but the
  position was forgotten on every reload.
- **EllesmereUI theme** now marks collected secrets with the same gold border
  the other themes use, instead of leaving them looking identical to missing
  ones.
- **Guide content can be translated**, not just the interface. Step
  instructions, notes and descriptions are all translatable now — see the
  README if you would like to help with a language.
- `/secrets help` lists every command, and `/secrets validate` checks the
  secret data for problems.

### Fixed

- **A Lua error on every login.** It also silently disabled the Beledar
  Orchestra helper entirely.
- **Browsing the checklist reset your Collections journal filters.** If you had
  the Mount Journal set to "Not Collected", paging through the Overview quietly
  cleared it.
- **Steps stayed red after you claimed the reward.** Pet, mount and appearance
  steps checked your bags for an item that is consumed the moment you use it —
  Unfazed Diver's final step, for one. Steps for equipped gear had the same
  problem: equipping the item made the step go red.
- **Achievement tooltips stuck on "Retrieving data".**
- **Step notes did not reopen** after collapsing and expanding the progress
  list, and took two clicks to close afterwards.
- **Steps with only a waypoint** were drawn with a large empty gap above the
  button.
- **The Guides tab style setting** was forgotten on every reload.
- **Setting a waypoint inside a dungeon** could throw an error if you do not
  have TomTom. It now explains itself instead. Steps with several waypoints say
  so rather than silently placing only the first.
- **The About tab's copy box** showed the Discord link even when you had
  clicked the Warcraft Secrets one.

### Under the hood

Faster to load and lighter on memory, especially the Guides tab, and a good
deal of old code removed. None of this changes how the addon behaves.
