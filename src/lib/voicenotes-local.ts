import { control } from "swift:../../native";

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
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    const response = await Promise.race([
      control(command),
      new Promise<string>((_, reject) => {
        timeout = setTimeout(
          () =>
            reject(
              new Error(
                "Voicenotes did not respond in time. Check the app before retrying; no second action was sent.",
              ),
            ),
          45000,
        );
      }),
    ]);
    return JSON.parse(response) as RecordingResult;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}
