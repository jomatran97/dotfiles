"""Structured audit logging with conservative redaction."""

from __future__ import annotations

from dataclasses import asdict, is_dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import re
from typing import Any, Mapping, Optional

SECRET_NAME_RE = re.compile(r"(api[_-]?key|token|secret|password|passwd|credential|authorization|cookie)", re.I)
SECRET_VALUE_PATTERNS = (
    re.compile(r"sk-[A-Za-z0-9_-]{16,}"),
    re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._~+/-]+=*"),
    re.compile(r"(?i)(authorization\s*[:=]\s*)[^\s,}]+"),
)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


class Redactor:
    """Redacts common secret names and token-like values."""

    replacement = "[REDACTED]"

    def redact(self, value: Any, *, key: Optional[str] = None) -> Any:
        if key and SECRET_NAME_RE.search(key):
            if value in (None, ""):
                return value
            return self.replacement
        if isinstance(value, Mapping):
            return {str(k): self.redact(v, key=str(k)) for k, v in value.items()}
        if isinstance(value, list):
            return [self.redact(v) for v in value]
        if isinstance(value, tuple):
            return tuple(self.redact(v) for v in value)
        if is_dataclass(value):
            return self.redact(asdict(value))
        if isinstance(value, str):
            redacted = value
            for pattern in SECRET_VALUE_PATTERNS:
                redacted = pattern.sub(lambda m: (m.group(1) if m.groups() else "") + self.replacement, redacted)
            return redacted
        return value


class AuditLogger:
    """JSONL audit logger."""

    def __init__(self, log_dir: Path, *, redactor: Optional[Redactor] = None) -> None:
        self.log_dir = log_dir
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.redactor = redactor or Redactor()

    def write(self, name: str, event: Mapping[str, Any]) -> Path:
        path = self.log_dir / f"{name}.jsonl"
        record = {
            "timestamp": utc_now_iso(),
            **self.redactor.redact(dict(event)),
        }
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, sort_keys=True, default=str) + "\n")
        return path
