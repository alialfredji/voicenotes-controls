"""Live test utility: invoke only this extension and accept its one-shot URL prompt."""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

commands = {
    "start": ("start-recording", "Start Recording"),
    "stop": ("stop-recording", "Stop and Save Recording"),
    "cancel": ("cancel-recording", "Cancel Recording"),
    "status": ("recording-status", "Recording Setup and Status"),
}
name, title = commands[sys.argv[1]]
manifest = json.loads((Path(__file__).resolve().parents[1] / "package.json").read_text())
pid = subprocess.check_output(["rtk", "proxy", "pgrep", "-x", "Raycast"], text=True).strip()
subprocess.run(["rtk", "open", f"raycast://extensions/{manifest['author']}/{manifest['name']}/{name}"], check=True)
for _ in range(20):
    probe = subprocess.run(["rtk", "orca", "computer", "get-app-state", "--app", f"pid:{pid}", "--no-screenshot", "--json"], text=True, capture_output=True)
    state = json.loads(probe.stdout)
    if not state.get("ok"):
        code = state.get("error", {}).get("code")
        if code in ["window_not_found", "window_stale", "app_not_found"]:
            pid = subprocess.check_output(["rtk", "proxy", "pgrep", "-x", "Raycast"], text=True).strip()
            time.sleep(0.25)
            continue
        raise RuntimeError(state)
    tree = state.get("result", {}).get("snapshot", {}).get("treeText", "")
    if f"Request to run {title}" in tree:
        match = re.search(r"^\s*(\d+) button Run Command$", tree, re.M)
        if not match:
            raise RuntimeError("Expected exact Run Command control")
        click = ["rtk", "orca", "computer", "click", "--app", f"pid:{pid}", "--element-index", match[1], "--no-screenshot", "--json"]
        if "--foreground" in sys.argv:
            click.append("--restore-window")
        clicked = subprocess.run(click, capture_output=True, text=True)
        action = json.loads(clicked.stdout or "{}")
        if not action.get("ok"):
            print(json.dumps({"command": name, "uiActionConfirmed": False, "uiError": action.get("error", {}).get("code"), "next": "Inspect Voicenotes state independently; no action was retried."}))
            sys.exit(2)
        print(json.dumps({"command": name, "oneShotPromptAccepted": True}))
        break
    time.sleep(0.25)
else:
    raise RuntimeError("Expected this extension's one-shot command prompt; no click performed")
