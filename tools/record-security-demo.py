"""Capture actual sqlcmd runs as a narrated-by-captions console video (no synthetic PASS).
Requires Pillow and ffmpeg with MJPEG decoding / VP9 encoding. Not a desktop/SSMS recording.
Usage: python tools/record-security-demo.py --ffmpeg PATH --database FreshVend_S217_Clean_20261115
"""
import argparse, datetime, hashlib, io, json, re, subprocess, time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

p = argparse.ArgumentParser()
p.add_argument('--ffmpeg', required=True)
p.add_argument('--server', default=r'.\SQLEXPRESS')
p.add_argument('--database', required=True)
a = p.parse_args()
if not re.fullmatch(r'FreshVend_(?:S|QA)[A-Za-z0-9_]+', a.database):
    raise SystemExit('Use a dedicated QA database')
root = Path(__file__).resolve().parent.parent
out = root / 'docs/evidence/SCRUM-230'
out.mkdir(parents=True, exist_ok=True)
stage = root / '.local-test/security-video'
stage.mkdir(parents=True, exist_ok=True)
movie = out / 'security-demo.webm'
font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 19)
heading = ImageFont.truetype('C:/Windows/Fonts/consolab.ttf', 28)
started = datetime.datetime.now().astimezone().isoformat()
encoder_log = (stage / 'encoder.log').open('wb')
encoder = subprocess.Popen([a.ffmpeg, '-y', '-f', 'image2pipe', '-vcodec', 'mjpeg', '-r', '2', '-i', 'pipe:0',
    '-an', '-c:v', 'libvpx-vp9', '-deadline', 'realtime', '-cpu-used', '8', '-b:v', '700k',
    str(movie)], stdin=subprocess.PIPE, stdout=encoder_log, stderr=subprocess.STDOUT,
    creationflags=subprocess.CREATE_NO_WINDOW)
frames = 0
def frame(title, lines, footer):
    global frames
    im = Image.new('RGB', (1440, 900), '#101923')
    d = ImageDraw.Draw(im)
    d.text((28, 20), 'FreshVend | SCRUM-230 | live SQL console', font=heading, fill='#71dcc1')
    d.text((28, 64), title, font=font, fill='white')
    d.text((28, 94), 'Actual sqlcmd execution | SQL Server 2022 Express | captions, no audio', font=font, fill='#afbecd')
    y = 140
    for line in lines[-26:]:
        d.text((28, y), line[:115], font=font, fill='#71dcc1' if 'PASS' in line else '#dee7ef')
        y += 26
    d.text((28, 840), footer[:115], font=font, fill='#f4c266')
    d.text((28, 867), datetime.datetime.now().astimezone().isoformat(timespec='seconds'), font=font, fill='#afbecd')
    b = io.BytesIO(); im.save(b, format='JPEG', quality=90); encoder.stdin.write(b.getvalue()); frames += 1
    return im

runs = []
try:
    for script, label in [('tests_auth.sql', '18 auth/RBAC/RLS cases; each fixture rolled back'),
                          ('demo_security.sql', 'RLS -> FULL + DIFF -> accidental DELETE -> LOG -> STOPAT restore')]:
        source = (root / 'tests' / script).read_text(encoding='utf-8-sig').replace('FreshVendDB', a.database)
        staged = stage / script; staged.write_text(source, encoding='utf-8-sig')
        log = out / script.replace('.sql', '.log')
        if log.exists(): log.unlink()
        cmd = ['sqlcmd', '-S', a.server, '-E', '-C', '-I', '-b', '-d', a.database, '-i', str(staged), '-o', str(log), '-u']
        proc = subprocess.Popen(cmd, creationflags=subprocess.CREATE_NO_WINDOW)
        while True:
            text = log.read_text(encoding='utf-16', errors='ignore') if log.exists() and log.stat().st_size > 2 else ''
            lines = [' '.join(s.split()) for s in text.splitlines() if s.strip() and not set(s.strip()) <= {'-', ' '}]
            if script == 'tests_auth.sql':
                selected = [s for s in lines if re.match(r'^\d+ (CreateUser|Login|ChangePassword|AssignMachine|DeactivateUser|RLS|Operator|Kiosk)', s)]
                shown = selected + [s for s in lines if '18/18 PASS' in s or s.startswith('Msg ')]
            else:
                shown = [s for s in lines if any(x in s for x in ['RLS', 'successfully', 'STOPAT', 'Incident committed', 'STOPAT fruit', 'Msg ', 'PASS FreshVend'])]
            im = frame(label, shown or ['Running real SQL; waiting for flushed output...'], f'Database: {a.database} | exit={proc.poll()}')
            time.sleep(.5)
            if proc.poll() is not None:
                # sqlcmd may flush its redirected output only as it exits.
                text = log.read_text(encoding='utf-16', errors='ignore')
                lines = [' '.join(s.split()) for s in text.splitlines() if s.strip() and not set(s.strip()) <= {'-', ' '}]
                if script == 'tests_auth.sql':
                    shown = [s[:100] + (' [PASS]' if s.endswith('PASS') else ' [FAIL]') for s in lines if re.match(r'^\d+ (CreateUser|Login|ChangePassword|AssignMachine|DeactivateUser|RLS|Operator|Kiosk)', s)]
                    shown += [s for s in lines if '18/18 PASS' in s or s.startswith('Msg ')]
                else:
                    shown = [s for s in lines if any(x in s for x in ['RLS', 'successfully', 'STOPAT', 'Incident committed', 'STOPAT fruit', 'Msg '])]
                for _ in range(12):
                    im = frame(label, shown, f'sqlcmd exit {proc.returncode} | full log: {log.name}'); time.sleep(.5)
                im.save(out / script.replace('.sql', '.png'))
                runs.append({'script': script, 'exitCode': proc.returncode, 'log': log.name,
                             'sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
                if proc.returncode: raise RuntimeError(f'{script} failed; do not publish a PASS video')
                break
finally:
    encoder.stdin.close(); encoder.wait(timeout=60); encoder_log.close()
if encoder.returncode: raise SystemExit('Video encoder failed: inspect encoder.log')
(out / 'recording.json').write_text(json.dumps({'startedAt': started, 'completedAt': datetime.datetime.now().astimezone().isoformat(),
    'server': a.server, 'database': a.database, 'capture': 'Live automated SQL console, not SSMS screen recording',
    'fps': 2, 'frames': frames, 'durationSeconds': frames / 2, 'video': movie.name,
    'videoSha256': hashlib.sha256(movie.read_bytes()).hexdigest(), 'runs': runs}, indent=2), encoding='utf-8')
print(f'Video captured from real SQL runs: {movie}, {frames / 2}s')

