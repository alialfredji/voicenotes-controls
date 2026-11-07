import { environment } from "@raycast/api";
import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";
import { chmod } from "node:fs/promises";

export type RecordingCommand = "start" | "stop" | "cancel";
export interface RecordingResult {
  ok: boolean;
  message: string;
  dispatched: boolean;
  observation: {
    state: string;
    timestamp: string;
    appVersion?: string;
    accessibility: boolean;
    eventPosting: boolean;
    controls: Record<string, boolean>;
    evidence: string[];
  };
}

export async function runLocal(
  command: RecordingCommand | "status" | "request-accessibility",
) {
  const helper = path.join(environment.assetsPath, "voicenotes-control");
  // Raycast copies assets with mode 0644. Restore execution on our own helper.
  await chmod(helper, 0o700);
  const { stdout } = await promisify(execFile)(helper, [command], {
    timeout: 20000,
    maxBuffer: 64 * 1024,
  });
  return JSON.parse(stdout) as RecordingResult;
}
