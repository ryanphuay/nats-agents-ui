import { expect, test } from "bun:test";
import { complete } from "./client.ts";

function mock(status: number, body: unknown): typeof fetch {
  return (async () => new Response(JSON.stringify(body), { status })) as typeof fetch;
}
test("uses authenticated free router with bounded text-only requests", async () => {
  const request = (async (url: string, options: RequestInit) => {
    expect(url).toBe("https://openrouter.ai/api/v1/chat/completions");
    expect(options.headers).toMatchObject({ Authorization: "Bearer test-key" });
    const body = JSON.parse(options.body as string);
    expect(body.model).toBe("openrouter/free");
    expect(body.messages[1]).toEqual({ role: "user", content: "hello" });
    expect(body.max_tokens).toBe(2048);
    expect(body.tools).toBeUndefined();
    expect(options.signal).toBeInstanceOf(AbortSignal);
    return new Response(JSON.stringify({ choices: [{ message: { content: " hello back " } }] }));
  }) as typeof fetch;
  expect(await complete("hello", "test-key", undefined, request)).toBe("hello back");
});
test("supports explicit model selection", async () => {
  const request = (async (_url: string, options: RequestInit) => {
    expect(JSON.parse(options.body as string).model).toBe("example/model:free");
    return new Response(JSON.stringify({ choices: [{ message: { content: "ok" } }] }));
  }) as typeof fetch;
  await complete("hello", "test", "example/model:free", request);
});
for (const [status, message] of [[401, "API key"], [403, "API key"], [402, "quota"], [429, "rate limit"], [500, "HTTP 500"]] as const) {
  test(`handles HTTP ${status} without exposing provider body`, async () => {
    await expect(complete("hi", "test", undefined, mock(status, { error: "secret" }))).rejects.toThrow(message);
  });
}
test("rejects provider errors and empty responses", async () => {
  await expect(complete("hi", "test", undefined, mock(200, { error: {} }))).rejects.toThrow("provider error");
  await expect(complete("hi", "test", undefined, mock(200, { choices: [] }))).rejects.toThrow("no text");
});
test("rejects missing credentials before network access", async () => {
  await expect(complete("hi", " ", undefined, (() => { throw new Error("network called"); }) as typeof fetch)).rejects.toThrow("API_KEY");
});
