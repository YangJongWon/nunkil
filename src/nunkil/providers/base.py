from typing import Protocol

import httpx

from ..schemas import ProductMatch


class ProductProvider(Protocol):
    """A shopping site we can ask 'what is this, and what does it cost'.

    Providers differ in what they can answer: Yahoo!ショッピング looks a JAN
    barcode up directly, while 楽天 and 네이버 only take keywords. Callers use
    `supports_jan` instead of catching failures.
    """

    name: str
    currency: str
    supports_jan: bool

    async def lookup_jan(self, jan: str, limit: int) -> list[ProductMatch]: ...

    async def search(self, text: str, limit: int) -> list[ProductMatch]: ...


class ProviderError(Exception):
    """The provider was reachable but could not answer."""


async def get_json(
    client: httpx.AsyncClient, url: str, params: dict, provider: str, headers: dict | None = None
) -> dict:
    try:
        response = await client.get(url, params=params, headers=headers, timeout=5)
    except httpx.HTTPError as e:
        raise ProviderError(f"{provider}: {e}") from e
    if response.status_code != 200:
        raise ProviderError(f"{provider}: HTTP {response.status_code}")
    try:
        return response.json()
    except ValueError as e:
        raise ProviderError(f"{provider}: invalid JSON") from e
