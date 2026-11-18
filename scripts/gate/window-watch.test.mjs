import assert from "node:assert/strict";
import test from "node:test";

import { windowCounts } from "./window-watch.mjs";

const rootPid = 400;
const unrelated = 900;
function sample(at, front, frontAncestors = [1], frontGroup = front) {
  return { at, front, frontAncestors, frontGroup, visible: [], godot: [], missed: 0 };
}

test("a windowless capture child taking focus invalidates an otherwise clear trace", () => {
  const rows = [sample(0, unrelated), sample(50, 401, [rootPid, 1]), sample(100, unrelated)];
  const counts = windowCounts(rows, rootPid);
  assert.equal(counts.onScreen, 0);
  assert.equal(counts.targetOnScreen, 0);
  assert.equal(counts.frontmostChanges, 1);
});

test("each newly foreground family PID counts, including a detached grandchild", () => {
  const rows = [
    sample(0, unrelated),
    sample(50, rootPid),
    sample(100, 402, [401, rootPid, 1], 402),
    sample(150, 402, [401, rootPid, 1], 402),
    sample(200, unrelated),
    sample(250, 403, [1], rootPid), // Reparented child that kept the capture group.
    sample(300, 901, [unrelated, 1]),
  ];
  assert.equal(windowCounts(rows, rootPid).frontmostChanges, 3);
});
