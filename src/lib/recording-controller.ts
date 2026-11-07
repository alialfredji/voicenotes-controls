import { closeMainWindow, showToast, Toast } from "@raycast/api";
import { RecordingCommand, runLocal } from "./voicenotes-local";

// State truth, preconditions, atomic cross-process locking, single dispatch, and
// bounded verification live together in the native helper. No remembered Boolean.
export async function runRecordingCommand(command: RecordingCommand) {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Checking Voicenotes…",
  });
  try {
    await closeMainWindow();
    const result = await runLocal(command);
    toast.style = result.ok ? Toast.Style.Success : Toast.Style.Failure;
    toast.title = result.message;
    if (!result.ok)
      toast.message = "Open Recording Setup and Status for details.";
  } catch (error) {
    toast.style = Toast.Style.Failure;
    toast.title = "Voicenotes control did not finish";
    toast.message = `${String(error)}. Check Voicenotes before retrying.`;
  }
}
