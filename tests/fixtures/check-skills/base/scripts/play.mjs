// Fixture stand-in for scripts/play.mjs, shaped like the real file closely
// enough for check-skills.mjs's static (regex, never-imported) parser: a
// top-level `verbs` array, `LAB_VERBS` / `LAB_SUBVERBS` objects, and a
// `verb === "lab"` literal comparison inside a labRoute-shaped function.
export function noop() {}

const verbs = ["play", "test", "watch", "shot", "list", "help"];
const LAB_VERBS = {
  stats: "stats-cli.mjs",
  gate: "gate.mjs",
  dash: "dash.mjs",
};
const LAB_SUBVERBS = {
  run: "harness.mjs",
  program: "program.mjs",
  verdicts: "verdicts.mjs",
};

export function labRoute(words) {
  const [verb] = words;
  if (verb === "lab") {
    return {};
  }
  return null;
}
