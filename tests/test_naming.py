from nunkil.naming import pick_identity, speakable
from nunkil.schemas import ProductMatch


def match(name: str, price: int) -> ProductMatch:
    return ProductMatch(name=name, price=price, currency="JPY", source="yahoo")


# These three came back from one real JAN lookup (4901330560782). Sorted by price
# the bundle wins, which is the wrong answer to "what am I holding?".
REAL_HITS = [
    match("500円 送料無料　カルビー 堅あげポテト　うすしお 小袋 4袋　 メール便 送料無料　", 500),
    match("お菓子 詰め合わせ ミニスナック 17種各1袋 計17袋 小袋 こども 景品 駄菓子 個包装", 1650),
    match("スナック菓子 詰め合わせ お菓子 2連 17種 計34袋 小袋 こども 駄菓子 個包装", 2480),
]


def test_identity_skips_bundles_even_when_they_are_cheaper():
    identity = pick_identity(REAL_HITS)
    assert identity is not None
    assert "堅あげポテト" in identity.name
    assert "詰め合わせ" not in identity.name


def test_identity_prefers_the_plain_product_name():
    hits = [
        match("カルビー 堅あげポテト うすしお 60g", 158),
        match("【送料無料】カルビー 堅あげポテト うすしお 60g ×12袋 まとめ買い ケース", 1800),
    ]
    assert pick_identity(hits).price == 158


def test_identity_ignores_unnamed_listings():
    assert pick_identity([match("", 100), match("녹차 500ml", 150)]).name == "녹차 500ml"
    assert pick_identity([]) is None


def test_speakable_strips_promo_noise_and_brackets():
    spoken = speakable("500円 送料無料　カルビー 堅あげポテト　うすしお 小袋 4袋　 メール便 送料無料　")
    assert "送料無料" not in spoken
    assert "メール便" not in spoken
    assert "カルビー" in spoken

    assert speakable("【期間限定】お～いお茶 濃い茶 600ml") == "お～いお茶 濃い茶 600ml"


def test_speakable_is_short_enough_to_hear_and_ends_on_a_word():
    long_name = "カルビー " + "うすしお " * 20
    spoken = speakable(long_name)
    assert len(spoken) <= 40
    assert not spoken.endswith("う")  # not cut mid-word


def test_speakable_drops_prices_glued_to_the_name():
    # The real listing title starts with its own price twice over.
    spoken = speakable("500円 送料無料　カルビー 堅あげポテト　うすしお 小袋 4袋 500えん 消化")
    assert "500" not in spoken
    assert spoken.startswith("カルビー")

    assert speakable("1,180원 포카칩 오리지널 66g") == "포카칩 오리지널 66g"
