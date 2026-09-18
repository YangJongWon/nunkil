from typing import Literal

from pydantic import BaseModel, Field

Region = Literal["jp", "kr"]


class ProductMatch(BaseModel):
    """One shop's listing for a product, normalized across providers."""

    name: str
    price: int | None = Field(description="가격. 통화 단위는 currency.")
    currency: Literal["JPY", "KRW"]
    source: str = Field(description="제공자 이름 (yahoo / rakuten / naver)")
    jan: str | None = None
    brand: str | None = None
    seller: str | None = None
    url: str | None = None


class ProductLookup(BaseModel):
    """What the app needs to speak a single short sentence."""

    query: str
    region: Region
    matches: list[ProductMatch]

    @property
    def cheapest(self) -> ProductMatch | None:
        priced = [m for m in self.matches if m.price is not None]
        return min(priced, key=lambda m: m.price or 0) if priced else None
