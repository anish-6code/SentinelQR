"""
Verdict Engine
Aggregates all threat signals and produces a final verdict, risk score,
and category classification for a scanned QR payload.

Scoring model:
  - Base score: 0 (fully clean)
  - Each threat indicator contributes a weighted delta based on severity:
      critical  → +40
      high      → +25
      medium    → +15
      low       → +5
  - Allowlisted domains cap the score at 10
  - Threat feed hits add a severity-weighted bonus
  - Final score is clamped to [0, 100]
  - Verdict thresholds:
      0–29   → SAFE
      30–59  → SUSPICIOUS
      60–100 → DANGER
"""

from dataclasses import dataclass
from typing import Optional
from .threat_feed import ThreatFeed

_SEVERITY_WEIGHTS = {
    "critical": 40,
    "high": 25,
    "medium": 15,
    "low": 5,
}

_VERDICT_THRESHOLDS = [
    (60, "DANGER"),
    (30, "SUSPICIOUS"),
    (0,  "SAFE"),
]


@dataclass
class ThreatIndicator:
    type: str
    severity: str
    description: str
    evidence: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "type": self.type,
            "severity": self.severity,
            "description": self.description,
            "evidence": self.evidence,
        }


class VerdictEngine:
    def __init__(self, threat_feed: ThreatFeed):
        self._feed = threat_feed

    async def find_threats(
        self,
        payload: str,
        payload_type: str,
        url_analysis: Optional[dict],
    ) -> list[ThreatIndicator]:
        threats: list[ThreatIndicator] = []

        if url_analysis:
            # ── 1. Threat feed lookup ──────────────────────────────────
            from urllib.parse import urlparse
            domain = urlparse(url_analysis["final_url"]).netloc.lstrip("www.")
            entry = self._feed.lookup(domain)
            if entry:
                threats.append(ThreatIndicator(
                    type="FEED_HIT",
                    severity="critical",
                    description=f"Domain '{domain}' is on the threat intelligence blocklist",
                    evidence=f"Category: {entry.category} | Source: {entry.source} | "
                             f"Confidence: {entry.confidence:.0%}",
                ))

            # ── 2. Redirect chain depth ────────────────────────────────
            hop_count = len(url_analysis.get("redirect_chain", []))
            if hop_count >= 5:
                threats.append(ThreatIndicator(
                    type="DEEP_REDIRECT_CHAIN",
                    severity="high",
                    description=f"URL traverses {hop_count} redirects, obscuring the final destination",
                    evidence=f"{hop_count} hops in chain",
                ))
            elif hop_count >= 2:
                threats.append(ThreatIndicator(
                    type="REDIRECT_CHAIN",
                    severity="medium",
                    description=f"URL redirects {hop_count} times before reaching the final destination",
                    evidence=f"{hop_count} hops in chain",
                ))

            # ── 3. No HTTPS ────────────────────────────────────────────
            if not url_analysis.get("has_ssl"):
                threats.append(ThreatIndicator(
                    type="NO_TLS",
                    severity="high",
                    description="Final destination does not use HTTPS",
                    evidence="Plaintext HTTP connection",
                ))

            # ── 4. Fresh domain ────────────────────────────────────────
            domain_age = url_analysis.get("domain_age_days")
            if domain_age is not None and domain_age < 30:
                threats.append(ThreatIndicator(
                    type="FRESH_DOMAIN",
                    severity="high",
                    description=f"Domain is only {domain_age} days old — a common indicator of disposable phishing infrastructure",
                    evidence=f"Registered {domain_age} days ago",
                ))

            # ── 5. Content-level suspicious patterns ───────────────────
            for pattern in url_analysis.get("suspicious_patterns", []):
                threats.append(ThreatIndicator(
                    type="SUSPICIOUS_CONTENT",
                    severity="medium",
                    description=pattern,
                ))

            # ── 6. New cert on HTTPS site ──────────────────────────────
            cert_age = url_analysis.get("cert_age_days")
            if cert_age is not None and cert_age < 7:
                threats.append(ThreatIndicator(
                    type="NEW_CERTIFICATE",
                    severity="medium",
                    description=f"TLS certificate is only {cert_age} days old",
                    evidence=f"Certificate issued {cert_age} day(s) ago",
                ))

        # ── 7. Non-URL payload types ───────────────────────────────────
        if payload_type == "WIFI":
            threats.append(ThreatIndicator(
                type="WIFI_PAYLOAD",
                severity="low",
                description="QR code encodes Wi-Fi credentials — verify the network before connecting",
            ))
        elif payload_type == "VCARD":
            threats.append(ThreatIndicator(
                type="VCARD_PAYLOAD",
                severity="low",
                description="QR code encodes contact data — review before saving to address book",
            ))

        return threats

    def score(
        self,
        threats: list[ThreatIndicator],
        url_analysis: Optional[dict],
    ) -> tuple[str, int, list[str]]:
        """Return (verdict, risk_score, categories)."""
        score = 0
        categories: set[str] = set()

        # Check allowlist first
        if url_analysis:
            from urllib.parse import urlparse
            domain = urlparse(url_analysis.get("final_url", "")).netloc.lstrip("www.")
            if self._feed.is_allowed(domain):
                return "SAFE", 5, ["allowlisted"]

        for t in threats:
            delta = _SEVERITY_WEIGHTS.get(t.severity, 0)
            score += delta
            categories.add(t.type)

        score = min(score, 100)

        verdict = "SAFE"
        for threshold, label in _VERDICT_THRESHOLDS:
            if score >= threshold:
                verdict = label
                break

        return verdict, score, sorted(categories)
