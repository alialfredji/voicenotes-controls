import {
  Action,
  ActionPanel,
  Detail,
  open,
  showToast,
  Toast,
} from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import { RecordingResult, runLocal } from "./lib/voicenotes-local";

export default function Command() {
  const [result, setResult] = useState<RecordingResult>();
  const [loading, setLoading] = useState(true);
  const [failure, setFailure] = useState<string>();
  const refresh = useCallback(async () => {
    setLoading(true);
    setFailure(undefined);
    try {
      setResult(await runLocal("status"));
    } catch (error) {
      setFailure(String(error));
      await showToast({
        style: Toast.Style.Failure,
        title: "Cannot read Voicenotes status",
        message: String(error),
      });
    } finally {
      setLoading(false);
    }
  }, []);
  useEffect(() => {
    void refresh();
  }, [refresh]);
  const o = result?.observation;
  const markdown = o
    ? `# Voicenotes Local\n\n**State:** ${o.state}\n\n**App version:** ${o.appVersion ?? "Not installed"} (validated: 2.4.2)\n\n**Accessibility:** ${o.accessibility ? "Granted" : "Required"}\n\n**Event posting:** ${o.eventPosting ? "Granted" : "Required for Cancel"}\n\n## Available controls\n\n${Object.entries(
        o.controls,
      )
        .map(
          ([name, ready]) =>
            `- ${name}: ${ready ? "available" : "unavailable"}`,
        )
        .join(
          "\n",
        )}\n\n## Observed evidence\n\n${o.evidence.map((line) => `- ${line}`).join("\n")}\n\nObserved: ${o.timestamp}\n\nStart and Stop use native buttons. Cancel requires Voicenotes’ Option+C shortcut. Saved-note persistence is owned by Voicenotes; Stop confirms capture ended. No API token is needed for recording commands.\n\nIf Start is unavailable while viewing a note, the command can return to Home automatically. Sign in to Voicenotes first.\n\nIf permission is required, grant Raycast and/or voicenotes-control access in System Settings → Privacy & Security → Accessibility, then refresh. This extension does not require Screen Recording permission.`
    : `# Voicenotes Local\n\n${failure ?? (loading ? "Loading recording diagnostics…" : "No diagnostics returned. Refresh to retry.")}`;
  return (
    <Detail
      isLoading={loading}
      markdown={markdown}
      actions={
        <ActionPanel>
          <Action title="Refresh Status" onAction={refresh} />
          <Action
            title="Request Accessibility Access"
            onAction={async () => {
              await runLocal("request-accessibility");
              await refresh();
            }}
          />
          <Action
            title="Open Accessibility Settings"
            onAction={() =>
              open(
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
              )
            }
          />
          <Action.Open
            title="Open Voicenotes"
            target="/Applications/Voicenotes.app"
          />
          <Action.CopyToClipboard
            title="Copy Diagnostics"
            content={JSON.stringify(result, null, 2)}
          />
        </ActionPanel>
      }
    />
  );
}
