# 2.0.7

### Fixed

- **"A Safer Place" never counted as done on Horde.** The step only knew the
  Alliance version of the quest, so Mrrl's unlock read as incomplete for every
  Horde character who had already done it.
- **The search box overlapped the counters and the portrait** on the default
  look. It has moved into the list column.
- **The Filter button sometimes drew as bare text** with no button behind it.
- Item steps read differently from one session to the next, depending on what
  your client happened to have loaded. They are consistent now.
- The progress counters sit together in the middle rather than at opposite ends
  of the window, and the Filter button no longer shows a number that counted up
  as you narrowed the filter.
- The list scrollbar now reflects how much of the list you are seeing.

### New

- **Search by type.** Typing "pets" or "mounts" in the Guides search now shows
  that type, instead of everything whose notes happen to mention the word.
- **Item steps are clickable.** Substeps that name an item are coloured by its
  quality, show its tooltip on hover, and shift-click drops it into chat. Shift
  now works on the Overview too, alongside Ctrl.
- Opening a merchant in Nazjatar now says whether the Crimson Tidestallion is
  stocked that day, and reminds you to equip the Azsh'ari Stormsurger Cape if it
  is not on — without it the special stock is not listed at all.

Full history: https://github.com/rousseauxy/SecretChecklist/blob/main/CHANGELOG.md
