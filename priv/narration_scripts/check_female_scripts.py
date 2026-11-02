#!/usr/bin/env python3
"""Check Arabella's meditative scripts before anything is recorded.

    python3 priv/narration_scripts/check_female_scripts.py

Reads every meditation in female_v3_meditations.csv from the public API
(read only; no keys, no ElevenLabs) and its script in female/<id>.txt, and
fails unless, for each one:

  * the script exists, and no script exists for a meditation not on the list;
  * with the tags and any added "..." taken out, the text is the live
    meditation exactly (whitespace aside), so no word or mark was changed;
  * the opening sentence has no tag (the first tag comes after it ends);
  * every tag is on the allowed list in meditative_enhance_prompt.md;
  * every tone tag after the first group comes with [softly] or [gently];
  * no exclamation mark and no capitalised word was added.

Prints one line per failure and a summary with the character counts that
set the cost (eleven_v4 bills about one credit per character sent).
"""
import csv, json, os, re, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://www.lumenviae.org/api/meditation-sets/"
TAG = re.compile(r"\[([^\]]*)\]")
TONE = {"thoughtful", "softly", "gently", "warmly", "tenderly", "sad", "reverently",
        "with quiet wonder", "softly with quiet resolve"}
BREATH = {"sighs softly", "short pause", "pause", "long pause"}
EASE = {"softly", "gently", "softly with quiet resolve"}


def norm(text):
    return re.sub(r"\s+", " ", text.replace("...", " ")).strip()


def first_sentence_end(text):
    m = re.search(r"[.?!;:](?=[\"'”’)]*(\s|$))", text)
    return m.end() if m else len(text)


def check(mid, script, content):
    errors = []
    bare = TAG.sub("", script)
    if norm(bare) != norm(content):
        a, b = norm(bare), norm(content)
        i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), min(len(a), len(b)))
        errors.append(f"text differs at char {i}: script {a[i:i+40]!r} vs live {b[i:i+40]!r}")
    first = TAG.search(script)
    if first and first.start() < first_sentence_end(TAG.sub(lambda m: " " * len(m.group(0)), script)):
        errors.append("opening sentence is tagged")
    for t in TAG.findall(script):
        if t not in TONE | BREATH:
            errors.append(f"tag not allowed: [{t}]")
    groups = [[t for t in g if t in TONE] for g in
              (TAG.findall(m.group(0)) for m in re.finditer(r"(?:\[[^\]]*\]\s*)+", script))]
    groups = [g for g in groups if g]
    for g in groups[1:]:
        if not set(g) & EASE:
            errors.append(f"tone change without softly or gently: {g}")
    if bare.count("!") > content.count("!"):
        errors.append("exclamation mark added")
    caps = lambda s: len(re.findall(r"\b[A-Z]{2,}\b", s))
    if caps(bare) > caps(content):
        errors.append("capitalised word added")
    return errors


def main():
    rows = list(csv.DictReader(open(os.path.join(HERE, "female_v3_meditations.csv"))))
    listed = {r["meditation_id"] for r in rows}
    live = {}
    for set_id in sorted({r["set_id"] for r in rows}):
        for m in json.load(urllib.request.urlopen(API + set_id))["data"]["meditations"]:
            live[str(m["id"])] = m["content"]
    failures, chars_text, chars_script = 0, 0, 0
    folder = os.path.join(HERE, "female")
    for name in sorted(os.listdir(folder)):
        if name.endswith(".txt") and name[:-4] not in listed:
            print(f"#{name[:-4]}: script for a meditation not on the list"); failures += 1
    for r in rows:
        mid = r["meditation_id"]; path = os.path.join(folder, f"{mid}.txt")
        if not os.path.exists(path):
            print(f"#{mid}: no script"); failures += 1; continue
        script = open(path).read().strip()
        if mid not in live:
            print(f"#{mid}: not in set {r['set_id']} on the live API"); failures += 1; continue
        chars_text += len(live[mid]); chars_script += len(script)
        for e in check(mid, script, live[mid]):
            print(f"#{mid}: {e}"); failures += 1
    print(f"{len(rows)} meditations, {chars_text} characters of text, {chars_script} "
          f"characters sent with tags; {failures} failure(s)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
