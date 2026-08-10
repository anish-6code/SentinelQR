"""
URL Analyzer
Resolves redirect chains, extracts metadata, fingerprints the page
content, and checks certificate/domain age. All network activity
happens inside this sandbox service — never on the user's device.
"""

import asyncio
import socket
import ssl
import re
from datetime import datetime, timezone
from urllib.parse import urlparse, urljoin
from dataclasses import dataclass, field
from typing import Optional
import httpx
import whois


@dataclass
class RedirectHop:
    hop: int
    url: str
    status_code: int

    def to_dict(self) -> dict:
        return {
            "hop": self.hop,
            "url": self.url,
            "status_code": self.status_code,
        }


@dataclass
class URLAnalysisResult:
    original_url: str
    final_url: str
    redirect_chain: list[RedirectHop] = field(default_factory=list)
    http_status: int = 0
    page_title: Optional[str] = None
    has_ssl: bool = False
    cert_age_days: Optional[int] = None
    domain_age_days: Optional[int] = None
    ip_address: Optional[str] = None
    country: Optional[str] = None
    suspicious_patterns: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "original_url": self.original_url,
            "final_url": self.final_url,
            "redirect_chain": [h.to_dict() for h in self.redirect_chain],
            "http_status": self.http_status,
            "page_title": self.page_title,
            "has_ssl": self.has_ssl,
            "cert_age_days": self.cert_age_days,
            "domain_age_days": self.domain_age_days,
            "ip_address": self.ip_address,
            "country": self.country,
            "suspicious_patterns": self.suspicious_patterns,
        }


# Patterns that appear in credential-harvesting pages
_PHISHING_CONTENT_PATTERNS = [
    (r'(?i)(enter\s+your\s+(password|otp|pin|cvv))', "Password/OTP input prompt"),
    (r'(?i)(verify\s+your\s+account)', "Account verification lure"),
    (r'(?i)(your\s+account\s+(has\s+been\s+)?(suspended|locked|blocked))', "Account suspension lure"),
    (r'(?i)(upi\s+pay\s+request)', "UPI pay request"),
    (r'(?i)(click\s+here\s+to\s+(claim|win|collect))', "Prize claim lure"),
    (r'download\s+(now|the\s+app)', "Forced download prompt"),
]

# Homograph/lookalike checks for popular domains
_LOOKALIKE_TARGETS = [
    "paypal", "amazon", "google", "facebook", "microsoft",
    "apple", "netflix", "sbi", "hdfc", "icici", "paytm", "phonepe",
]


class URLAnalyzer:
    def __init__(self, timeout: float = 20.0, max_hops: int = 12):
        self._timeout = timeout
        self._max_hops = max_hops
        self._client = httpx.AsyncClient(
            follow_redirects=False,      # Manual redirect tracing
            timeout=timeout,
            headers={"User-Agent": "Mozilla/5.0 (compatible; SentinelQR-Sandbox/1.0)"},
            verify=False,               # We check cert validity ourselves
        )

    async def analyse(self, url: str) -> dict:
        result = URLAnalysisResult(original_url=url, final_url=url)

        # ── 1. Trace redirect chain ────────────────────────────────────
        current_url = url
        hop = 0
        while hop < self._max_hops:
            try:
                resp = await self._client.get(current_url)
            except Exception as exc:
                result.http_status = 0
                result.suspicious_patterns.append(f"Connection failed: {exc}")
                break

            result.redirect_chain.append(
                RedirectHop(hop=hop, url=current_url, status_code=resp.status_code)
            )

            if resp.status_code in (301, 302, 303, 307, 308) and "location" in resp.headers:
                new_url = resp.headers["location"]
                if not new_url.startswith("http"):
                    new_url = urljoin(current_url, new_url)
                current_url = new_url
                hop += 1
            else:
                result.final_url = current_url
                result.http_status = resp.status_code
                # ── 2. Page content analysis ──────────────────────────
                try:
                    body = resp.text
                    result.page_title = self._extract_title(body)
                    result.suspicious_patterns += self._check_content(body)
                except Exception:
                    pass
                break

        # ── 3. TLS / certificate check ─────────────────────────────────
        parsed = urlparse(result.final_url)
        if parsed.scheme == "https":
            result.has_ssl = True
            result.cert_age_days = await self._cert_age(parsed.netloc)
        else:
            result.suspicious_patterns.append("No HTTPS on final destination")

        # ── 4. Domain age via WHOIS ────────────────────────────────────
        try:
            domain = parsed.netloc.split(":")[0]
            result.ip_address = socket.gethostbyname(domain)
            info = whois.whois(domain)
            creation = info.creation_date
            if isinstance(creation, list):
                creation = creation[0]
            if creation:
                age = (datetime.now(timezone.utc) - creation.replace(tzinfo=timezone.utc)).days
                result.domain_age_days = age
                if age < 30:
                    result.suspicious_patterns.append(
                        f"Domain registered only {age} days ago"
                    )
        except Exception:
            pass

        # ── 5. Homograph / lookalike check ─────────────────────────────
        final_domain = urlparse(result.final_url).netloc.lower()
        for brand in _LOOKALIKE_TARGETS:
            if brand in final_domain and not final_domain.endswith(f"{brand}.com") \
                    and not final_domain.endswith(f"{brand}.in"):
                result.suspicious_patterns.append(
                    f"Domain resembles '{brand}' but is not the official site"
                )

        # ── 6. Excessive subdomain depth ──────────────────────────────
        parts = final_domain.split(".")
        if len(parts) > 4:
            result.suspicious_patterns.append(
                f"Suspicious subdomain depth: {final_domain}"
            )

        return result.to_dict()

    # ── Helpers ────────────────────────────────────────────────────────

    def _extract_title(self, html: str) -> Optional[str]:
        m = re.search(r"<title[^>]*>([^<]+)</title>", html, re.IGNORECASE)
        return m.group(1).strip() if m else None

    def _check_content(self, html: str) -> list[str]:
        hits = []
        for pattern, description in _PHISHING_CONTENT_PATTERNS:
            if re.search(pattern, html):
                hits.append(description)
        return hits

    async def _cert_age(self, hostname: str) -> Optional[int]:
        try:
            ctx = ssl.create_default_context()
            port = 443
            if ":" in hostname:
                hostname, port_str = hostname.rsplit(":", 1)
                port = int(port_str)
            conn = ctx.wrap_socket(
                socket.socket(socket.AF_INET),
                server_hostname=hostname,
            )
            conn.settimeout(8)
            conn.connect((hostname, port))
            cert = conn.getpeercert()
            conn.close()
            not_before_str = cert.get("notBefore", "")
            not_before = datetime.strptime(not_before_str, "%b %d %H:%M:%S %Y %Z")
            age = (datetime.utcnow() - not_before).days
            return age
        except Exception:
            return None
