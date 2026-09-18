import hmac
import logging
import os
from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Query

from .providers import (
    REQUIRED_ENV,
    MissingCredentials,
    ProductProvider,
    ProviderError,
    providers_from_env,
)
from .schemas import ProductLookup, ProductMatch, Region

log = logging.getLogger("nunkil")


def create_app(
    providers: dict[Region, list[ProductProvider]] | None = None,
    token: str | None = None,
) -> FastAPI:
    state: dict = {"providers": providers}

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        # One shared connection pool; providers are cheap wrappers around it.
        async with httpx.AsyncClient() as client:
            if state["providers"] is None:
                state["providers"] = providers_from_env(client)
            yield

    def require_token(authorization: Annotated[str | None, Header()] = None) -> None:
        if token is None:
            return
        if authorization is None or not hmac.compare_digest(authorization, f"Bearer {token}"):
            raise HTTPException(status_code=401, detail="invalid token")

    app = FastAPI(title="NunKil", lifespan=lifespan, dependencies=[Depends(require_token)])

    @app.get("/health")
    async def health() -> dict:
        return {"ok": True}

    @app.get("/product")
    async def product(
        region: Annotated[Region, Query()] = "jp",
        jan: Annotated[str | None, Query(pattern=r"^\d{8,14}$")] = None,
        q: Annotated[str | None, Query(min_length=1, max_length=120)] = None,
        limit: Annotated[int, Query(ge=1, le=10)] = 5,
    ) -> ProductLookup:
        """Identify a product and what it costs online.

        The app sends a barcode it read on-device whenever it can — then no photo
        ever leaves the phone, and the answer comes back without a model call.
        """
        if (jan is None) == (q is None):
            raise HTTPException(status_code=400, detail="pass exactly one of jan or q")

        available = (state["providers"] or {}).get(region) or []
        if not available:
            raise MissingCredentials(REQUIRED_ENV[region])

        matches: list[ProductMatch] = []
        errors: list[str] = []
        for provider in available:
            # A provider that can't resolve barcodes would just keyword-search the
            # digits; only fall back to that if nothing better answered.
            if jan is not None and not provider.supports_jan and matches:
                continue
            try:
                found = (
                    await provider.lookup_jan(jan, limit)
                    if jan is not None
                    else await provider.search(q or "", limit)
                )
            except ProviderError as e:
                log.warning("provider failed: %s", e)
                errors.append(str(e))
                continue
            matches.extend(found)

        if not matches and errors:
            raise HTTPException(status_code=502, detail="; ".join(errors))

        matches.sort(key=lambda m: (m.price is None, m.price or 0))
        return ProductLookup(query=jan or q or "", region=region, matches=matches[:limit])

    @app.exception_handler(MissingCredentials)
    async def missing_credentials(_request, exc: MissingCredentials):
        from fastapi.responses import JSONResponse

        return JSONResponse(status_code=503, content={"detail": f"설정되지 않은 키: {exc}"})

    return app


def app_from_env() -> FastAPI:
    return create_app(token=os.environ.get("NUNKIL_TOKEN"))
