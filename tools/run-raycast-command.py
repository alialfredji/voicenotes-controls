"""Live test utility: invoke only this extension and accept its one-shot URL prompt."""
import json
import re
import subprocess
import sys
import time

commands = {
    "start": ("start-recording", "Start Recording"),
    "stop": ("stop-recording", "Stop and Save Recording"),
    "cancel": ("cancel-recording", "Cancel Recording"),
    "status": ("recording-status", "Recording Setup and Status"),
    "search": ("search-notes", "Search Notes"),
}
name, title = commands[sys.argv[1]]
pid = subprocess.check_output(["rtk", "proxy", "pgrep", "-x", "Raycast"], text=True).strip()
subprocess.run(["rtk", "open", f"raycast://extensions/parzival/voicenotes-local/{name}"], check=True)
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
        action = json.loads(subprocess.check_output(["rtk", "orca", "computer", "click", "--app", f"pid:{pid}", "--element-index", match[1], "--no-screenshot", "--json"], text=True))
        if not action.get("ok"):
            raise RuntimeError(action)
        print(json.dumps({"command": name, "oneShotPromptAccepted": True}))
        break
    time.sleep(0.25)
else:
    raise RuntimeError("Expected this extension's one-shot command prompt; no click performed")
