import httpx
import pytest

from nunkil.providers import NaverShopping, RakutenIchiba, YahooShopping
from nunkil.providers.base import ProviderError

# Response shapes follow each provider's published documentation.
YAHOO_BODY = {
    "totalResultsAvailable": 1,
    "hits": [
        {
            "name": "カルビー ポテトチップス うすしお味 60g",
            "price": 138,
            "url": "https://store.example.jp/item/1",
            "janCode": "4901330500009",
            "brand": {"id": 1, "name": "カルビー"},
            "seller": {"sellerId": "s1", "name": "サンプル商店", "url": "https://store.example.jp"},
            "code": "abc",
            "inStock": True,
        }
    ],
}
RAKUTEN_BODY = {
    "items": [
        {
            "itemName": "カルビー ポテトチップス うすしお 60g×12袋",
            "itemPrice": 1980,
            "itemUrl": "https://item.rakuten.example/1",
            "shopName": "楽天サンプル店",
            "mediumImageUrls": ["https://img.example/1.jpg"],
        }
    ]
}
NAVER_BODY = {
    "items": [
        {
            "title": "<b>포카칩</b> 오리지널 &amp; 66g",
            "lprice": "1180",
            "link": "https://shopping.naver.example/1",
            "mallName": "네이버스토어",
            "brand": "오리온",
            "maker": "오리온",
        }
    ]
}


def client_returning(body: dict, status: int = 200, capture: dict | None = None) -> httpx.AsyncClient:
    def handler(request: httpx.Request) -> httpx.Response:
        if capture is not None:
            capture["url"] = str(request.url)
            capture["headers"] = request.headers
        return httpx.Response(status, json=body)

    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


async def test_yahoo_looks_up_a_barcode_directly():
    capture: dict = {}
    provider = YahooShopping("app-id", client_returning(YAHOO_BODY, capture=capture))

    matches = await provider.lookup_jan("4901330500009")

    assert "jan_code=4901330500009" in capture["url"]
    assert "appid=app-id" in capture["url"]
    assert provider.supports_jan
    match = matches[0]
    assert match.name.startswith("カルビー ポテトチップス")
    assert (match.price, match.currency, match.source) == (138, "JPY", "yahoo")
    assert (match.jan, match.brand, match.seller) == ("4901330500009", "カルビー", "サンプル商店")


async def test_rakuten_sends_flat_format_and_has_no_jan_lookup():
    capture: dict = {}
    provider = RakutenIchiba("app-id", "access-key", client_returning(RAKUTEN_BODY, capture=capture))

    matches = await provider.search("ポテトチップス")

    assert "formatVersion=2" in capture["url"]
    assert "accessKey=access-key" in capture["url"]
    assert not provider.supports_jan
    assert (matches[0].price, matches[0].seller) == (1980, "楽天サンプル店")


async def test_naver_strips_markup_and_sends_auth_headers():
    capture: dict = {}
    provider = NaverShopping("id", "secret", client_returning(NAVER_BODY, capture=capture))

    matches = await provider.search("포카칩")

    assert capture["headers"]["X-Naver-Client-Id"] == "id"
    assert capture["headers"]["X-Naver-Client-Secret"] == "secret"
    match = matches[0]
    assert match.name == "포카칩 오리지널 & 66g"
    assert (match.price, match.currency, match.brand) == (1180, "KRW", "오리온")


async def test_http_error_becomes_provider_error():
    provider = YahooShopping("app-id", client_returning({}, status=500))
    with pytest.raises(ProviderError):
        await provider.lookup_jan("4901330500009")


async def test_empty_result_is_not_an_error():
    provider = YahooShopping("app-id", client_returning({"hits": []}))
    assert await provider.lookup_jan("4901330500009") == []
