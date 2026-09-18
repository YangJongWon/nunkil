import httpx

from ..schemas import ProductMatch
from .base import get_json

ENDPOINT = "https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch"


class YahooShopping:
    """Yahoo!ショッピング. The only provider that resolves a JAN barcode directly,
    which makes it the fast path for 'what is this thing in my hand'."""

    name = "yahoo"
    currency = "JPY"
    supports_jan = True

    def __init__(self, app_id: str, client: httpx.AsyncClient) -> None:
        self._app_id = app_id
        self._client = client

    async def lookup_jan(self, jan: str, limit: int = 5) -> list[ProductMatch]:
        return await self._request({"jan_code": jan, "results": limit})

    async def search(self, text: str, limit: int = 5) -> list[ProductMatch]:
        return await self._request({"query": text, "results": limit})

    async def _request(self, params: dict) -> list[ProductMatch]:
        payload = await get_json(
            self._client, ENDPOINT, {"appid": self._app_id, **params}, self.name
        )
        return [self._to_match(hit) for hit in payload.get("hits") or []]

    def _to_match(self, hit: dict) -> ProductMatch:
        brand = hit.get("brand") or {}
        seller = hit.get("seller") or {}
        price = hit.get("price")
        return ProductMatch(
            name=hit.get("name") or "",
            price=int(price) if isinstance(price, (int, float, str)) and str(price).isdigit() else None,
            currency="JPY",
            source=self.name,
            jan=hit.get("janCode"),
            brand=brand.get("name"),
            seller=seller.get("name"),
            url=hit.get("url"),
        )
