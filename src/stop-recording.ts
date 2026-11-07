import { runRecordingCommand } from "./lib/recording-controller";
export default async function Command() {
  await runRecordingCommand("stop");
}
