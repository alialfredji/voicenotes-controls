import { runNavigationCommand } from "./lib/navigation-controller";

export default async function Command() {
  await runNavigationCommand("copy-latest-dictation");
}
