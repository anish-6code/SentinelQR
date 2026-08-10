# SentinelQR

**SentinelQR** treats every scanned QR code as hostile until proven otherwise.

Rather than decoding a code and handing the destination straight to the phone's browser — the behaviour every mainstream scanner exhibits, and the behaviour attackers rely on — SentinelQR holds the destination inside the application, resolves and inspects it on a remote sandbox, and only completes the journey once a verdict has been produced.

## Threat Model

**Quishing** is the practice of pasting a malicious QR code over a legitimate one — on a restaurant menu, a parking meter, a payment standee, a public notice or a delivery slip. Because a QR code is visually unreadable to humans, the substitution is undetectable before scanning.

> A QR code cannot silently install malware. It carries only a text payload. Compromise still requires the user to act — to enter credentials on a convincing page, approve a payment request, or download and install a file.

### Primary Threat Scenarios Addressed

| Threat | Description |
|--------|-------------|
| Credential Harvesting | Cloned login pages for banking, UPI, or social media |
| Fraudulent Payments | Malicious UPI collect requests or fake payment portals |
| Malicious APK Distribution | Harmful Android packages presented as required apps |
| Malicious Payloads | Wi-Fi configs and contact injections with hostile data |
| Redirect Chain Obfuscation | Hostile final destinations hidden behind reputable intermediaries |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SentinelQR App                        │
│  ┌──────────┐   ┌──────────────┐   ┌─────────────────┐  │
│  │  Camera  │──▶│  QR Decoder  │──▶│  Payload Parser │  │
│  └──────────┘   └──────────────┘   └────────┬────────┘  │
│                                             │            │
│  ┌──────────────────────────────────────────▼──────────┐ │
│  │              Sandbox Analysis Engine                 │ │
│  │  • URL Resolution & Redirect Chain Tracing           │ │
│  │  • Threat Intelligence Lookup                        │ │
│  │  • Page Content Fingerprinting                       │ │
│  │  • Certificate & Domain Age Verification             │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌──────────┐   ┌──────────────┐   ┌─────────────────┐   │
│  │  Verdict │──▶│  Risk Report │──▶│  Open / Block   │   │
│  │  Engine  │   │  Generator   │   │  Decision Gate  │   │
│  └──────────┘   └──────────────┘   └─────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
Scam_qr/
├── android/          # Native Android QR scanner integration
├── lib/              # Flutter application source
│   ├── core/         # Core utilities, theme, routing
│   ├── features/     # Feature modules (scanner, verdict, history)
│   └── sandbox/      # Sandbox API client
├── sandbox_engine/   # Python sandbox analysis microservice
│   ├── api/          # FastAPI endpoints
│   ├── analyzers/    # URL, content, and threat analyzers
│   └── intelligence/ # Threat intelligence feeds
├── docs/             # Architecture and threat model documentation
└── tests/            # Unit and integration tests
```

## Getting Started

### Prerequisites
- Flutter 3.x
- Python 3.11+
- Android SDK 34+

### Running the Sandbox Engine
```bash
cd sandbox_engine
pip install -r requirements.txt
uvicorn api.main:app --host 0.0.0.0 --port 8000
```

### Running the Flutter App
```bash
flutter pub get
flutter run
```

## Security Model

The application follows a **zero-trust** approach to QR code content:

1. **Scan** — camera captures the code; payload stays in-app memory
2. **Parse** — payload type is classified (URL, UPI, WiFi, vCard, plain text)
3. **Submit** — payload is sent to sandbox engine over TLS
4. **Analyse** — sandbox resolves redirects, checks threat feeds, fingerprints page
5. **Verdict** — a scored risk report is returned (SAFE / SUSPICIOUS / DANGER)
6. **Gate** — user can proceed only after reviewing the verdict

## License

MIT License — see [LICENSE](LICENSE)
