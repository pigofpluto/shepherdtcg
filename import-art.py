#!/usr/bin/env python3
"""
Import card art into Assets.xcassets.

Usage:
    python3 import-art.py            # defaults to ./Art/Cards
    python3 import-art.py <folder>   # or any other folder

Drop card art into Art/Cards and run this. Files are matched to cards either by
exact card id (`h_samson.png`) or by a friendly alias (`samson.png`, `youngdavid.png`
— see ALIASES below). Each match becomes an `<id>.imageset` in Assets.xcassets.
Re-run any time; it overwrites cleanly and reports which cards still need art.

Then rebuild (`xcodegen generate && open BibleTCG.xcodeproj`) — the art replaces
the procedural placeholders automatically, with no code change.
"""

import sys, os, json, shutil

# The card ids (must match Services/CardLibrary.swift).
CARD_IDS = [
    # Creatures
    "sparrow","tide-pool-crab","raven","minnow-shoal","locust","wild-boar",
    "golden-jackal","owl","river-otter","stone-ram","lion","eagle","great-fish",
    "behemoth-calf","serpent","whale","griffin-vulture","kraken","great-bear","leviathan",
    # Humans
    "shepherd-boy","field-hand","watchman","young-scribe","herald","farmer","elder",
    "soldier","fisherman","physician","priest","judge","centurion","craftsman",
    "kings-guard","prophet","warrior-chief","high-priest","champion","anointed-king",
    # Relics
    "watchtower","ark-of-the-covenant","altar-of-fire","fish-net","shepherds-staff",
    "scroll-of-wisdom","banner-of-courage","shield-of-strength",
    # Events
    "the-great-flood","plague-of-locusts","the-red-sea","walls-of-jericho",
    "the-fiery-furnace","the-lions-den","the-great-storm","tower-of-babylon",
    "the-whales-belly","the-tribulation",
    # Restored named humans
    "h_solomon","h_moses","h_daniel","h_abraham","h_joseph","h_paul","h_deborah",
    "h_isaiah","h_eve","h_magi","h_david","h_joshua","h_gideon","h_esther",
    "h_elijah","h_peter","h_baptist","h_matthew","h_samson","h_goliath",
    "h_benaiah","h_caleb","h_jael","h_nehemiah",
    # Restored named animals
    "ant","dove","lamb","donkey","camel",
]

VALID_EXT = {".png", ".jpg", ".jpeg"}
HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "Assets.xcassets")

# Friendly filename aliases → card id, so you can name files by character/topic
# instead of the internal id. Keys are matched loosely (case/space/punctuation
# insensitive). A file already named after a card id always works too.
ALIASES = {
    # creatures (exact or thematic)
    "lion": "lion", "locust": "locust", "locusts": "locust",
    "leviathan": "leviathan", "fish": "great-fish", "greatfish": "great-fish",
    "sparrow": "sparrow", "raven": "raven", "eagle": "eagle", "serpent": "serpent",
    "whale": "whale", "kraken": "kraken", "owl": "owl", "bear": "great-bear",
    "greatbear": "great-bear", "wildboar": "wild-boar", "boar": "wild-boar",
    "crab": "tide-pool-crab", "minnow": "minnow-shoal", "jackal": "golden-jackal",
    "otter": "river-otter", "ram": "stone-ram", "calf": "behemoth-calf",
    "vulture": "griffin-vulture", "griffin": "griffin-vulture",
    # restored named humans — character art maps to its named card
    "samson": "h_samson", "youngdavid": "h_david", "david": "h_david",
    "daniellions": "h_daniel", "daniel": "h_daniel",
    "queenesther": "h_esther", "esther": "h_esther",
    "evegarden": "h_eve", "eve": "h_eve",
    "isaiah": "h_isaiah", "matthew": "h_matthew",
    "3wisemen": "h_magi", "threewisemen": "h_magi", "wisemen": "h_magi", "magi": "h_magi",
    "petersword": "h_peter", "peter": "h_peter",
    "johnthebaptist": "h_baptist", "baptist": "h_baptist",
    "solomon": "h_solomon", "moses": "h_moses", "abraham": "h_abraham",
    "joseph": "h_joseph", "paul": "h_paul", "deborah": "h_deborah",
    "joshua": "h_joshua", "gideon": "h_gideon", "elijah": "h_elijah",
    "goliath": "h_goliath", "benaiah": "h_benaiah", "caleb": "h_caleb",
    "jael": "h_jael", "nehemiah": "h_nehemiah",
    # restored named animals
    "anthill": "ant", "ant": "ant", "dove": "dove", "lamb": "lamb",
    "donkey": "donkey", "camel": "camel",
    # relics
    "ark": "ark-of-the-covenant", "arkofthecovenant": "ark-of-the-covenant",
    "watchtower": "watchtower", "altaroffire": "altar-of-fire", "altar": "altar-of-fire",
    "fishnet": "fish-net", "net": "fish-net",
    "staff": "shepherds-staff", "shepherdsstaff": "shepherds-staff",
    # events
    "flood": "the-great-flood", "greatflood": "the-great-flood",
    "redsea": "the-red-sea", "jericho": "walls-of-jericho", "wallsofjericho": "walls-of-jericho",
    "lionsden": "the-lions-den",
    "fieryfurnace": "the-fiery-furnace", "furnace": "the-fiery-furnace",
    "plagueoflocusts": "plague-of-locusts", "greatstorm": "the-great-storm",
    "towerofbabylon": "tower-of-babylon", "babylon": "tower-of-babylon",
    "whalesbelly": "the-whales-belly", "tribulation": "the-tribulation",
}


def normalize(stem: str) -> str:
    return "".join(c for c in stem.lower() if c.isalnum())


def resolve_id(stem: str):
    """Map a filename stem to a card id, or None if it matches nothing."""
    if stem in CARD_IDS:
        return stem
    return ALIASES.get(normalize(stem))


def main():
    # Default to the repo's own art library.
    src = os.path.expanduser(sys.argv[1]) if len(sys.argv) > 1 \
        else os.path.join(HERE, "Art", "Cards")
    if not os.path.isdir(src):
        print(f"Source folder not found: {src}")
        sys.exit(1)
    if not os.path.isdir(ASSETS):
        print(f"Assets.xcassets not found next to this script (expected {ASSETS}).")
        sys.exit(1)

    imported, unknown = [], []

    for fname in sorted(os.listdir(src)):
        stem, ext = os.path.splitext(fname)
        if ext.lower() not in VALID_EXT:
            continue
        card_id = resolve_id(stem)
        if card_id is None:
            unknown.append(fname)
            continue

        imageset = os.path.join(ASSETS, f"{card_id}.imageset")
        os.makedirs(imageset, exist_ok=True)
        # Clear any prior image files in this imageset, then copy the new one.
        for old in os.listdir(imageset):
            if os.path.splitext(old)[1].lower() in VALID_EXT:
                os.remove(os.path.join(imageset, old))
        dest_name = f"{card_id}{ext.lower()}"
        shutil.copy2(os.path.join(src, fname), os.path.join(imageset, dest_name))

        with open(os.path.join(imageset, "Contents.json"), "w") as f:
            json.dump({
                "images": [{"filename": dest_name, "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1},
            }, f, indent=2)
        imported.append(f"{card_id}  ({fname})" if normalize(stem) != card_id else card_id)

    have = {d[:-len(".imageset")] for d in os.listdir(ASSETS) if d.endswith(".imageset")}
    missing = [c for c in CARD_IDS if c not in have]

    print(f"Imported this run: {len(imported)}")
    for c in imported:
        print(f"  + {c}")
    if unknown:
        print(f"\nSkipped (name doesn't match any card id): {len(unknown)}")
        for u in unknown:
            print(f"  ? {u}")
    print(f"\nArt present: {len(CARD_IDS) - len(missing)}/{len(CARD_IDS)}")
    if missing:
        print(f"Still missing ({len(missing)}):")
        print("  " + ", ".join(missing))
    else:
        print("All 57 cards have art. Rebuild the app.")


if __name__ == "__main__":
    main()
