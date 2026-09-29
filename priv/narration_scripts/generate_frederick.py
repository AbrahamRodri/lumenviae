#!/usr/bin/env python3
"""Record meditations with Eleven v4 and hand-tagged ("enhanced") scripts, then upload.

    python3 -u priv/narration_scripts/generate_frederick.py SET_ID [--voice frederick|female]
        [--ids 228,251] [--no-upload] [--force]

Scripts: priv/narration_scripts/frederick/<meditation_id>.txt (direction tags live only
there, never in stored content; the same tagged script serves every voice). Each
script's words are checked against the live content, or against
priv/narration_scripts/pending_text_fixes.json when a text fix for that id is waiting
to be applied to the database.

frederick: saves narration_out/frederick/<filename>, uploads voices/frederick/<filename>
  (skips existing keys unless --force). No database writes.
female: saves narration_out/female/<filename>; before overwriting the live
  voices/female/<filename> it copies the current object to
  voices/female_pre_v4/<filename> (once). Use --ids to limit to changed meditations.
"""
import json, os, re, sys, urllib.request
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

def main():
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
        path = os.path.join(ROOT, "priv/narration_scripts/frederick", f"{m['id']}.txt")
        script = open(path).read().strip()
        content = fixes.get(str(m["id"]), m["content"])
        if words(re.sub(r"\[[^\]]*\]", "", script)) != words(content):
            sys.exit(f"#{m['id']}: script words differ from the content; fix {path}")
        out = os.path.join(outdir, fn)
        if force or not os.path.exists(out):
            req = urllib.request.Request(
                f"https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=mp3_44100_128",
                data=json.dumps({"text": script, "model_id": MODEL, "voice_settings": SETTINGS}).encode(),
                headers={"xi-api-key": env["ELEVEN_LABS_API_KEY"], "Content-Type": "application/json", "Accept": "audio/mpeg"})
            with urllib.request.urlopen(req, timeout=150) as r: audio = r.read()
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
