#!/usr/bin/env python3
"""Line-by-line timings for meditation recordings, the way the Chant Library has them.

    python3 scripts/narration_lines.py --audio DIR [--ids 121,122] [--cache DIR]

For each meditation in priv/narration_scripts/female_v3_meditations.csv (the
75 Arabella recordings re-recorded on 2 Nov 2026), reads the MP3 in DIR, finds
the phrases in it (silences, from its loudness), asks a local Whisper model
what is heard in each, aligns that with the meditation's stored text word by
word, and cuts the text into lines: a sentence, or several when the narrator
did not pause between them, each starting and ending where the recording falls
silent; a line under a second (a closing "Amen.") joins the one before it.
Writes priv/narration_lines/female.json.

A recording gets lines only when it passes every check: the MP3 is the one
live in S3 (same MD5 as its ETag; skipped with --no-etag), at least 90% of the
text's words are heard, and every line has at least 70% of its words heard in
its own span (aligned from the phrases, and heard again from the line's window
alone), is 1 to 45 seconds long and is read at 6 to 25 characters a second.
Anything else is listed as a failure, never guessed.

Free and local: no ElevenLabs, no recording. Needs ffmpeg, the AWS CLI with
the lumenviae-agent profile (for the ETag), and numpy, soundfile, rapidfuzz and
sherpa-onnx with the whisper-small model (WHISPER_DIR, by default the iOS
repo's Tools/ChantLines/cache/models/sherpa-onnx-whisper-small).
"""

import csv, difflib, hashlib, json, os, re, subprocess, sys, unicodedata, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIST = ROOT / "priv/narration_scripts/female_v3_meditations.csv"
OUT = ROOT / "priv/narration_lines/female.json"
API = "https://www.lumenviae.org/api/meditation-sets/"
BUCKET = "lumenviae-audio"
WHISPER = Path(os.environ.get("WHISPER_DIR", Path.home() /
    "Developer/lumenviae/ios/Tools/ChantLines/cache/models/sherpa-onnx-whisper-small"))

FRAME = 0.02          # seconds per loudness frame
QUIET = -32.0         # dB under the loud speech that counts as silence
GAP = 0.25            # the shortest silence that parts two phrases, in seconds
LEAD = 0.08           # a line starts this much before its sound
TAIL = 0.12           # and ends this much after it
MIN_LINE, MAX_LINE = 1.0, 45.0
MIN_RATE, MAX_RATE = 6.0, 25.0     # characters of text a second
HEARD_ALL, HEARD_LINE = 0.90, 0.70
ABBREVIATIONS = {"st", "sts", "mt", "mr", "mrs", "dr", "ch", "cf", "viz", "vs", "ps", "lk", "jn"}

_recognizer = None


def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def norm(word):
    word = unicodedata.normalize("NFKD", word).encode("ascii", "ignore").decode()
    return word.lower().replace("'", "")


def words_of(text):
    """(normalized word, start offset, end offset) for every word."""
    return [(norm(m.group(0)), m.start(), m.end())
            for m in re.finditer(r"[A-Za-z0-9À-ɏ]+(?:['’][A-Za-z]+)*", text)]


def sentence_ends(text):
    """Offsets just past each sentence's last mark."""
    ends = []
    for m in re.finditer(r"[.?!](?:[\"'”’)\]]*)(?=\s|$)", text):
        before = re.search(r"([A-Za-z]+)\.$", text[:m.start() + 1])
        if before and before.group(1).lower() in ABBREVIATIONS:
            continue
        ends.append(m.end())
    if not ends or ends[-1] < len(text.rstrip()):
        ends.append(len(text.rstrip()))
    return ends


def wav_of(mp3, cache):
    out = cache / "wav" / (mp3.stem + ".wav")
    if not out.exists():
        out.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(mp3), "-ac", "1",
                        "-ar", "16000", str(out)], check=True)
    return out


def phrases(wav):
    import numpy as np
    import soundfile as sf
    audio, rate = sf.read(str(wav), dtype="float32")
    n = int(FRAME * rate)
    frames = audio[: len(audio) // n * n].reshape(-1, n)
    db = 20 * np.log10(np.sqrt((frames ** 2).mean(axis=1)) + 1e-9)
    loud = np.percentile(db, 95)
    sounding = db > loud + QUIET
    spans, start, quiet_run = [], None, 0
    for i, s in enumerate(sounding):
        if s:
            if start is None: start = i
            quiet_run = 0
        elif start is not None:
            quiet_run += 1
            if quiet_run * FRAME >= GAP:
                spans.append((start * FRAME, (i - quiet_run + 1) * FRAME)); start = None
    if start is not None:
        spans.append((start * FRAME, len(sounding) * FRAME))
    return [s for s in spans if s[1] - s[0] >= 0.1], len(audio) / rate


def hear(name, wav, spans, cache):
    path = cache / "asr" / f"{name}.json"
    known = json.loads(path.read_text()) if path.exists() else {}
    keys = [f"{a:.2f}-{b:.2f}" for a, b in spans]
    todo = [k for k in keys if k not in known]
    if todo:
        global _recognizer
        import numpy as np
        import sherpa_onnx
        import soundfile as sf
        if _recognizer is None:
            m = str(WHISPER / "small-")
            _recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
                encoder=m + "encoder.int8.onnx", decoder=m + "decoder.int8.onnx",
                tokens=m + "tokens.txt", language="en", task="transcribe",
                num_threads=int(os.environ.get("WHISPER_THREADS", os.cpu_count() or 4)))
        audio, rate = sf.read(str(wav), dtype="float32")
        for k in todo:
            a, b = (float(x) for x in k.split("-"))
            heard = []
            for c in np.arange(a, b, 28.0):   # Whisper hears 30 seconds at a time
                stream = _recognizer.create_stream()
                stream.accept_waveform(rate, audio[int(max(0, c - 0.05) * rate):int(min(b + 0.05, c + 28.0) * rate)])
                _recognizer.decode_stream(stream)
                heard.append(stream.result.text.strip())
            known[k] = " ".join(h for h in heard if h)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(known, ensure_ascii=False, indent=0))
    return [known[k] for k in keys]


def etag_matches(mp3, key):
    r = subprocess.run(["aws", "s3api", "head-object", "--bucket", BUCKET, "--key", key,
                        "--profile", "lumenviae-agent", "--query", "ETag", "--output", "text"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return False, "not in S3"
    md5 = hashlib.md5(mp3.read_bytes()).hexdigest()
    return r.stdout.strip().strip('"') == md5, "differs from the live file"


def lines_for(content, spans, heard, total):
    text_words = words_of(content)
    heard_words, heard_span = [], []
    for i, h in enumerate(heard):
        for w, _, _ in words_of(h):
            heard_words.append(w); heard_span.append(i)
    matcher = difflib.SequenceMatcher(None, [w for w, _, _ in text_words], heard_words, autojunk=False)
    span_of, matched = [None] * len(text_words), [False] * len(text_words)
    for a, b, size in matcher.get_matching_blocks():
        for k in range(size):
            span_of[a + k] = heard_span[b + k]; matched[a + k] = True
    if sum(matched) < HEARD_ALL * len(text_words):
        return None, f"only {sum(matched)} of {len(text_words)} words heard"
    # An unheard word ("O" heard as "Oh", "five thousand" as "5,000") lies
    # between the phrases of the heard words around it: a line may begin no
    # earlier than the next heard word's phrase and end no later than the
    # last heard word's.
    first_span, last_span, last = [0] * len(span_of), [0] * len(span_of), 0
    for i, s in enumerate(span_of):
        last = s if s is not None else last
        last_span[i] = last
    after = len(spans) - 1
    for i in range(len(span_of) - 1, -1, -1):
        after = span_of[i] if span_of[i] is not None else after
        first_span[i] = after
    starts = [s for _, s, _ in text_words]
    def first_word(offset): return next(i for i, s in enumerate(starts) if s >= offset)
    sentences, begin = [], 0
    for end in sentence_ends(content):
        if any(begin <= s < end for s in starts):
            sentences.append((begin, end, first_word(begin), max(i for i, s in enumerate(starts) if s < end)))
        begin = end
    lines, group = [], None
    for n, (b, e, wa, wz) in enumerate(sentences):
        group = (group[0], e, group[2], wz) if group else (b, e, wa, wz)
        nxt = sentences[n + 1] if n + 1 < len(sentences) else None
        if nxt is None or first_span[nxt[2]] > last_span[wz]:
            lines.append(group); group = None
    # A line too short to follow (a closing "Amen.") joins the line before it.
    def span(line): return spans[last_span[line[3]]][1] - spans[first_span[line[2]]][0]
    joined = []
    for line in lines:
        if joined and span(line) < MIN_LINE:
            b, _, wa, _ = joined.pop(); joined.append((b, line[1], wa, line[3]))
        else:
            joined.append(line)
    lines = joined
    out, prev_end = [], 0.0
    for b, e, wa, wz in lines:
        text = re.sub(r"\s+", " ", content[b:e]).strip()
        start = max(prev_end, spans[first_span[wa]][0] - LEAD)
        end = min(total, spans[last_span[wz]][1] + TAIL)
        length = end - start
        heard_here = sum(matched[wa:wz + 1]) / (wz - wa + 1)
        if heard_here < HEARD_LINE:
            return None, f"line '{text[:40]}' only {heard_here:.0%} heard"
        if not MIN_LINE <= length <= MAX_LINE:
            return None, f"line '{text[:40]}' is {length:.1f}s"
        if not MIN_RATE <= len(text) / length <= MAX_RATE:
            return None, f"line '{text[:40]}' reads at {len(text) / length:.1f} characters a second"
        out.append({"text": text, "start": round(start, 2), "end": round(end, 2)})
        prev_end = end
    return out, None


def recheck(name, wav, lines, cache):
    """Hears each line's own window again, on its own: at least HEARD_LINE of
    its words must be there. None when every line passes, else why not."""
    heard = hear(name + ".lines", wav, [(l["start"], l["end"]) for l in lines], cache)
    for line, h in zip(lines, heard):
        want = [w for w, _, _ in words_of(line["text"])]
        got = [w for w, _, _ in words_of(h)]
        found = sum(b.size for b in difflib.SequenceMatcher(None, want, got, autojunk=False).get_matching_blocks())
        if found < HEARD_LINE * len(want):
            return f"line '{line['text'][:40]}' heard on its own as '{h[:40]}'"
    return None


def main():
    audio_dir = Path(opt("--audio") or sys.exit("--audio DIR (the recordings) is required"))
    cache = Path(opt("--cache", os.path.join(os.environ.get("TMPDIR", "/tmp"), "narration_lines")))
    only = set(opt("--ids", "").split(",")) - {""}
    rows = [r for r in csv.DictReader(open(LIST)) if not only or r["meditation_id"] in only]
    live = {}
    for set_id in sorted({r["set_id"] for r in rows}):
        for m in json.load(urllib.request.urlopen(API + set_id))["data"]["meditations"]:
            live[str(m["id"])] = m["content"]
    result = json.loads(OUT.read_text()) if OUT.exists() else {}
    failures = []
    for r in rows:
        mid, mp3 = r["meditation_id"], audio_dir / r["audio_file"]
        if not mp3.exists():
            failures.append((mid, "no recording")); continue
        if "--no-etag" not in sys.argv:
            ok, why = etag_matches(mp3, f"voices/female/{r['audio_file']}")
            if not ok:
                failures.append((mid, f"recording {why}")); result.pop(mid, None); continue
        wav = wav_of(mp3, cache)
        spans, total = phrases(wav)
        heard = hear(mp3.stem, wav, spans, cache)
        lines, why = lines_for(live[mid], spans, heard, total)
        if lines is not None:
            why = recheck(mp3.stem, wav, lines, cache)
            if why: lines = None
        if lines is None:
            failures.append((mid, why)); result.pop(mid, None); continue
        result[mid] = {"audio_file": r["audio_file"], "lines": lines}
        print(f"#{mid} {r['audio_file']}: {len(lines)} lines over {total:.0f}s", flush=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(dict(sorted(result.items(), key=lambda kv: int(kv[0]))),
                              ensure_ascii=False, indent=1) + "\n")
    for mid, why in failures:
        print(f"#{mid}: FAILED, {why}", flush=True)
    print(f"{len(rows) - len(failures)} of {len(rows)} written to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
