#!/usr/bin/env python3
"""
Check Resources/cards.json against Services/CardLibrary.swift.

CardLibrary.swift is the live card set (87 cards) and is what actually runs.
cards.json documents the starter set (55) and is kept in sync by hand — this
script tells you where the two have drifted.

    python3 check-card-sync.py

Every id in cards.json must exist in CardLibrary.swift with matching cost,
stats, element/discipline and keywords. Ability text is compared loosely
(whitespace-normalised) and reported for review rather than treated as fatal,
since the two files store it differently: cards.json splits abilities into
{trigger, text} pairs, CardLibrary.swift keeps one combined string.

Exit 0 = in sync. Exit 1 = drift found.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SWIFT = os.path.join(ROOT, "Services", "CardLibrary.swift")
JSON = os.path.join(ROOT, "Resources", "cards.json")


def swift_cards(path):
    """Pull every TCGCard(...) initializer out of CardLibrary.swift."""
    src = open(path, encoding="utf-8").read()
    cards = {}
    for match in re.finditer(r"TCGCard\(", src):
        # Scan forward to the matching close paren, ignoring parens in strings.
        i, depth, in_str = match.end(), 1, False
        while i < len(src) and depth:
            ch = src[i]
            if in_str:
                if ch == "\\":
                    i += 1
                elif ch == '"':
                    in_str = False
            elif ch == '"':
                in_str = True
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            i += 1
        body = src[match.end():i - 1]

        def s(field):
            m = re.search(r'\b%s:\s*"((?:[^"\\]|\\.)*)"' % field, body)
            return m.group(1) if m else None

        def n(field):
            m = re.search(r"\b%s:\s*(-?\d+)" % field, body)
            return int(m.group(1)) if m else 0

        def enum(field):
            m = re.search(r"\b%s:\s*\.(\w+)" % field, body)
            return m.group(1) if m else None

        kw = re.search(r"\bkeywords:\s*\[([^\]]*)\]", body)
        keywords = re.findall(r'"([^"]+)"', kw.group(1)) if kw else []

        cid = s("id")
        if not cid:
            continue
        cards[cid] = {
            "name": s("name"),
            "type": enum("type"),
            "cost": n("cost"),
            "attack": n("attack"),
            "health": n("health"),
            "discipline": enum("discipline"),
            "element": enum("element"),
            "keywords": sorted(keywords),
            "ability": " ".join((s("ability") or "").split()),
        }
    return cards


def json_cards(path):
    """Flatten cards.json into the same shape."""
    data = json.load(open(path, encoding="utf-8"))
    out = {}
    for section, ctype in (("creatures", "creature"), ("humans", "human"),
                           ("relics", "relic"), ("events", "event")):
        for c in data.get(section, []):
            abilities = c.get("abilities", [])
            # "Play: draw a card." + "Sacrifice: ..." -> one combined string,
            # matching how CardLibrary.swift stores it.
            text = " ".join("%s: %s" % (a["trigger"].capitalize(), a["text"])
                            for a in abilities)
            if not text:
                # Keyword-only cards print just the keyword, e.g. "Charge."
                printed = [k for k in c.get("keywords", []) if k in ("charge", "shield")]
                text = " ".join(k.capitalize() + "." for k in printed)
            if not text:
                text = c.get("text", "")     # relics use a flat `text` field
            out[c["id"]] = {
                "name": c.get("name"),
                "type": ctype,
                "cost": c.get("cost", 0),
                "attack": c.get("attack", 0),
                "health": c.get("health", 0),
                "discipline": c.get("discipline"),
                "element": c.get("element"),
                "keywords": sorted(c.get("keywords", [])),
                "ability": " ".join(text.split()),
            }
    return out


def main():
    sw, js = swift_cards(SWIFT), json_cards(JSON)
    print("CardLibrary.swift: %d cards    cards.json: %d cards\n" % (len(sw), len(js)))

    hard, soft = [], []

    missing = sorted(set(js) - set(sw))
    for cid in missing:
        hard.append("%-22s in cards.json but NOT in CardLibrary.swift" % cid)

    # Fields that must match exactly.
    for cid in sorted(set(js) & set(sw)):
        a, b = js[cid], sw[cid]
        for field in ("name", "type", "cost", "attack", "health",
                      "discipline", "element", "keywords"):
            if a[field] != b[field]:
                hard.append("%-22s %-11s json=%-18r swift=%r"
                            % (cid, field, a[field], b[field]))
        if a["ability"] != b["ability"]:
            soft.append("%s\n     json:  %s\n     swift: %s"
                        % (cid, a["ability"] or "(none)", b["ability"] or "(none)"))

    if hard:
        print("DRIFT (%d):" % len(hard))
        for line in hard:
            print("  " + line)
    else:
        print("Stats, types and keywords all match.")

    if soft:
        print("\nAbility text differs (%d) — review, may just be phrasing:" % len(soft))
        for line in soft:
            print("  " + line)

    undocumented = len(set(sw) - set(js))
    print("\n%d cards are in CardLibrary.swift only — expected, cards.json "
          "covers the starter set." % undocumented)

    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
