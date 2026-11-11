import { LaunchProps } from "@raycast/api";
import { runNavigationCommand } from "./lib/navigation-controller";

export default async function Command(
  props: LaunchProps<{ arguments: { input: string } }>,
) {
  await runNavigationCommand("ask", props.arguments.input);
}
