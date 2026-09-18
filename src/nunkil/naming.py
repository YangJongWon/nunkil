import re

from .schemas import ProductMatch

# Shop listings are written for search engines, not for being read aloud. The same
# barcode comes back as "카루비 우스시오 60g" and as "과자 17종 모음 계 34봉 개별포장
# 送料無料 …". For "what is this?" we want the former; the cheapest listing is a
# separate question.
BUNDLE_MARKERS = (
    "詰め合わせ", "詰合せ", "箱買い", "ケース", "まとめ買い", "セット", "個包装",
    "業務用", "大量", "福袋", "アソート",
    "모음", "세트", "묶음", "박스", "대용량",
)
PROMO_MARKERS = (
    "送料無料", "メール便", "ポイント", "クーポン", "在庫限り", "訳あり", "激安",
    "무료배송", "쿠폰", "특가",
)
# "17種", "計34袋", "3個", "×12"
COUNT_PATTERN = re.compile(r"(\d+\s*(種|袋|個|入|本|缶)|[×x]\s*\d+|계\s*\d+|\d+\s*개입)")


def _noise_score(name: str) -> tuple[int, int, int]:
    """Lower is more likely to be the product's own name."""
    bundles = sum(marker in name for marker in BUNDLE_MARKERS)
    promos = sum(marker in name for marker in PROMO_MARKERS)
    counts = len(COUNT_PATTERN.findall(name))
    return (bundles, promos + counts, len(name))


def pick_identity(matches: list[ProductMatch]) -> ProductMatch | None:
    """The listing whose name best answers 'what is this?'.

    Not the cheapest: bundles and multi-packs are often cheaper per listing and
    have the noisiest names.
    """
    named = [m for m in matches if m.name.strip()]
    return min(named, key=lambda m: _noise_score(m.name)) if named else None


# "500円", "¥500", "1,980원", "158엔" — the shelf price belongs in its own sentence,
# not glued to the product's name.
PRICE_PATTERN = re.compile(r"[¥￥]\s?[\d,]+|[\d,]+\s*(円|えん|엔|원)")


def speakable(name: str, limit: int = 40) -> str:
    """Trims a listing title down to something worth hearing."""
    cleaned = name
    for marker in PROMO_MARKERS:
        cleaned = cleaned.replace(marker, " ")
    cleaned = re.sub(r"[【\[（(].*?[】\]）)]", " ", cleaned)
    cleaned = PRICE_PATTERN.sub(" ", cleaned)
    cleaned = re.sub(r"[\s　]+", " ", cleaned).strip(" -/|,")
    if len(cleaned) <= limit:
        return cleaned
    # Cut on a space so the speech doesn't end mid-word.
    head = cleaned[:limit]
    cut = head.rfind(" ")
    return (head[:cut] if cut >= limit // 2 else head).strip()
