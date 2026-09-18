import httpx
import pytest

from nunkil.providers import providers_from_env

# A typo in an env var name fails silently — the region just looks unconfigured —
# so the exact names are pinned here.


@pytest.fixture
def client():
    return httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(200, json={})))


def test_yahoo_client_id_enables_japan(monkeypatch, client):
    monkeypatch.setenv("YAHOO_CLIENT_ID", "client-id")
    built = providers_from_env(client)
    assert [p.name for p in built["jp"]] == ["yahoo"]
    assert built["kr"] == []


def test_rakuten_needs_both_keys(monkeypatch, client):
    monkeypatch.delenv("YAHOO_CLIENT_ID", raising=False)
    monkeypatch.setenv("RAKUTEN_APP_ID", "app")
    assert providers_from_env(client)["jp"] == []
    monkeypatch.setenv("RAKUTEN_ACCESS_KEY", "key")
    assert [p.name for p in providers_from_env(client)["jp"]] == ["rakuten"]


def test_naver_needs_both_keys(monkeypatch, client):
    monkeypatch.setenv("NAVER_CLIENT_ID", "id")
    assert providers_from_env(client)["kr"] == []
    monkeypatch.setenv("NAVER_CLIENT_SECRET", "secret")
    assert [p.name for p in providers_from_env(client)["kr"]] == ["naver"]


def test_yahoo_comes_before_rakuten(monkeypatch, client):
    monkeypatch.setenv("YAHOO_CLIENT_ID", "client-id")
    monkeypatch.setenv("RAKUTEN_APP_ID", "app")
    monkeypatch.setenv("RAKUTEN_ACCESS_KEY", "key")
    # Order matters: the barcode-capable provider must be asked first.
    assert [p.name for p in providers_from_env(client)["jp"]] == ["yahoo", "rakuten"]


def test_nothing_configured(monkeypatch, client):
    for name in ("YAHOO_CLIENT_ID", "RAKUTEN_APP_ID", "RAKUTEN_ACCESS_KEY", "NAVER_CLIENT_ID", "NAVER_CLIENT_SECRET"):
        monkeypatch.delenv(name, raising=False)
    assert providers_from_env(client) == {"jp": [], "kr": []}
