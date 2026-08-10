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
    value: boolean;
    dataType: "BOOLEAN";
    comment: string;
    metadata: Record<string, unknown>;
  }>;
};

function evaluate(ctx: EvaluationContext): EvaluationResult {
  const inputText =
    typeof ctx.observation.input === "string"
      ? ctx.observation.input
      : JSON.stringify(ctx.observation.input ?? "");

  const match = inputText.match(/[A-Z]{6,}/);
  const detected = match !== null;

  return {
    scores: [
      {
        name: "workshop_all_caps_signal",
        value: detected,
        dataType: "BOOLEAN",
        comment: detected
          ? `Detected all-caps run: ${match?.[0]}`
          : "No run of six uppercase English letters was detected.",
        metadata: {
          rule: "uppercase_run_gte_6",
          match: match?.[0] ?? null,
        },
      },
    ],
  };
}
