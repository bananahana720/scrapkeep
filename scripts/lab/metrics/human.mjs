export default [
  {
    id: "agent_agreement",
    layer: "human",
    kind: "kpi",
    sentinel: false,
    thresholds: null,
    min_n: 5,
    says: "Share of the tags in Andrew's playtest verdicts that the bot also flags.",
  },
  {
    id: "unplayed_green",
    layer: "human",
    kind: "kri",
    sentinel: false,
    thresholds: { worse: "higher", warn: 2, fail: 4 },
    min_n: 1,
    says: "Gate-passing builds waiting for Andrew to play them.",
  },
];
