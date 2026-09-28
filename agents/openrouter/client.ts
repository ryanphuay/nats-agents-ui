export async function complete(
  prompt: string,
  apiKey: string,
  model = "openrouter/free",
  request: typeof fetch = fetch,
): Promise<string> {
  if (!apiKey.trim()) throw new Error("OPENROUTER_API_KEY is required");
  const result = await request("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: "You are a helpful assistant in a NATS agent demo. You have no filesystem, shell, or browsing tools. Work only with supplied text; never claim to have inspected files or executed commands." },
        { role: "user", content: prompt },
      ],
      max_tokens: 2048,
      stream: false,
    }),
    signal: AbortSignal.timeout(90_000),
  });
  // Do not relay provider bodies: they may echo request content or credentials.
  if (!result.ok) {
    if (result.status === 429) throw new Error("OpenRouter rate limit reached; try again later");
    if (result.status === 401 || result.status === 403) throw new Error("OpenRouter rejected the API key or access permissions");
    if (result.status === 402) throw new Error("OpenRouter quota or credits unavailable; check your account and model");
    throw new Error(`OpenRouter request failed (HTTP ${result.status})`);
  }
  const body = await result.json();
  if (body.error) throw new Error("OpenRouter returned a provider error; try again later or choose another model");
  const text = body.choices?.[0]?.message?.content;
  if (typeof text !== "string" || !text.trim()) throw new Error("OpenRouter returned no text response");
  return text.trim();
}
