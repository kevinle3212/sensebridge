// Runs another command with `.env` already loaded.
//
//   node scripts/with-env.js npx --yes @railway/cli status
//
// For the external CLIs the `railway:*` and `vercel:*` npm scripts wrap. They
// read their credentials (`RAILWAY_TOKEN`, `VERCEL_TOKEN`) from the
// environment, and cannot be made to read a `.env` the way load-env.js fixes
// for our own scripts — so this loads it and hands the process over.
//
// The command runs unchanged: same stdio, same exit code, same signal. This is
// a wrapper, not a runner with opinions.
import { spawn } from "node:child_process";
import "./load-env.js";

const [command, ...args] = process.argv.slice(2);
if (!command) {
  console.error("usage: node scripts/with-env.js <command> [args...]");
  process.exit(2);
}

// The command comes from package.json, not from user input.
const child = spawn(command, args, { stdio: "inherit" });
child.on("error", (error) => {
  console.error(`with-env: cannot run '${command}': ${error.message}`);
  process.exit(127);
});
// Re-raise the child's signal rather than reporting success: a CLI killed by
// Ctrl-C must not look like a clean exit to whatever called npm.
child.on("exit", (code, signal) => {
  if (signal) process.kill(process.pid, signal);
  else process.exit(code ?? 0);
});
