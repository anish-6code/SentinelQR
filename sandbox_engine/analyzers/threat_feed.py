"""
Threat Intelligence Feed
Loads and queries blocklists / allowlists for domain-level threat data.
In production this would pull from PhishTank, URLH, Google Safe Browsing,
etc. For offline / demo use it ships with a curated static seed list.
"""

import asyncio
import json
import os
from pathlib import Path
from dataclasses import dataclass
from typing import Optional


@dataclass
class FeedEntry:
    domain: str
    category: str        # phishing | malware | spam | fake-apk | scam
    confidence: float    # 0.0–1.0
    source: str


class ThreatFeed:
    def __init__(self):
        self._entries: dict[str, FeedEntry] = {}
        self._seed_path = Path(__file__).parent.parent / "intelligence" / "seed_blocklist.json"

    async def load(self):
        """Load seed blocklist from disk and optionally refresh from remote feeds."""
        if self._seed_path.exists():
            data = json.loads(self._seed_path.read_text(encoding="utf-8"))
            for entry in data.get("entries", []):
                self._entries[entry["domain"].lower()] = FeedEntry(
                    domain=entry["domain"].lower(),
                    category=entry["category"],
                    confidence=entry.get("confidence", 0.9),
                    source=entry.get("source", "seed"),
                )

    def lookup(self, domain: str) -> Optional[FeedEntry]:
        """Return a FeedEntry if the domain or any parent domain is blocked."""
        domain = domain.lower().lstrip("www.")
        # Exact match
        if domain in self._entries:
            return self._entries[domain]
        # Parent-domain walk (e.g. sub.evil.com → evil.com)
        parts = domain.split(".")
        for i in range(1, len(parts) - 1):
            parent = ".".join(parts[i:])
            if parent in self._entries:
                return self._entries[parent]
        return None

    def is_allowed(self, domain: str) -> bool:
        """Check if a domain is on the known-good allowlist."""
        _allowlist = {
            "google.com", "youtube.com", "github.com", "wikipedia.org",
            "stackoverflow.com", "microsoft.com", "apple.com", "amazon.com",
        }
        return domain.lower().lstrip("www.") in _allowlist
