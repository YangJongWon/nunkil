import os

import httpx

from ..schemas import Region
from .base import ProductProvider, ProviderError
from .naver import NaverShopping
from .rakuten import RakutenIchiba
from .yahoo import YahooShopping

__all__ = [
    "ProductProvider",
    "ProviderError",
    "YahooShopping",
    "RakutenIchiba",
    "NaverShopping",
    "providers_from_env",
    "MissingCredentials",
]


class MissingCredentials(Exception):
    """No provider is configured for a region. The message names the env vars,
    because that is the only thing the operator can act on."""


def providers_from_env(client: httpx.AsyncClient) -> dict[Region, list[ProductProvider]]:
    """Builds whatever the environment has keys for. Order matters: the first
    provider that can answer a JAN is the fast path."""
    jp: list[ProductProvider] = []
    if app_id := os.environ.get("YAHOO_APP_ID"):
        jp.append(YahooShopping(app_id, client))
    if (rakuten_id := os.environ.get("RAKUTEN_APP_ID")) and (
        access_key := os.environ.get("RAKUTEN_ACCESS_KEY")
    ):
        jp.append(RakutenIchiba(rakuten_id, access_key, client))

    kr: list[ProductProvider] = []
    if (naver_id := os.environ.get("NAVER_CLIENT_ID")) and (
        naver_secret := os.environ.get("NAVER_CLIENT_SECRET")
    ):
        kr.append(NaverShopping(naver_id, naver_secret, client))

    return {"jp": jp, "kr": kr}


REQUIRED_ENV: dict[Region, str] = {
    "jp": "YAHOO_APP_ID (또는 RAKUTEN_APP_ID + RAKUTEN_ACCESS_KEY)",
    "kr": "NAVER_CLIENT_ID + NAVER_CLIENT_SECRET",
}
