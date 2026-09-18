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
    """What the app needs to speak a single short sentence.

    `identity` answers "what is this?" and `cheapest` answers "what does it cost?".
    They are usually different listings: bundles are cheap per unit but their
    titles are unreadable.
    """

    query: str
    region: Region
    identity: ProductMatch | None = None
    cheapest: ProductMatch | None = None
    spoken_name: str | None = Field(default=None, description="식별 이름을 소리내어 읽기 좋게 다듬은 것")
    matches: list[ProductMatch]
