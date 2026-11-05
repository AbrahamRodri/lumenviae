#!/usr/bin/env python3
"""Line-by-line timings for the spoken Rosary's clips, as the meditations have them.

    mix run --no-start scripts/rosary_clips.exs > "$TMPDIR/rosary_clips.json"
    python3 scripts/rosary_lines.py --clips "$TMPDIR/rosary_clips.json" [--voice female]
        [--names hail_mary,glory_be] [--cache DIR]

The clip list (`scripts/rosary_clips.exs`) gives every clip a voice records:
its recording voice, hashed file name, kind, name and the words it was sent
(`LumenViae.Rosary.PrayerAudio.speech_text/1`'s words, with the text's own
line breaks kept). For each voice, this fetches
the live recordings through the app's own signed URLs (`GET
/api/rosary/audio?voice=`, with and without `include=book`), keeps a
recording only when its bytes match the ETag it was served with, and then
times it exactly as `scripts/narration_lines.py` times a meditation (the
same phrase split, local Whisper, word alignment and checks, imported from
it). One difference: a line may end at the end of a line of the prayer's
text as well as at a sentence's end, so a long prayer (the Creed, the Hail
Holy Queen) is shown a line at a time rather than a sentence; lines the
narrator did not pause between are still one. A line is
1 to 45 seconds long, read at 6 to 25 characters a second, with at least
90% of the clip's words and 70% of each line's heard. A clip that fails is
listed, never guessed.

Writes `priv/rosary_audio/lines/<voice>.json`, keyed by the clip's file
name: `{"<file>": {"duration": seconds, "lines": [{"text", "start", "end"}]}}`
(the duration is the recording's, so a test can check the lines fit it). A reworded or
re-recorded clip has a new file name, so old timings never apply to it.

Free and local: no ElevenLabs, no recording. Needs ffmpeg and numpy,
soundfile and sherpa-onnx with the whisper-small model (WHISPER_DIR; see
`scripts/narration_lines.py`).
"""

import hashlib, json, os, sys, urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import narration_lines as nl  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "priv/rosary_audio/lines"
API = "https://www.lumenviae.org/api/rosary/audio?voice="
AGENT = {"User-Agent": "Mozilla/5.0 LumenViae rosary_lines"}


def line_ends(text):
    """Where a line may end: a sentence's end, or the end of a line of the text."""
    ends = set(SENTENCE_ENDS(text))
    offset = 0
    for line in text.split("\n"):
        offset += len(line)
        if line.strip():
            ends.add(len(line.rstrip()) + offset - len(line))
        offset += 1
    return sorted(e for e in ends if e <= len(text.rstrip()))


SENTENCE_ENDS = nl.sentence_ends
nl.sentence_ends = line_ends


def served_urls(voice):
    """{(recording voice, file): signed url} from the voice's manifests."""
    urls = {}

    def walk(o):
        if isinstance(o, dict):
            if o.get("file") and o.get("audio_url"):
                recorded_by = o["audio_url"].split("/voices/")[1].split("/")[0]
                urls[(recorded_by, o["file"])] = o["audio_url"]
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)

    for query in ("", "&include=book"):
        req = urllib.request.Request(API + voice + query, headers=AGENT)
        walk(json.load(urllib.request.urlopen(req))["data"])
    return urls


def fetch(url, path):
    """Downloads a recording once; True when its bytes match its ETag."""
    if not path.exists():
        r = urllib.request.urlopen(urllib.request.Request(url, headers=AGENT))
        data, etag = r.read(), (r.headers.get("ETag") or "").strip('"')
        if etag != hashlib.md5(data).hexdigest():
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return True


def main():
    clips = json.load(open(nl.opt("--clips") or sys.exit("--clips FILE is required")))
    cache = Path(nl.opt("--cache", os.path.join(os.environ.get("TMPDIR", "/tmp"), "rosary_lines")))
    only_voice = nl.opt("--voice")
    only = set(nl.opt("--names", "").split(",")) - {""}

    # One entry per recording: a voice that borrows another's clips (the
    # Prayer Book, for now) is timed under the voice that recorded them.
    recordings = {}
    for c in clips:
        if (not only_voice or c["voice"] == only_voice) and (not only or c["name"] in only):
            recordings[(c["voice"], c["file"])] = c

    urls = {}
    for asked in sorted({c["asked"] for c in clips}):
        urls.update(served_urls(asked))

    for voice in sorted({v for v, _ in recordings}):
        out = OUT / f"{voice}.json"
        result = json.loads(out.read_text()) if out.exists() else {}
        timed, failures = 0, []
        for (v, file), c in sorted(recordings.items()):
            if v != voice:
                continue
            label = f"{c['kind']} {c['name']}"
            url = urls.get((voice, file))
            mp3 = cache / "mp3" / voice / file
            if url is None:
                failures.append((label, "not served")); result.pop(file, None); continue
            if not fetch(url, mp3):
                failures.append((label, "download differs from its ETag")); result.pop(file, None); continue
            wav = nl.wav_of(mp3, cache / voice)
            spans, total = nl.phrases(wav)
            name = f"{voice}-{mp3.stem}"
            heard = nl.hear(name, wav, spans, cache)
            lines, why = nl.lines_for(c["text"], spans, heard, total)
            if lines is not None:
                why = nl.recheck(name, wav, lines, cache)
                if why: lines = None
            if lines is None:
                failures.append((label, why)); result.pop(file, None); continue
            result[file] = {"duration": round(total, 2), "lines": lines}
            timed += 1
            print(f"{voice} {label}: {len(lines)} lines over {total:.1f}s", flush=True)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(dict(sorted(result.items())), ensure_ascii=False, indent=1) + "\n")
        for label, why in failures:
            print(f"{voice} {label}: FAILED, {why}", flush=True)
        total_clips = sum(1 for v, _ in recordings if v == voice)
        print(f"{voice}: {timed} of {total_clips} timed, written to {out.relative_to(ROOT)}", flush=True)


if __name__ == "__main__":
    main()
