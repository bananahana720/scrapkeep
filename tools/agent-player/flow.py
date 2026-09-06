"""Orchard menu decisions from exact-window accessibility observations."""

import re

REWARD_NAMES = {
    "ground-loop": "Ground Loop",
    "brace-package": "Brace package",
    "echo": "Echo",
    "shear-package": "Shear package",
}
DIALOG_STATES = {
    "Click to take control": "capture",
    "Your lightning caster": "paused",
    "Make the next wave yours": "rewards",
    "The orchard is yours.": "won",
    "One more spark?": "lost",
}
START_BUTTON = "Enter the orchard ↗"


def _visible(node):
    return (
        node.get("showing") is True
        and node.get("visible") is True
        and not node.get("defunct")
        and not node.get("stale")
    )


def _nodes(observation):
    return [node for node in observation.get("nodes", []) if _visible(node)]


def _pressable(node):
    return (
        node.get("role") == 43
        and _visible(node)
        and node.get("enabled") is True
        and node.get("sensitive") is True
        and node.get("actions", []).count("press") == 1
        and isinstance(node.get("control_id"), str)
        and bool(node["control_id"])
    )


def _action(node):
    return {
        "name": node["name"],
        "control_id": node["control_id"],
        "action_name": "press",
    }


def classify(observation):
    """Recognize menus before considering positive HUD evidence as gameplay."""
    nodes = _nodes(observation)
    dialogs = [node for node in nodes if node.get("role") == 16]
    welcome = any(
        node.get("role") == 43 and node.get("name") == START_BUTTON for node in nodes
    )
    fatal = any(
        node.get("role") == 83 and node.get("name") == "The orchard could not start."
        for node in nodes
    )
    if len(dialogs) > 1 or sum((bool(dialogs), welcome, fatal)) > 1:
        return "unknown"
    if dialogs:
        return DIALOG_STATES.get(dialogs[0].get("name"), "unknown")
    if fatal:
        return "startup_error"
    if welcome:
        return "welcome"
    if observation.get("truncated"):
        return "unknown"
    names = {node.get("name", "") for node in nodes}
    hud = any(re.fullmatch(r"WAVE [1-3] / 3", name) for name in names) or (
        "Abilities" in names
        and any(
            node.get("role") == 43 and node.get("name") == "I Dashboard"
            for node in nodes
        )
    )
    if "HULL" in names and hud:
        return "playing"
    return "unknown"


def select_button(observation, name):
    """Return one exact usable button, refusing incomplete or ambiguous trees."""
    if observation.get("truncated"):
        return None
    matches = [
        node
        for node in _nodes(observation)
        if node.get("role") == 43 and node.get("name") == name
    ]
    if len(matches) != 1 or not _pressable(matches[0]):
        return None
    return _action(matches[0])


def choose_action(observation, preferences):
    """Choose the next menu action. Terminal restart is the caller's policy."""
    if any(reward_id not in REWARD_NAMES for reward_id in preferences):
        raise ValueError("Unknown orchard reward preference")
    state = classify(observation)
    if state == "welcome":
        return select_button(observation, START_BUTTON)
    if state == "capture":
        return select_button(observation, "Capture mouse & resume")
    if state == "paused":
        names = {
            node.get("name") for node in _nodes(observation) if node.get("role") == 43
        }
        options = names & {"Resume play", "Back to rewards"}
        return (
            select_button(observation, next(iter(options)))
            if len(options) == 1
            else None
        )
    if state != "rewards" or observation.get("truncated"):
        return None
    buttons = [node for node in _nodes(observation) if node.get("role") == 43]
    continuations = [
        node
        for node in buttons
        if re.fullmatch(r"Continue to wave [23]", node.get("name", ""))
        and _pressable(node)
    ]
    if continuations:
        if len(continuations) != 1:
            return None
        return select_button(observation, continuations[0]["name"])
    for reward_id in preferences:
        prefix = "CHOOSE ONE " + REWARD_NAMES[reward_id]
        matches = [
            node
            for node in buttons
            if (normalized := " ".join(node.get("name", "").split())) == prefix
            or normalized.startswith(prefix + " ")
        ]
        if len(matches) > 1:
            return None
        if len(matches) == 1 and _pressable(matches[0]):
            return dict(_action(matches[0]), reward_id=reward_id)
    return None
