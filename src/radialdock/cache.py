from __future__ import annotations

import sqlite3
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CacheEntry:
    path: str
    mtime: float
    thumb_path: str


class ThumbnailCache:
    def __init__(self, root_dir: Path) -> None:
        self.root_dir = root_dir
        self.db_path = self.root_dir / "thumbs.sqlite3"
        self.thumb_dir = self.root_dir / "thumbs"
        self.root_dir.mkdir(parents=True, exist_ok=True)
        self.thumb_dir.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()

    def _ensure_schema(self) -> None:
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS thumbnails (
                    path TEXT PRIMARY KEY,
                    mtime REAL NOT NULL,
                    thumb_path TEXT NOT NULL
                )
                """
            )

