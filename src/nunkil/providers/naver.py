import html
import re

import httpx

from ..schemas import ProductMatch
from .base import get_json

ENDPOINT = "https://openapi.naver.com/v1/search/shop.json"
_TAGS = re.compile(r"<[^>]+>")


class NaverShopping:
    """네이버 쇼핑. Keyword only; a barcode is passed through as the keyword.
    Titles come back with <b> highlight tags and HTML entities."""

    name = "naver"
    currency = "KRW"
    supports_jan = False

    def __init__(self, client_id: str, client_secret: str, client: httpx.AsyncClient) -> None:
        self._headers = {"X-Naver-Client-Id": client_id, "X-Naver-Client-Secret": client_secret}
        self._client = client

    async def lookup_jan(self, jan: str, limit: int = 5) -> list[ProductMatch]:
        return await self.search(jan, limit)

    async def search(self, text: str, limit: int = 5) -> list[ProductMatch]:
        payload = await get_json(
            self._client,
            ENDPOINT,
            {"query": text, "display": limit, "sort": "asc"},
            self.name,
            headers=self._headers,
        )
        return [self._to_match(item) for item in payload.get("items") or []]

    def _to_match(self, item: dict) -> ProductMatch:
        price = item.get("lprice")
        return ProductMatch(
            name=html.unescape(_TAGS.sub("", item.get("title") or "")),
            price=int(price) if str(price).isdigit() else None,
            currency="KRW",
            source=self.name,
            brand=item.get("brand") or item.get("maker") or None,
            seller=item.get("mallName"),
            url=item.get("link"),
        )
