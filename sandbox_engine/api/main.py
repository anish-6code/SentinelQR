"""
SentinelQR Sandbox Analysis Engine
FastAPI microservice that accepts QR payload submissions and returns
structured threat reports.

Every payload is treated as hostile until the analysis pipeline
clears it. URLs are never forwarded to any user device until a
verdict has been produced and the client has chosen to proceed.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uuid
import time
from datetime import datetime, timezone

from analyzers.url_analyzer import URLAnalyzer
from analyzers.threat_feed import ThreatFeed
from analyzers.payload_classifier import classify_payload
from analyzers.verdict_engine import VerdictEngine

app = FastAPI(
    title="SentinelQR Sandbox Engine",
    description="Zero-trust QR payload analysis microservice",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # Lock to your app's origin in production
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)

# Singletons initialised at startup
url_analyzer: URLAnalyzer = None
threat_feed: ThreatFeed = None
verdict_engine: VerdictEngine = None


@app.on_event("startup")
async def startup():
    global url_analyzer, threat_feed, verdict_engine
    url_analyzer = URLAnalyzer()
    threat_feed = ThreatFeed()
    await threat_feed.load()
    verdict_engine = VerdictEngine(threat_feed)


# ── Request / Response models ─────────────────────────────────────────────

class AnalyseRequest(BaseModel):
    payload: str
    format: str = "QR_CODE"
    requested_at: str | None = None


class AnalyseResponse(BaseModel):
    id: str
    verdict: str
    risk_score: int
    payload_type: str
    raw_payload: str
    url_analysis: dict | None
    threats: list[dict]
    categories: list[str]
    analysed_at: str
    duration_ms: int


# ── Endpoints ─────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "service": "sentinel-sandbox"}


@app.post("/api/v1/analyse", response_model=AnalyseResponse)
async def analyse(req: AnalyseRequest):
    start = time.monotonic()
    report_id = str(uuid.uuid4())

    # 1. Classify the raw payload
    payload_type = classify_payload(req.payload)

    # 2. URL-specific deep analysis
    url_analysis_data = None
    if payload_type == "URL":
        try:
            url_analysis_data = await url_analyzer.analyse(req.payload)
        except Exception as exc:
            raise HTTPException(status_code=502, detail={
                "code": "SANDBOX_ANALYSIS_FAILED",
                "message": str(exc),
            })

    # 3. Generate threat indicators
    threats = await verdict_engine.find_threats(
        payload=req.payload,
        payload_type=payload_type,
        url_analysis=url_analysis_data,
    )

    # 4. Compute verdict and score
    verdict, risk_score, categories = verdict_engine.score(threats, url_analysis_data)

    duration_ms = int((time.monotonic() - start) * 1000)

    return AnalyseResponse(
        id=report_id,
        verdict=verdict,
        risk_score=risk_score,
        payload_type=payload_type,
        raw_payload=req.payload,
        url_analysis=url_analysis_data,
        threats=[t.to_dict() for t in threats],
        categories=categories,
        analysed_at=datetime.now(timezone.utc).isoformat(),
        duration_ms=duration_ms,
    )
