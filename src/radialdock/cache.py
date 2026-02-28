from __future__ import annotations

import hashlib
import sqlite3
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps

THUMB_RENDER_VERSION = "cover-v2"


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
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_thumbnails_mtime ON thumbnails (mtime)"
            )

    def get_thumbnail_uri(
        self,
        source_path: Path,
        refresh: bool = False,
        size: tuple[int, int] = (96, 96),
    ) -> str | None:
        thumb_path = self.get_thumbnail_path(source_path=source_path, refresh=refresh, size=size)
        if thumb_path is None:
            return None
        return thumb_path.as_uri()

    def peek_thumbnail_uri(
        self,
        source_path: Path,
        size: tuple[int, int] = (96, 96),
    ) -> str | None:
        if not source_path.exists() or not source_path.is_file():
            return None

        try:
            mtime = source_path.stat().st_mtime
        except OSError:
            return None

        cached = self._lookup(
            source_path=source_path,
            mtime=mtime,
            refresh=False,
            size=size,
        )
        if cached is None:
            return None
        return cached.as_uri()

    def get_thumbnail_path(
        self,
        source_path: Path,
        refresh: bool = False,
        size: tuple[int, int] = (96, 96),
    ) -> Path | None:
        if not source_path.exists() or not source_path.is_file():
            return None

        try:
            mtime = source_path.stat().st_mtime
        except OSError:
            return None

        cached = self._lookup(source_path=source_path, mtime=mtime, refresh=refresh, size=size)
        if cached is not None:
            return cached

        rendered = self._render_thumbnail(source_path=source_path, mtime=mtime, size=size)
        if rendered is None:
            return None

        self._upsert(source_path=source_path, mtime=mtime, thumb_path=rendered)
        return rendered

    def _thumb_path_for(
        self,
        source_path: Path,
        mtime: float,
        size: tuple[int, int],
    ) -> Path:
        key = f"{THUMB_RENDER_VERSION}|{source_path}|{mtime}|{size[0]}x{size[1]}"
        thumb_name = hashlib.sha1(key.encode("utf-8"), usedforsecurity=False).hexdigest() + ".png"
        return self.thumb_dir / thumb_name

    def _lookup(
        self,
        source_path: Path,
        mtime: float,
        refresh: bool,
        size: tuple[int, int],
    ) -> Path | None:
        if refresh:
            return None
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "SELECT mtime, thumb_path FROM thumbnails WHERE path = ?",
                (str(source_path),),
            ).fetchone()
        if row is None:
            return None
        cached_mtime = float(row[0])
        cached_thumb = Path(str(row[1]))
        expected_thumb = self._thumb_path_for(source_path=source_path, mtime=mtime, size=size)
        if cached_mtime != mtime or not cached_thumb.exists():
            return None
        if cached_thumb.name != expected_thumb.name:
            return None
        return cached_thumb

    def _render_thumbnail(
        self,
        source_path: Path,
        mtime: float,
        size: tuple[int, int],
    ) -> Path | None:
        target_size = (max(1, int(size[0])), max(1, int(size[1])))
        thumb_path = self._thumb_path_for(source_path=source_path, mtime=mtime, size=target_size)
        try:
            with Image.open(source_path) as image:
                image = ImageOps.exif_transpose(image)
                if image.mode not in ("RGB", "RGBA"):
                    image = image.convert("RGBA")
                image = ImageOps.fit(
                    image,
                    target_size,
                    method=Image.Resampling.LANCZOS,
                    centering=(0.5, 0.5),
                )
                image.save(thumb_path, "PNG")
        except Exception:
            return None
        return thumb_path

    def _upsert(self, source_path: Path, mtime: float, thumb_path: Path) -> None:
        previous_thumb: str | None = None
        with sqlite3.connect(self.db_path) as conn:
            row = conn.execute(
                "SELECT thumb_path FROM thumbnails WHERE path = ?",
                (str(source_path),),
            ).fetchone()
            if row is not None:
                previous_thumb = str(row[0])
            conn.execute(
                """
                INSERT INTO thumbnails(path, mtime, thumb_path)
                VALUES(?, ?, ?)
                ON CONFLICT(path) DO UPDATE
                SET mtime=excluded.mtime, thumb_path=excluded.thumb_path
                """,
                (str(source_path), mtime, str(thumb_path)),
            )
            conn.commit()

        if previous_thumb and previous_thumb != str(thumb_path):
            previous_path = Path(previous_thumb)
            if previous_path.exists():
                try:
                    previous_path.unlink()
                except OSError:
                    pass
