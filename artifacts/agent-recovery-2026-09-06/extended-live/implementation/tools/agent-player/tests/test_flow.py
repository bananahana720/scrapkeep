"""Boundary fixtures follow Chromium AT-SPI roles and orchard menu copy."""

import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "flow", Path(__file__).parents[1] / "flow.py"
)
flow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(flow)


def node(name, role=43, **changes):
    return {
        "name": name,
        "role": role,
        "showing": True,
        "visible": True,
        "enabled": True,
        "sensitive": True,
        "defunct": False,
        "stale": False,
        "control_id": "opaque-" + name,
        "actions": ["press", "showContextMenu"],
        **changes,
    }


def observation(*nodes, truncated=False):
    return {
        "nodes": list(nodes),
        "truncated": truncated,
        "observation_id": "one-use-observation",
        "one_use": True,
    }


def menu(title, *nodes, **kwargs):
    return observation(node(title, 16), *nodes, **kwargs)


class ClassificationTests(unittest.TestCase):
    def test_named_dialogs_ignore_duplicate_title_text(self):
        for title, state in flow.DIALOG_STATES.items():
            with self.subTest(state=state):
                self.assertEqual(
                    flow.classify(menu(title, node(title, 83), node(title, 116))), state
                )

    def test_heading_without_dialog_cannot_establish_menu(self):
        self.assertEqual(
            flow.classify(observation(node("One more spark?", 83))), "unknown"
        )

    def test_hud_is_positive_evidence_but_does_not_override_modal(self):
        hud = [node("WAVE 1 / 3", 116), node("HULL", 116)]
        self.assertEqual(flow.classify(observation(*hud)), "playing")
        self.assertEqual(flow.classify(menu("Your lightning caster", *hud)), "paused")
        self.assertEqual(flow.classify(observation(*hud, truncated=True)), "unknown")
        self.assertEqual(flow.classify(observation(hud[0])), "unknown")
        self.assertEqual(flow.classify(observation()), "unknown")

    def test_hidden_and_stale_markers_are_ignored(self):
        for change in (
            {"showing": False},
            {"visible": False},
            {"stale": True},
            {"defunct": True},
        ):
            self.assertEqual(
                flow.classify(observation(node(flow.START_BUTTON, **change))), "unknown"
            )

    def test_conflicting_states_and_unknown_dialog_refuse_play(self):
        self.assertEqual(
            flow.classify(menu("One more spark?", node(flow.START_BUTTON))), "unknown"
        )
        self.assertEqual(
            flow.classify(menu("One more spark?", node("The orchard is yours.", 16))),
            "unknown",
        )
        self.assertEqual(
            flow.classify(
                menu("unexpected", node("HULL", 116), node("WAVE 1 / 3", 116))
            ),
            "unknown",
        )

    def test_truncated_visible_menu_still_has_known_state(self):
        view = menu("Your lightning caster", node("Resume play"), truncated=True)
        self.assertEqual(flow.classify(view), "paused")
        self.assertIsNone(flow.choose_action(view, []))

    def test_startup_error_requires_heading(self):
        self.assertEqual(
            flow.classify(observation(node("The orchard could not start.", 83))),
            "startup_error",
        )
        self.assertEqual(
            flow.classify(observation(node("The orchard could not start.", 116))),
            "unknown",
        )


class SelectionTests(unittest.TestCase):
    def test_button_role_prevents_same_label_text_ambiguity(self):
        control = node("Resume play", control_id="fresh-control-123")
        view = menu("Your lightning caster", control, node("Resume play", 116))
        result = flow.choose_action(view, [])
        self.assertEqual(
            result,
            {
                "name": "Resume play",
                "control_id": "fresh-control-123",
                "action_name": "press",
            },
        )
        self.assertEqual(view["observation_id"], "one-use-observation")
        self.assertEqual(control["control_id"], "fresh-control-123")

    def test_duplicate_buttons_refuse_even_if_one_disabled(self):
        for enabled in (True, False):
            view = observation(
                node("Resume play"), node("Resume play", enabled=enabled)
            )
            self.assertIsNone(flow.select_button(view, "Resume play"))

    def test_capability_and_liveness_required(self):
        changes = [
            {"enabled": False},
            {"sensitive": False},
            {"showing": False},
            {"visible": False},
            {"stale": True},
            {"defunct": True},
            {"actions": ["showContextMenu"]},
            {"actions": ["press", "press"]},
            {"control_id": ""},
            {"role": 83},
        ]
        for change in changes:
            self.assertIsNone(
                flow.select_button(
                    observation(node("Resume play", **change)), "Resume play"
                )
            )

    def test_simple_menu_actions_and_restart_policy(self):
        cases = [
            (observation(node(flow.START_BUTTON)), flow.START_BUTTON),
            (
                menu("Click to take control", node("Capture mouse & resume")),
                "Capture mouse & resume",
            ),
            (menu("Your lightning caster", node("Back to rewards")), "Back to rewards"),
        ]
        for view, name in cases:
            self.assertEqual(flow.choose_action(view, [])["name"], name)
        for title in ("The orchard is yours.", "One more spark?"):
            view = menu(title, node("Start a fresh run"))
            self.assertIsNone(flow.choose_action(view, []))
            self.assertEqual(
                flow.select_button(view, "Start a fresh run")["name"],
                "Start a fresh run",
            )

    def test_conflicting_resume_controls_refuse(self):
        view = menu(
            "Your lightning caster", node("Resume play"), node("Back to rewards")
        )
        self.assertIsNone(flow.choose_action(view, []))

    def test_reward_preference_uses_real_names_and_descriptions(self):
        ground = (
            "CHOOSE ONE\nGround Loop\nBody impacts chain lightning to nearby enemies."
        )
        brace = "CHOOSE ONE Brace package Two Brace parts improve burst recovery and damage protection."
        view = menu(
            "Make the next wave yours",
            node(ground),
            node(brace),
            node("Continue to wave 2", enabled=False),
        )
        selected = flow.choose_action(view, ["echo", "brace-package", "ground-loop"])
        self.assertEqual(selected["reward_id"], "brace-package")
        self.assertEqual(selected["name"], brace)
        self.assertEqual(flow.choose_action(view, ["ground-loop"])["name"], ground)
        self.assertIsNone(flow.choose_action(view, ["shear-package"]))

    def test_all_reward_ids_match_actual_names(self):
        for reward_id, name in flow.REWARD_NAMES.items():
            view = menu(
                "Make the next wave yours", node("CHOOSE ONE " + name + " Description.")
            )
            self.assertEqual(
                flow.choose_action(view, [reward_id])["reward_id"], reward_id
            )

    def test_reward_duplicates_and_near_names_refuse(self):
        label = "CHOOSE ONE Echo Description."
        self.assertIsNone(
            flow.choose_action(
                menu("Make the next wave yours", node(label), node(label)), ["echo"]
            )
        )
        self.assertIsNone(
            flow.choose_action(
                menu(
                    "Make the next wave yours", node("CHOOSE ONE Echoing Description.")
                ),
                ["echo"],
            )
        )

    def test_enabled_continue_wins_after_reward_selection(self):
        view = menu(
            "Make the next wave yours",
            node("CHOOSE ONE Echo Description.", enabled=False),
            node("Continue to wave 3"),
        )
        self.assertEqual(
            flow.choose_action(view, ["echo"])["name"], "Continue to wave 3"
        )
        view["nodes"].append(node("Continue to wave 2"))
        self.assertIsNone(flow.choose_action(view, ["echo"]))

    def test_disabled_continue_never_selected(self):
        view = menu(
            "Make the next wave yours", node("Continue to wave 2", enabled=False)
        )
        self.assertIsNone(flow.choose_action(view, []))

    def test_unknown_configuration_is_explicit_error(self):
        with self.assertRaises(ValueError):
            flow.choose_action(observation(), ["invented-reward"])


if __name__ == "__main__":
    unittest.main()


class RealHUDEvidenceTests(unittest.TestCase):
    def test_static_hud_can_identify_play_when_dynamic_text_is_omitted(self):
        nodes = [
            {"name": name, "role": role, "visible": True, "showing": True}
            for name, role in [("HULL", 116), ("Abilities", 110), ("I Dashboard", 43)]
        ]
        self.assertEqual(flow.classify({"nodes": nodes, "truncated": False}), "playing")
        self.assertEqual(
            flow.classify({"nodes": nodes[1:], "truncated": False}), "unknown"
        )
