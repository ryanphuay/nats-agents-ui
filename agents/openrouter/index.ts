import { readFileSync } from "node:fs";
import { connect, credsAuthenticator } from "@nats-io/transport-node";
import { AgentService, splitResponseText } from "@synadia-ai/agent-service";
import { complete } from "./client.ts";

const apiKey = process.env.OPENROUTER_API_KEY;
const credsPath = process.env.NATS_CREDS;
const model = process.env.OPENROUTER_MODEL || "openrouter/free";
if (!apiKey?.trim()) throw new Error("OPENROUTER_API_KEY is required");
if (!credsPath) throw new Error("NATS_CREDS is required");
const nc = await connect({
  servers: process.env.NATS_URL ?? "nats://127.0.0.1:15222",
  name: "openrouter-agent",
  authenticator: credsAuthenticator(readFileSync(credsPath)),
});
const service = new AgentService({
  nc, agent: "openrouter", owner: "demo", name: "main", session: "main",
  description: "OpenRouter hosted model — text-only, no local tools",
  version: "0.1.0", heartbeatIntervalS: 5, keepaliveIntervalS: 15,
  attachmentsOk: false,
  extraMetadata: { bridge: "openrouter-api", model, permission_policy: "no-tools" },
});
service.onPrompt(async (envelope, response) => {
  await response.send({ type: "status", status: "Waiting for OpenRouter" });
  try {
    const answer = await complete(envelope.prompt, apiKey, model);
    for (const chunk of splitResponseText(answer, 1024 * 1024)) await response.send(chunk);
  } catch (error) {
    const message = error instanceof Error && error.message.startsWith("OpenRouter")
      ? error.message : "OpenRouter network request failed or timed out";
    await response.send(message);
  }
});
await service.start();
console.log(`openrouter agent listening on ${service.subject.prompt}`);
async function shutdown() {
  await service.stop();
  await nc.close();
  process.exit(0);
}
process.on("SIGINT", () => void shutdown());
process.on("SIGTERM", () => void shutdown());
