#!/usr/bin/env python3
"""Record meditations with Eleven v4 and hand-tagged ("enhanced") scripts, then upload.

    python3 -u priv/narration_scripts/generate_frederick.py SET_ID [--voice frederick|female]
        [--ids 228,251] [--no-upload] [--force]
    python3 -u priv/narration_scripts/generate_frederick.py --ranked --credits N [--keep 2000]
        [--no-upload] [--force]

Scripts: priv/narration_scripts/frederick/<meditation_id>.txt for frederick, and
priv/narration_scripts/female/<meditation_id>.txt for female, tagged in the calmer style of
meditative_enhance_prompt.md and checked by check_female_scripts.py (direction tags live
only there, never in stored content). With --voice female a meditation without a female/
script is skipped. Each script's words are checked against the live content, or
against priv/narration_scripts/pending_text_fixes.json when a text fix for that id is
waiting to be applied to the database.

frederick: saves narration_out/frederick/<filename>, uploads voices/frederick/<filename>
  (skips existing keys unless --force). No database writes.
female: saves narration_out/female/<filename>; before overwriting the live
  voices/female/<filename> it copies the current object to
  voices/female_pre_v4/<filename> (once). Use --ids to limit to changed meditations.
--ranked: re-records Frederick from frederick_meditative/<id>.txt, worst first in
  frederick_ranked.csv (write it first with rank_frederick.py), and right after each
  of Arabella's 46 in female_v4_dramatic_meditations.csv (recorded on v4 from his
  dramatic scripts) her recording from female/<id>.txt. The API key cannot read the
  balance, so the run counts it by hand: it starts at --credits (the balance on the
  account page), takes off each recording's cost (the response's character-cost
  header, else one credit per character sent), prints the spend and the balance
  after every recording, and stops before one would leave fewer than --keep (2,000
  by default), pricing it at the dearest rate per character seen so far, one
  credit per character before any. A recording is
  skipped once the live file differs from its archive in voices/<voice>_pre_meditative/,
  and one saved locally in narration_out/<voice>_meditative/ is uploaded without being
  paid for again, so a second run goes on where the first stopped, including after a
  failed upload. Any S3 error other than "not found" stops the run. Before replacing voices/<voice>/<filename>
  it copies the live file to voices/<voice>_pre_meditative/<filename> (once);
  voices/female_pre_v4/ is never written here.
"""
import csv, json, os, re, sys, urllib.request
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VOICES = {
    "frederick": "j9jfwdrw7BRfcR43Qohk",   # Frederick Surrey
    "female": "Z3R5wn05IrDiVCyEkUrK",      # Arabella
}
MODEL = "eleven_v4"
SETTINGS = {"stability": 0.5, "similarity_boost": 0.75}
API = "https://www.lumenviae.org/api/meditation-sets/"

env = {}
# Read when present, so the S3 checks below can be tested without keys.
if os.path.exists(os.path.join(ROOT, ".env")):
    for line in open(os.path.join(ROOT, ".env")):
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1); env[k.strip()] = v.strip().strip('"\'')

def s3_options(env):
    """boto3's S3 client options from .env, the same settings the app reads
    in config/runtime.exs: AWS S3 in AWS_REGION unless S3_HOST names another
    S3-compatible store (Cloudflare R2: S3_HOST=<account>.r2.cloudflarestorage.com,
    S3_REGION=auto), so new recordings land where the app signs links."""
    options = {"aws_access_key_id": env["AWS_ACCESS_KEY_ID"],
               "aws_secret_access_key": env["AWS_SECRET_ACCESS_KEY"],
               "region_name": env.get("S3_REGION") or env["AWS_REGION"]}
    if env.get("S3_HOST"):
        options["endpoint_url"] = (env.get("S3_SCHEME") or "https://") + env["S3_HOST"]
    return options

def s3_client():
    import boto3
    return boto3.client("s3", **s3_options(env))

def head_etag(s3, bucket, key, missing_on_403=False):
    """The object's ETag, or None when it does not exist; any other S3 error
    stops the run, since reading it as "missing" could pay for a recording
    again or replace a live file without archiving it.

    Without s3:ListBucket (the upload user has none) S3 answers a missing key
    with 403, not 404. So a 403 reads as missing only with missing_on_403,
    which a caller passes after it has just read another key of the same
    voices/ tree (the live file): that read proves the credentials work, so
    the 403 can only mean the key is absent."""
    try:
        return s3.head_object(Bucket=bucket, Key=key)["ETag"]
    except Exception as e:
        code = str(getattr(e, "response", {}).get("Error", {}).get("Code", ""))
        if code in ("404", "NoSuchKey", "NotFound"): return None
        if missing_on_403 and code in ("403", "Forbidden", "AccessDenied"): return None
        raise

def words(s): return re.findall(r"[A-Za-z']+", s.lower())
def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

def tts(vid, script):
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
        data=json.dumps({"text": script, "model_id": MODEL, "voice_settings": SETTINGS}).encode(),
        headers={"xi-api-key": env["ELEVEN_LABS_API_KEY"], "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=150) as r: return r.read(), dict(r.headers)

def charged(headers, characters):
    """What one recording cost in credits: the `character-cost` header
    ElevenLabs documents on its responses (api-reference/introduction), or
    `x-character-count`, which an older page of the same docs names; without
    a usable one, one credit per character sent, the dearest it has been."""
    named = {k.lower(): v for k, v in headers.items()}
    for name in ("character-cost", "x-character-count"):
        try: return float(named[name])
        except (KeyError, TypeError, ValueError): pass
    return float(characters)

class Budget:
    """The credits a ranked run may spend, counted by hand: the API key cannot
    read the account's balance (it lacks user_read). It starts at --credits,
    is charged what each recording cost, and refuses a recording that would
    take it under --keep. A recording not yet made is priced at the dearest
    rate per character seen on this run, one credit per character before any."""
    def __init__(self, credits, keep):
        self.balance, self.keep, self.spent, self.rate = float(credits), keep, 0.0, None
    def affords(self, characters):
        return self.balance - characters * (self.rate or 1.0) >= self.keep
    def charge(self, characters, headers):
        cost = charged(headers, characters)
        self.balance -= cost; self.spent += cost
        self.rate = max(self.rate or 0.0, cost / characters)
        return cost

def already_replaced(live, archived):
    """A ranked recording is done when its archive exists and the live file is
    no longer that archived one. An archive beside an unchanged live file is
    an upload that failed, which the run retries."""
    return archived is not None and live not in (None, archived)

def ranked():
    keep, credits = opt("--keep", "2000"), opt("--credits")
    if not keep.isdigit(): sys.exit("--keep takes a whole number of credits")
    if not credits or not credits.isdigit():
        sys.exit("--ranked needs --credits N: the balance on the ElevenLabs account page now")
    budget = Budget(int(credits), int(keep))
    upload = "--no-upload" not in sys.argv; force = "--force" in sys.argv
    here = os.path.join(ROOT, "priv/narration_scripts")
    rows = list(csv.DictReader(open(os.path.join(here, "frederick_ranked.csv"))))
    s3 = None; bucket = env["AWS_S3_BUCKET"]
    if upload: s3 = s3_client()
    def live_and_archive(key, archive):
        """The live file's ETag (a 403 here stops the run: these credentials
        cannot read the tree) and then the archive's (a 403 now means absent)."""
        live = head_etag(s3, bucket, key)
        return live, head_etag(s3, bucket, archive, missing_on_403=live is not None)
    # Arabella's meditations recorded on v4 from Frederick's dramatic
    # scripts (29 Sep): re-recorded beside his, from female/<id>.txt.
    female_too = {r["meditation_id"] for r in
        csv.DictReader(open(os.path.join(here, "female_v4_dramatic_meditations.csv")))}
    sets, stopped = {}, False
    for r in rows:
        mid = r["meditation_id"]
        if r["set_id"] not in sets:
            sets[r["set_id"]] = {str(m["id"]): m for m in
                json.load(urllib.request.urlopen(API + r["set_id"]))["data"]["meditations"]}
        m = sets[r["set_id"]].get(mid)
        if not m: sys.exit(f"#{mid}: not in set {r['set_id']}; run rank_frederick.py again")
        fn = m["audio_url"].split("?")[0].rsplit("/", 1)[-1]
        jobs = [("frederick", "frederick_meditative")]
        if mid in female_too: jobs.append(("female", "female"))
        for voice, folder in jobs:
            key, archive = f"voices/{voice}/{fn}", f"voices/{voice}_pre_meditative/{fn}"
            label = f"#{mid} {voice} rank {r['rank']}"
            # Done when the live file is no longer the one archived. An archive
            # beside an unchanged live file is an upload that failed: carry on,
            # and a recording already saved locally is uploaded without paying.
            if s3 and not force:
                live, old = live_and_archive(key, archive)
                if already_replaced(live, old):
                    print(f"{label}: already re-recorded, skipped", flush=True); continue
            path = os.path.join(here, folder, f"{mid}.txt")
            script = open(path).read().strip()
            if words(re.sub(r"\[[^\]]*\]", "", script)) != words(m["content"]):
                sys.exit(f"#{mid}: script words differ from the content; fix {path}")
            outdir = os.path.join(ROOT, "narration_out", f"{voice}_meditative"); os.makedirs(outdir, exist_ok=True)
            out = os.path.join(outdir, fn)
            cost = 0
            if force or not os.path.exists(out):
                if not budget.affords(len(script)):
                    print(f"Stopped at {label} ({len(script)} characters): about "
                          f"{budget.balance:,.0f} credits left, keeping {budget.keep:,}; "
                          f"{budget.spent:,.0f} spent. Run again with the new balance.", flush=True)
                    stopped = True; break
                audio, headers = tts(VOICES[voice], script)
                if len(audio) < 1000: sys.exit(f"{label}: empty audio")
                open(out + ".part", "wb").write(audio); os.replace(out + ".part", out)
                cost = budget.charge(len(script), headers)
            status = "saved"
            if s3:
                # voices/<voice>_pre_meditative/, never female_pre_v4/ (which
                # holds Arabella's v3 originals)
                live, old = live_and_archive(key, archive)
                if live is not None and old is None:
                    s3.copy_object(Bucket=bucket, Key=archive, CopySource={"Bucket": bucket, "Key": key})
                    # Read the copy back strictly before replacing the live file:
                    # if these credentials cannot read the archive prefix, every
                    # 403 above was a hidden archive, not a missing one, and a
                    # rerun would copy new takes over the backups. Stop here.
                    head_etag(s3, bucket, archive)
                s3.upload_file(out, bucket, key, ExtraArgs={"ContentType": "audio/mpeg"})
                status = f"replaced live {voice} (old copy archived)"
            print(f"{label} {fn} · {cost:,.0f} credits · {status} · spent {budget.spent:,.0f}, "
                  f"about {budget.balance:,.0f} left", flush=True)
        if stopped: break
    print(f"Done: {budget.spent:,.0f} credits spent, about {budget.balance:,.0f} left", flush=True)

def main():
    if "--ranked" in sys.argv: return ranked()
    set_id = sys.argv[1]
    voice = opt("--voice", "frederick"); vid = VOICES[voice]
    ids = set(opt("--ids", "").split(",")) - {""}
    upload = "--no-upload" not in sys.argv; force = "--force" in sys.argv
    fixes_path = os.path.join(ROOT, "priv/narration_scripts/pending_text_fixes.json")
    fixes = json.load(open(fixes_path)) if os.path.exists(fixes_path) else {}
    s = json.load(urllib.request.urlopen(API + set_id))["data"]
    outdir = os.path.join(ROOT, "narration_out", voice); os.makedirs(outdir, exist_ok=True)
    s3 = None; bucket = env["AWS_S3_BUCKET"]
    if upload: s3 = s3_client()
    def exists(key):
        try: s3.head_object(Bucket=bucket, Key=key); return True
        except Exception: return False
    for m in s["meditations"]:
        if ids and str(m["id"]) not in ids: continue
        fn = m["audio_url"].split("?")[0].rsplit("/", 1)[-1]
        # female reads her own meditative scripts (female/<id>.txt) and skips a
        # meditation without one, so a whole set never re-records her v4 files
        # from Frederick's dramatic tags.
        folder = "female" if voice == "female" else "frederick"
        path = os.path.join(ROOT, "priv/narration_scripts", folder, f"{m['id']}.txt")
        if voice == "female" and not os.path.exists(path):
            print(f"#{m['id']}: no female/ script, skipped", flush=True); continue
        script = open(path).read().strip()
        content = fixes.get(str(m["id"]), m["content"])
        if words(re.sub(r"\[[^\]]*\]", "", script)) != words(content):
            sys.exit(f"#{m['id']}: script words differ from the content; fix {path}")
        out = os.path.join(outdir, fn)
        if force or not os.path.exists(out):
            audio, _headers = tts(vid, script)
            if len(audio) < 1000: sys.exit(f"#{m['id']}: empty audio")
            open(out + ".part", "wb").write(audio); os.replace(out + ".part", out)
        key = f"voices/{voice}/{fn}"; status = "saved"
        if s3:
            if voice == "female":
                archive = f"voices/female_pre_v4/{fn}"
                if exists(key) and not exists(archive):
                    s3.copy_object(Bucket=bucket, Key=archive, CopySource={"Bucket": bucket, "Key": key})
                s3.upload_file(out, bucket, key, ExtraArgs={"ContentType": "audio/mpeg"}); status = "replaced live female (old copy archived)"
            elif exists(key) and not force: status = "already in S3"
            else:
                s3.upload_file(out, bucket, key, ExtraArgs={"ContentType": "audio/mpeg"}); status = "uploaded"
        print(f"#{m['id']} {fn} {os.path.getsize(out)} bytes · {status} · {key}", flush=True)

if __name__ == "__main__":
    main()
