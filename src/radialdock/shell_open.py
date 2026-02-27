from __future__ import annotations

import os
from pathlib import Path


def open_path(path: str | Path) -> bool:
    candidate = Path(path)
    if not candidate.exists():
        return False
    os.startfile(str(candidate))  # type: ignore[attr-defined]
    return True
