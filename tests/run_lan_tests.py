"""Launch real host/client processes; any assertion, timeout, or absent pass fails."""
import pathlib
import subprocess
import sys
import time

repo = pathlib.Path(__file__).resolve().parent.parent
executable = '/Applications/Godot.app/Contents/MacOS/Godot'
script = sys.argv[1] if len(sys.argv) > 1 else 'lan_session_smoke.gd'
command = [executable, '--headless', '--path', str(repo), '--script', 'res://tests/' + script, '--']
host = subprocess.Popen(command + ['host'] + sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
time.sleep(0.5)
client = subprocess.Popen(command + ['client'] + sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
failed = False
for name, process in [('client', client), ('host', host)]:
    try:
        output = process.communicate(timeout=18)[0]
    except subprocess.TimeoutExpired:
        process.kill()
        output = process.communicate()[0]
        failed = True
        print(name, 'TIMEOUT', flush=True)
    print(name, process.returncode, output, flush=True)
    failed |= process.returncode != 0 or '_PASS' not in output or 'SCRIPT ERROR' in output
sys.exit(1 if failed else 0)
