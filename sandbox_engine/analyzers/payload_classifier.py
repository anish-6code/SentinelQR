"""
Payload Classifier
Determines the semantic type of a raw QR code payload.
"""

import re
from urllib.parse import urlparse


def classify_payload(payload: str) -> str:
    """
    Classify a raw QR payload string into one of:
      URL | UPI | WIFI | VCARD | MAILTO | SMS | TEL | TEXT
    """
    p = payload.strip()

    if re.match(r'^https?://', p, re.IGNORECASE):
        return "URL"

    if p.lower().startswith("upi://"):
        return "UPI"

    if p.lower().startswith("wifi:"):
        return "WIFI"

    if p.lower().startswith("begin:vcard"):
        return "VCARD"

    if p.lower().startswith("mailto:"):
        return "MAILTO"

    if p.lower().startswith("sms:") or p.lower().startswith("smsto:"):
        return "SMS"

    if p.lower().startswith("tel:"):
        return "TEL"

    # Bare domain heuristic (no scheme)
    try:
        parsed = urlparse("https://" + p)
        if parsed.netloc and "." in parsed.netloc and len(parsed.netloc) < 100:
            return "URL"
    except Exception:
        pass

    return "TEXT"
