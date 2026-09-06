"""The caller holds one workspace lock for each bounded combat segment."""

import time

from observer import Observer


class PerceptionFailure(RuntimeError):
    pass


def play(
    desktop,
    policy,
    seconds,
    evidence,
    *,
    active_limit=None,
    observer_factory=Observer,
    clock=time.monotonic,
    sleep=time.sleep,
):
    started = previous = clock()
    frames, gaps, actions = [], [], []
    reason = "segment_limit"
    previous_intent = None
    last_frame = None
    observer = None
    try:
        with observer_factory(desktop) as observer, desktop.native() as controller:
            while clock() - started < seconds:
                now = clock()
                dt = now - previous
                previous = now
                gaps.append(dt * 1000)
                if active_limit is not None and policy.elapsed >= active_limit:
                    reason = "active_limit"
                    break
                if observer.error is not None:
                    raise PerceptionFailure(f"capture failed: {observer.error}")
                frame = observer.latest
                if frame is None:
                    if now - started > 2:
                        raise PerceptionFailure(
                            f"no first frame ({getattr(observer, 'phase', 'unknown stage')})"
                        )
                    controller.tick()
                    sleep(0.02)
                    continue
                age = now - frame["time"]
                if age > 0.75:
                    raise PerceptionFailure("stale frame")
                if frame["modal"]:
                    reason = "menu_candidate"
                    break
                if age >= 0.5:
                    controller.release()
                    sleep(0.02)
                    continue
                fresh = frame["id"] != last_frame
                if fresh:
                    policy.aim(frame)
                    last_frame = frame["id"]
                    frames.append(
                        {
                            "frame_id": frame["id"],
                            "active_seconds": policy.elapsed,
                            "frame_age_ms": age * 1000,
                            "capture_ms": frame["capture_ms"],
                            "observe_ms": frame["observe_ms"],
                            "targets": len(frame["targets"]),
                        }
                    )
                    frames[-1].update(
                        width=frame["width"],
                        height=frame["height"],
                        lower_sky_fraction=frame.get("lower_sky_fraction"),
                        recovering_sky=policy.recovering_sky,
                    )
                    evidence.frame(frame)
                intent = policy.step(dt)
                if fresh or intent != previous_intent:
                    controller.set_state(
                        intent.keys,
                        intent.buttons,
                        intent.look,
                        lease_seconds=max(0.001, 0.5 - age),
                    )
                    if intent != previous_intent:
                        actions.append(
                            {
                                "elapsed": now - started,
                                "active_seconds": policy.elapsed,
                                "keys": intent.keys,
                                "buttons": intent.buttons,
                                "look": intent.look,
                            }
                        )
                    previous_intent = intent
                controller.tick()
                sleep(max(0, 0.02 - (clock() - now)))
            controller.release()
    except BaseException as exc:
        reason = f"{type(exc).__name__}: {exc}"
        raise
    finally:
        evidence.event(
            "combat_segment",
            reason=reason,
            wall_seconds=clock() - started,
            active_seconds=policy.elapsed,
            actions=actions,
            frames=frames,
            tick_gaps_ms=gaps,
            observer_phase=getattr(observer, "phase", None),
            capture_phase=getattr(desktop, "capture_phase", None),
            capture_error=str(observer.error)
            if observer is not None and observer.error is not None
            else None,
        )
    return reason
