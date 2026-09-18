import httpx

from ..schemas import ProductMatch
from .base import get_json

ENDPOINT = "https://openapi.rakuten.co.jp/ichibams/api/IchibaItem/Search/20260701"


class RakutenIchiba:
    """楽天市場. No JAN parameter, so a barcode has to be sent as a keyword —
    useful as a second opinion on price, not as the identifier."""

    name = "rakuten"
    currency = "JPY"
    supports_jan = False

    def __init__(self, app_id: str, access_key: str, client: httpx.AsyncClient) -> None:
        self._app_id = app_id
        self._access_key = access_key
        self._client = client

    async def lookup_jan(self, jan: str, limit: int = 5) -> list[ProductMatch]:
        return await self.search(jan, limit)

    async def search(self, text: str, limit: int = 5) -> list[ProductMatch]:
        payload = await get_json(
            self._client,
            ENDPOINT,
            {
                "applicationId": self._app_id,
                "accessKey": self._access_key,
                "keyword": text,
                "hits": limit,
                # Flat item objects instead of the legacy {"item": {...}} wrapper.
                "formatVersion": 2,
            },
            self.name,
        )
        return [self._to_match(item) for item in payload.get("items") or []]

    def _to_match(self, item: dict) -> ProductMatch:
        price = item.get("itemPrice")
        return ProductMatch(
            name=item.get("itemName") or "",
            price=int(price) if isinstance(price, int) else None,
            currency="JPY",
            source=self.name,
            seller=item.get("shopName"),
            url=item.get("itemUrl"),
        )
