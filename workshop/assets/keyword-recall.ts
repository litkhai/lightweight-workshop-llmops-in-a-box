type ToolCall = {
  id: string;
  name: string;
  arguments: unknown;
  type: string;
  index: number;
};

type EvaluationContext = {
  observation: {
    input: unknown;
    output: unknown;
    metadata: unknown;
    toolCalls: ToolCall[];
  };
  experiment:
    | {
        itemExpectedOutput: unknown;
        itemMetadata: unknown;
      }
    | undefined;
};

type EvaluationResult = {
  scores: Array<{
    name: string;
    value: number;
    dataType: "NUMERIC";
    comment: string;
    metadata: Record<string, unknown>;
  }>;
};

const STOP_WORDS = new Set([
  "about", "after", "before", "from", "have", "into", "only", "open",
  "select", "then", "that", "their", "there", "these", "this", "through",
  "under", "when", "where", "which", "with", "your",
]);

function asText(value: unknown): string {
  if (typeof value === "string") return value;
  if (value && typeof value === "object") {
    const object = value as Record<string, unknown>;
    for (const key of ["expected_answer", "content", "text", "answer"]) {
      if (typeof object[key] === "string") return object[key] as string;
    }
    const choices = object.choices;
    if (Array.isArray(choices) && choices.length > 0) {
      return asText(choices[0]);
    }
    if (object.message) return asText(object.message);
  }
  return JSON.stringify(value ?? "");
}

function keywords(text: string): string[] {
  return Array.from(
    new Set(
      text
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, " ")
        .split(/\s+/)
        .filter((token) => token.length >= 4 && !STOP_WORDS.has(token)),
    ),
  );
}

function evaluate(ctx: EvaluationContext): EvaluationResult {
  const actual = asText(ctx.observation.output);
  const expected = asText(ctx.experiment?.itemExpectedOutput);
  const expectedKeywords = keywords(expected);
  const actualTokens = new Set(keywords(actual));
  const matched = expectedKeywords.filter((token) => actualTokens.has(token));
  const recall =
    expectedKeywords.length === 0 ? 0 : matched.length / expectedKeywords.length;

  return {
    scores: [
      {
        name: "workshop_keyword_recall",
        value: Number(recall.toFixed(4)),
        dataType: "NUMERIC",
        comment: `${matched.length}/${expectedKeywords.length} expected keywords matched.`,
        metadata: {
          matched,
          missing: expectedKeywords.filter((token) => !actualTokens.has(token)),
        },
      },
    ],
  };
}
