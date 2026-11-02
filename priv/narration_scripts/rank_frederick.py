#!/usr/bin/env python3
"""Rank Frederick's recorded scripts by how far they break the meditative rule.

    python3 priv/narration_scripts/rank_frederick.py

Scores every script in frederick/ (what his live recordings were made from)
against meditative_enhance_prompt.md and writes frederick_ranked.csv, worst
first, with the characters of its replacement in frederick_meditative/ (what
a re-recording sends, about one eleven_v4 credit per character) and a running
total, which `generate_frederick.py --ranked --budget N` reads. Read only:
the public API for the live text, no keys, no ElevenLabs.

Points per script:
  3  each loud tag ([earnestly], [resolute], [joyful, rising], [awed]...)
  2  each whispered or hushed tag
  1  each other tag not on the prompt's allowed list
  3  a tag on the opening sentence
  3  each capitalised word the live text does not have (emphasis)
  2  each exclamation mark the live text does not have
  1  each change of tone, after the first, without softly or gently
  1  each change of tone beyond one in a paragraph

The rank is points per 1,000 characters of text, so a budget buys the
meditations that sound most dramatic for their length first; the raw points
are in the file too.
"""
import csv, json, os, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://www.lumenviae.org/api/meditation-sets"
CATEGORIES = ["joyful", "sorrowful", "glorious", "luminous", "seven_sorrows"]
TAG = re.compile(r"\[([^\]]*)\]")
GROUP = re.compile(r"(?:\[[^\]]*\]\s*)+")
ALLOWED = {"thoughtful", "softly", "gently", "warmly", "tenderly", "sad", "reverently",
           "with quiet wonder", "softly with quiet resolve", "sighs softly",
           "short pause", "pause", "long pause"}
BREATH = {"sighs softly", "short pause", "pause", "long pause"}
LOUD = re.compile(r"earnest|resolut|excit|angr|shout|dramatic|laugh|joy|rising|bright|"
                  r"firm|triumph|fervent|urgen|passion|intens|bold|strong|exult|cry|loud|"
                  r"proclaim|emphatic|forceful|declar|vehement|stern|command|swell|build|"
                  r"exclaim|fierce|ardent|jubil|elat|thunder|awe|grave|solemn|conviction")
HUSHED = re.compile(r"whisper|hushed")


def live_meditations():
    found = {}
    for cat in CATEGORIES:
        for s in json.load(urllib.request.urlopen(f"{API}?category={cat}"))["data"]:
            for m in json.load(urllib.request.urlopen(f"{API}/{s['id']}"))["data"]["meditations"]:
                found.setdefault(str(m["id"]), dict(set_id=s["id"], set=s["name"],
                                                    content=m["content"]))
    return found


def first_sentence_end(text):
    m = re.search(r"[.?!;:](?=[\"'”’)]*(\s|$))", text)
    return m.end() if m else len(text)


def score(script, content):
    points, notes = 0, []
    tags = TAG.findall(script)
    loud = [t for t in tags if t not in ALLOWED and LOUD.search(t)]
    hushed = [t for t in tags if t not in ALLOWED and not LOUD.search(t) and HUSHED.search(t)]
    other = [t for t in tags if t not in ALLOWED and t not in loud and t not in hushed]
    points += 3 * len(loud) + 2 * len(hushed) + len(other)
    if loud: notes.append(f"{len(loud)} loud")
    if hushed: notes.append(f"{len(hushed)} hushed")
    if other: notes.append(f"{len(other)} off-list")
    first = TAG.search(script)
    blank = TAG.sub(lambda m: " " * len(m.group(0)), script)
    if first and first.start() < first_sentence_end(blank):
        points += 3; notes.append("tagged opening")
    bare = TAG.sub("", script)
    caps = lambda s: len(re.findall(r"\b[A-Z]{2,}\b", s))
    extra_caps = max(0, caps(bare) - caps(content))
    bangs = max(0, bare.count("!") - content.count("!"))
    points += 3 * extra_caps + 2 * bangs
    if extra_caps: notes.append(f"{extra_caps} emphasis capitals")
    if bangs: notes.append(f"{bangs} added !")
    abrupt, crowded = 0, 0
    for para in script.split("\n"):
        tones = [g for g in ([t for t in TAG.findall(m.group(0)) if t not in BREATH]
                             for m in GROUP.finditer(para)) if g]
        crowded += max(0, len(tones) - 1)
    groups = [g for g in ([t for t in TAG.findall(m.group(0)) if t not in BREATH]
                          for m in GROUP.finditer(script)) if g]
    for g in groups[1:]:
        if not any(t.startswith(("softly", "gently")) for t in g):
            abrupt += 1
    points += abrupt + crowded
    if abrupt: notes.append(f"{abrupt} abrupt tone changes")
    if crowded: notes.append(f"{crowded} extra tone changes in a paragraph")
    return points, "; ".join(notes)


def main():
    live = live_meditations()
    rows = []
    for name in os.listdir(os.path.join(HERE, "frederick")):
        if not name.endswith(".txt"): continue
        mid = name[:-4]
        old = open(os.path.join(HERE, "frederick", name)).read().strip()
        new_path = os.path.join(HERE, "frederick_meditative", name)
        new = open(new_path).read().strip() if os.path.exists(new_path) else ""
        content = live[mid]["content"]
        points, notes = score(old, content)
        rows.append(dict(meditation_id=mid, set_id=live[mid]["set_id"], set=live[mid]["set"],
                         points=points,
                         per_1000=round(points * 1000 / len(content), 2),
                         breaks=notes, characters=len(new)))
    rows.sort(key=lambda r: (-r["per_1000"], -r["points"], int(r["meditation_id"])))
    total = 0
    with open(os.path.join(HERE, "frederick_ranked.csv"), "w", newline="") as f:
        cols = ["rank", "meditation_id", "set_id", "set", "per_1000", "points", "breaks",
                "characters", "running_total"]
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader()
        for i, r in enumerate(rows, 1):
            total += r["characters"]
            w.writerow(dict(r, rank=i, running_total=total))
    print(f"{len(rows)} meditations ranked, {total} characters to re-record them all")


if __name__ == "__main__":
    main()
