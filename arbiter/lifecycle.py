"""Normalized lifecycle states for provider sessions."""

from __future__ import annotations

from enum import Enum


class LifecycleState(str, Enum):
    """Provider-neutral session lifecycle states."""

    UNINITIALIZED = "uninitialized"
    READY = "ready"
    STARTING = "starting"
    RUNNING = "running"
    WAITING_FOR_AUTH = "waiting_for_auth"
    WAITING_FOR_PERMISSION = "waiting_for_permission"
    COMPLETED = "completed"
    FAILED = "failed"
    STOPPING = "stopping"
    STOPPED = "stopped"
