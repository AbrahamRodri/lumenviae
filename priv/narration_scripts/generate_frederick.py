#!/usr/bin/env python3
"""Record meditations with Eleven v4 and hand-tagged ("enhanced") scripts, then upload.

    python3 -u priv/narration_scripts/generate_frederick.py SET_ID [--voice frederick|female]
        [--ids 228,251] [--no-upload] [--force]
    python3 -u priv/narration_scripts/generate_frederick.py --ranked [--keep 2000]
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
  dramatic scripts) her recording from female/<id>.txt. Before each one it asks the account how
  many credits remain and stops when recording it would leave fewer than --keep
  (2,000 by default), pricing a character at the dearest rate measured on the run
  (1 credit until the first is measured; 0.46 was seen on 2 Nov). A recording already
  replaced (its old file is in voices/<voice>_pre_meditative/) is skipped, and one
  saved locally in narration_out/<voice>_meditative/ costs nothing, so a second run
  goes on where the first stopped. Before replacing voices/<voice>/<filename>
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
for line in open(os.path.join(ROOT, ".env")):
    if "=" in line and not line.lstrip().startswith("#"):
        k, v = line.split("=", 1); env[k.strip()] = v.strip().strip('"\'')

def words(s): return re.findall(r"[A-Za-z']+", s.lower())
def opt(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

def tts(vid, script):
    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
        data=json.dumps({"text": script, "model_id": MODEL, "voice_settings": SETTINGS}).encode(),
        headers={"xi-api-key": env["ELEVEN_LABS_API_KEY"], "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=150) as r: return r.read()

def remaining_credits():
    req = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription",
        headers={"xi-api-key": env["ELEVEN_LABS_API_KEY"], "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r: sub = json.load(r)
    return sub["character_limit"] - sub["character_count"]

def ranked():
    keep = opt("--keep", "2000")
    if not keep.isdigit(): sys.exit("--keep takes a whole number of credits")
    keep = int(keep)
    # Credits per character sent: start at 1 (the dearest it has been) and
    # use the dearest rate measured on this run once one is measured.
    rate, measured = 1.0, None
    upload = "--no-upload" not in sys.argv; force = "--force" in sys.argv
    here = os.path.join(ROOT, "priv/narration_scripts")
    rows = list(csv.DictReader(open(os.path.join(here, "frederick_ranked.csv"))))
    s3 = None; bucket = env["AWS_S3_BUCKET"]
    if upload:
        import boto3
        s3 = boto3.client("s3", aws_access_key_id=env["AWS_ACCESS_KEY_ID"],
            aws_secret_access_key=env["AWS_SECRET_ACCESS_KEY"], region_name=env["AWS_REGION"])
    def exists(key):
        try: s3.head_object(Bucket=bucket, Key=key); return True
        except Exception: return False
    # Arabella's meditations recorded on v4 from Frederick's dramatic
    # scripts (29 Sep): re-recorded beside his, from female/<id>.txt.
    female_too = {r["meditation_id"] for r in
        csv.DictReader(open(os.path.join(here, "female_v4_dramatic_meditations.csv")))}
    sets, spent, stopped = {}, 0, False
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
            if s3 and not force and exists(archive):
                print(f"{label}: already re-recorded, skipped", flush=True); continue
            path = os.path.join(here, folder, f"{mid}.txt")
            script = open(path).read().strip()
            if words(re.sub(r"\[[^\]]*\]", "", script)) != words(m["content"]):
                sys.exit(f"#{mid}: script words differ from the content; fix {path}")
            outdir = os.path.join(ROOT, "narration_out", f"{voice}_meditative"); os.makedirs(outdir, exist_ok=True)
            out = os.path.join(outdir, fn)
            cost = len(script) if force or not os.path.exists(out) else 0
            if cost:
                left = remaining_credits()
                if left - cost * rate < keep:
                    print(f"Stopped at {label} ({cost} characters): {left} credits left, "
                          f"keeping {keep}; {spent} characters sent", flush=True)
                    stopped = True; break
                audio = tts(VOICES[voice], script)
                if len(audio) < 1000: sys.exit(f"{label}: empty audio")
                open(out + ".part", "wb").write(audio); os.replace(out + ".part", out)
                spent += cost
                used = left - remaining_credits()
                if used > 0: measured = max(measured or 0, used / cost); rate = measured
            status = "saved"
            if s3:
                # voices/<voice>_pre_meditative/, never female_pre_v4/ (which
                # holds Arabella's v3 originals)
                if exists(key) and not exists(archive):
                    s3.copy_object(Bucket=bucket, Key=archive, CopySource={"Bucket": bucket, "Key": key})
                s3.upload_file(out, bucket, key, ExtraArgs={"ContentType": "audio/mpeg"})
                status = f"replaced live {voice} (old copy archived)"
            print(f"{label} {fn} {cost} characters · {status} · total {spent}", flush=True)
        if stopped: break
    print(f"Done: {spent} characters sent, about {rate:.2f} credits per character", flush=True)

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
    if upload:
        import boto3
        s3 = boto3.client("s3", aws_access_key_id=env["AWS_ACCESS_KEY_ID"],
            aws_secret_access_key=env["AWS_SECRET_ACCESS_KEY"], region_name=env["AWS_REGION"])
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
            audio = tts(vid, script)
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
