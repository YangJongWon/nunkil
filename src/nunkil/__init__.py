import os


def main() -> None:
    import uvicorn

    # The server listens on the LAN so the phone can reach it; a shared token is
    # mandatory because every request spends someone's API quota.
    if not os.environ.get("NUNKIL_TOKEN"):
        raise SystemExit("NUNKIL_TOKEN is not set. Generate one with: openssl rand -hex 24")

    uvicorn.run(
        "nunkil.app:app_from_env",
        factory=True,
        host=os.environ.get("NUNKIL_HOST", "0.0.0.0"),
        port=int(os.environ.get("NUNKIL_PORT", "8010")),
    )
