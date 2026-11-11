import { closeMainWindow, showToast, Toast } from "@raycast/api";
import { navigate } from "swift:../../native";
import { RecordingResult } from "./voicenotes-local";

export async function runNavigationCommand(action: string, input = "") {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Opening Voicenotes…",
  });
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    await closeMainWindow();
    const response = await Promise.race([
      navigate(action, input),
      new Promise<string>((_, reject) => {
        timeout = setTimeout(
          () =>
            reject(
              new Error(
                "Voicenotes did not respond in time; no retry was sent",
              ),
            ),
          45000,
        );
      }),
    ]);
    const result = JSON.parse(response) as RecordingResult;
    toast.style = result.ok ? Toast.Style.Success : Toast.Style.Failure;
    toast.title = result.message;
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Voicenotes action did not finish";
    toast.message = `${String(error)}. Check the app before retrying.`;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}
