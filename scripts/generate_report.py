#!/usr/bin/env python3
"""Generate a saved weekday US ETF/asset brief using Alpha Vantage data."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from html import escape
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen
from urllib.parse import urlencode

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
DATA_DIR = ROOT / "data"
BASE_URL = "https://www.alphavantage.co/query"
EQUITY_SYMBOLS = ["QQQ", "VOO", "SCHD", "META", "MSFT", "IBIT"]
CRYPTO_SYMBOLS = ["ETH"]
ALL_SYMBOLS = EQUITY_SYMBOLS + CRYPTO_SYMBOLS
NEWS_TICKERS = "META,MSFT,CRYPTO:ETH"


@dataclass
class Quote:
    symbol: str
    price: float | None
    change_pct: float | None
    source: str
    note: str = ""


def env(name: str, default: str | None = None) -> str:
    load_dotenv(ROOT / ".env.local")
    value = os.getenv(name, default)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def local_now() -> datetime:
    tz_name = os.getenv("REPORT_TIMEZONE", "America/New_York")
    if ZoneInfo:
        return datetime.now(ZoneInfo(tz_name))
    return datetime.now()


def request_alpha(params: dict[str, str], api_key: str, pause: float = 12.5) -> dict[str, Any]:
    query = dict(params)
    query["apikey"] = api_key
    url = f"{BASE_URL}?{urlencode(query)}"
    request = Request(url, headers={"User-Agent": "Stock_Update/1.0"})
    try:
        with urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        raise RuntimeError(f"HTTP error from Alpha Vantage: {exc.code}") from exc
    except URLError as exc:
        raise RuntimeError(f"Network error from Alpha Vantage: {exc.reason}") from exc
    if "Information" in payload or "Note" in payload:
        message = payload.get("Information") or payload.get("Note")
        raise RuntimeError(f"Alpha Vantage limit/message for {params}: {message}")
    time.sleep(pause)
    return payload


def read_cached_json(name: str) -> dict[str, Any] | None:
    path = DATA_DIR / name
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def parse_float(value: Any) -> float | None:
    if value is None:
        return None
    text = str(value).strip().replace("%", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def get_equity_quote(symbol: str, api_key: str) -> tuple[Quote, dict[str, Any]]:
    payload = request_alpha({"function": "GLOBAL_QUOTE", "symbol": symbol}, api_key)
    data = payload.get("Global Quote", {})
    price = parse_float(data.get("05. price"))
    change_pct = parse_float(data.get("10. change percent"))
    note = ""
    if not data:
        note = "No quote returned."
    return Quote(symbol, price, change_pct, "GLOBAL_QUOTE", note), payload


def get_crypto_quote(symbol: str, api_key: str) -> tuple[Quote, dict[str, Any]]:
    payload = request_alpha(
        {"function": "DIGITAL_CURRENCY_DAILY", "symbol": symbol, "market": "USD"},
        api_key,
    )
    series = payload.get("Time Series (Digital Currency Daily)", {})
    dates = sorted(series.keys(), reverse=True)
    if len(dates) < 2:
        return Quote(symbol, None, None, "DIGITAL_CURRENCY_DAILY", "Insufficient ETH daily data."), payload
    latest = parse_float(series[dates[0]].get("4. close"))
    previous = parse_float(series[dates[1]].get("4. close"))
    change_pct = None
    if latest is not None and previous:
        change_pct = (latest - previous) / previous * 100
    return Quote(symbol, latest, change_pct, "DIGITAL_CURRENCY_DAILY"), payload


def get_news(api_key: str) -> dict[str, Any]:
    attempts = [
        {
            "function": "NEWS_SENTIMENT",
            "tickers": NEWS_TICKERS,
            "sort": "LATEST",
            "limit": "25",
        },
        {
            "function": "NEWS_SENTIMENT",
            "topics": "financial_markets,technology,blockchain",
            "sort": "LATEST",
            "limit": "25",
        },
        {
            "function": "NEWS_SENTIMENT",
            "topics": "financial_markets",
            "sort": "LATEST",
            "limit": "25",
        },
    ]
    errors: list[str] = []
    for params in attempts:
        try:
            return request_alpha(params, api_key)
        except RuntimeError as exc:
            errors.append(str(exc))
    return {"feed": [], "errors": errors}


def save_json(name: str, payload: dict[str, Any]) -> Path:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    path = DATA_DIR / name
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def format_pct(value: float | None) -> str:
    if value is None:
        return "n/a"
    sign = "+" if value > 0 else ""
    return f"{sign}{value:.2f}%"


def format_price(value: float | None) -> str:
    if value is None:
        return "n/a"
    return f"${value:,.2f}"


def report_bias(change_pct: float | None) -> str:
    if change_pct is None:
        return "observe"
    if change_pct >= 1.0:
        return "positive momentum"
    if change_pct <= -1.0:
        return "risk-off pressure"
    return "neutral"


def extract_recent_recommendations(limit: int = 5) -> list[str]:
    if not REPORT_DIR.exists():
        return []
    reports = sorted(REPORT_DIR.glob("*_us_etf_brief.*"), reverse=True)[:limit]
    items: list[str] = []
    for path in reports:
        text = path.read_text(encoding="utf-8", errors="ignore")
        if path.suffix == ".html":
            match = re.search(
                r'<section id="investment-view".*?<li>(.*?)</li>',
                text,
                flags=re.DOTALL,
            )
            if match:
                item = re.sub(r"<[^>]+>", "", match.group(1)).strip()
                items.append(f"{path.stem[:10]}: {item}")
            continue

        markdown_pattern = re.compile(r"^- (.+)$")
        in_section = False
        for line in text.splitlines():
            if line.startswith("## Investment View"):
                in_section = True
                continue
            if in_section and line.startswith("## "):
                in_section = False
            if in_section:
                match = markdown_pattern.match(line.strip())
                if match:
                    items.append(f"{path.stem[:10]}: {match.group(1)}")
                    break
    return items[:limit]


def summarize_news(news: dict[str, Any]) -> list[dict[str, str]]:
    articles = news.get("feed", [])[:10]
    rows: list[dict[str, str]] = []
    for article in articles:
        rows.append(
            {
                "title": str(article.get("title", "")).strip(),
                "source": str(article.get("source", "")).strip(),
                "sentiment": str(article.get("overall_sentiment_label", "")).strip(),
                "score": str(article.get("overall_sentiment_score", "")).strip(),
                "url": str(article.get("url", "")).strip(),
            }
        )
    return rows


def make_investment_view(quotes: list[Quote], news_rows: list[dict[str, str]], history: list[str]) -> list[str]:
    by_symbol = {quote.symbol: quote for quote in quotes}
    qqq = by_symbol.get("QQQ")
    voo = by_symbol.get("VOO")
    schd = by_symbol.get("SCHD")
    eth = by_symbol.get("ETH")
    ibit = by_symbol.get("IBIT")
    meta = by_symbol.get("META")
    msft = by_symbol.get("MSFT")

    view: list[str] = []
    if qqq and voo and (qqq.change_pct or 0) > (voo.change_pct or 0) + 0.5:
        view.append("Growth is leading broad market beta today; favor staged entries rather than chasing a full position at the open.")
    elif qqq and voo and (qqq.change_pct or 0) < (voo.change_pct or 0) - 0.5:
        view.append("Broad market exposure looks steadier than growth beta; keep QQQ additions smaller until Nasdaq breadth improves.")
    else:
        view.append("QQQ and VOO are moving broadly in line; maintain core exposure and let position sizing follow risk tolerance.")

    if schd and schd.change_pct is not None:
        if schd.change_pct < -0.75:
            view.append("SCHD weakness can be used as a dividend-quality watchlist entry point, but avoid treating it as a short-term hedge.")
        else:
            view.append("SCHD remains the stabilizer sleeve; use it to balance growth and crypto-linked volatility.")

    crypto_signal = max([v for v in [eth.change_pct if eth else None, ibit.change_pct if ibit else None] if v is not None] or [0])
    if crypto_signal > 2:
        view.append("Crypto-linked assets are firm; keep IBIT/ETH exposure capped and rebalance into strength if allocation is already above target.")
    elif crypto_signal < -2:
        view.append("Crypto-linked assets are under pressure; wait for intraday stabilization before adding IBIT or ETH.")
    else:
        view.append("IBIT and ETH are not giving a strong directional signal; keep crypto exposure at target weight.")

    megacap_moves = [v for v in [meta.change_pct if meta else None, msft.change_pct if msft else None] if v is not None]
    if megacap_moves and min(megacap_moves) < -1.5:
        view.append("One or more megacap holdings is dragging; check whether the news is company-specific before averaging down.")
    elif megacap_moves and max(megacap_moves) > 1.5:
        view.append("Megacap strength supports QQQ, but trim concentration risk if META/MSFT become outsized versus ETF holdings.")

    negative_news = [row for row in news_rows if "Bearish" in row["sentiment"]]
    if negative_news:
        view.append("News sentiment includes bearish items; prioritize limit orders and avoid increasing every risk sleeve at once.")

    if history:
        view.append("Relative to recent briefs, keep the decision rule consistent: add only when price action and news tone agree.")
    return view


def signal_class(signal: str) -> str:
    return {
        "positive momentum": "positive",
        "neutral": "neutral",
        "risk-off pressure": "negative",
        "observe": "observe",
    }.get(signal, "observe")


def render_report_html(
    now: datetime,
    quotes: list[Quote],
    news_rows: list[dict[str, str]],
    history: list[str],
    raw_files: list[Path],
) -> str:
    investment_view = make_investment_view(quotes, news_rows, history)
    rows: list[str] = []
    for quote in quotes:
        signal = report_bias(quote.change_pct)
        rows.append(
            "<tr>"
            f"<td class=\"symbol\">{escape(quote.symbol)}</td>"
            f"<td>{escape(format_price(quote.price))}</td>"
            f"<td>{escape(format_pct(quote.change_pct))}</td>"
            f"<td><span class=\"signal {signal_class(signal)}\">{escape(signal)}</span></td>"
            f"<td>{escape(quote.source)}</td>"
            "</tr>"
        )

    news_items: list[str] = []
    if news_rows:
        for row in news_rows[:8]:
            title = row["title"] or "Untitled"
            source = row["source"] or "Unknown source"
            sentiment = row["sentiment"] or "n/a"
            url = row["url"]
            title_html = escape(title)
            link = f"<a href=\"{escape(url)}\">Read</a>" if url else ""
            news_items.append(
                "<li>"
                f"<div class=\"news-title\">{title_html}</div>"
                f"<div class=\"meta\">{escape(source)} · sentiment: {escape(sentiment)} {link}</div>"
                "</li>"
            )
    else:
        news_items.append("<li>No news items returned by Alpha Vantage.</li>")

    history_items = history or ["No prior saved briefs found yet; this will build up over future weekdays."]
    raw_file_items = [str(path.relative_to(ROOT)) for path in raw_files]
    generated_at = now.strftime("%Y-%m-%d %H:%M %Z")

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>US ETF Daily Brief - {now:%Y-%m-%d}</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f6f7f9;
      --panel: #ffffff;
      --text: #17202a;
      --muted: #5f6b7a;
      --line: #d9dee7;
      --positive-bg: #dff6e8;
      --positive: #116b38;
      --neutral-bg: #edf1f6;
      --neutral: #435166;
      --negative-bg: #fde5e4;
      --negative: #a3261d;
      --observe-bg: #e2efff;
      --observe: #1e5d9e;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.55;
    }}
    main {{
      width: min(1080px, calc(100% - 32px));
      margin: 32px auto;
    }}
    header {{
      margin-bottom: 24px;
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: clamp(28px, 4vw, 44px);
      letter-spacing: 0;
    }}
    h2 {{
      margin: 0 0 14px;
      font-size: 20px;
      letter-spacing: 0;
    }}
    .subtitle {{
      color: var(--muted);
      margin: 0;
    }}
    section {{
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 20px;
      margin: 16px 0;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      overflow-wrap: anywhere;
    }}
    th, td {{
      padding: 12px 10px;
      border-bottom: 1px solid var(--line);
      text-align: right;
      vertical-align: middle;
    }}
    th:first-child, td:first-child, th:nth-child(4), td:nth-child(4), th:nth-child(5), td:nth-child(5) {{
      text-align: left;
    }}
    tr:last-child td {{ border-bottom: 0; }}
    .symbol {{
      font-weight: 700;
    }}
    .signal {{
      display: inline-flex;
      align-items: center;
      min-height: 28px;
      padding: 3px 10px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 700;
      white-space: nowrap;
    }}
    .positive {{ background: var(--positive-bg); color: var(--positive); }}
    .neutral {{ background: var(--neutral-bg); color: var(--neutral); }}
    .negative {{ background: var(--negative-bg); color: var(--negative); }}
    .observe {{ background: var(--observe-bg); color: var(--observe); }}
    ul {{
      margin: 0;
      padding-left: 20px;
    }}
    li + li {{
      margin-top: 10px;
    }}
    .news-title {{
      font-weight: 650;
    }}
    .meta, .small {{
      color: var(--muted);
      font-size: 14px;
    }}
    a {{
      color: #1f6feb;
      text-decoration: none;
    }}
    a:hover {{
      text-decoration: underline;
    }}
    @media (max-width: 720px) {{
      main {{ width: min(100% - 20px, 1080px); margin: 16px auto; }}
      section {{ padding: 14px; }}
      table {{ font-size: 14px; }}
      th, td {{ padding: 9px 6px; }}
      .signal {{ white-space: normal; }}
    }}
  </style>
</head>
<body>
  <main>
    <header>
      <h1>US ETF Daily Brief - {now:%Y-%m-%d}</h1>
      <p class="subtitle">Generated at {escape(generated_at)}. Informational research only; not personalized financial advice.</p>
    </header>

    <section>
      <h2>Watchlist Snapshot</h2>
      <table>
        <thead>
          <tr>
            <th>Symbol</th>
            <th>Price</th>
            <th>Daily change</th>
            <th>Signal</th>
            <th>Data source</th>
          </tr>
        </thead>
        <tbody>
          {''.join(rows)}
        </tbody>
      </table>
    </section>

    <section>
      <h2>News Brief</h2>
      <ul>{''.join(news_items)}</ul>
    </section>

    <section>
      <h2>Prior Brief Context</h2>
      <ul>{''.join(f"<li>{escape(item)}</li>" for item in history_items)}</ul>
    </section>

    <section id="investment-view">
      <h2>Investment View</h2>
      <ul>{''.join(f"<li>{escape(item)}</li>" for item in investment_view)}</ul>
    </section>

    <section>
      <h2>Saved Inputs</h2>
      <ul>{''.join(f"<li><code>{escape(item)}</code></li>" for item in raw_file_items)}</ul>
    </section>
  </main>
</body>
</html>
"""


def main() -> int:
    api_key = env("ALPHAVANTAGE_API_KEY")
    now = local_now()
    date_slug = f"{now:%Y-%m-%d}"
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    quotes: list[Quote] = []
    raw_files: list[Path] = []

    for symbol in EQUITY_SYMBOLS:
        cache_name = f"{date_slug}_{symbol}_quote.json"
        payload = read_cached_json(cache_name)
        if payload is None:
            quote, payload = get_equity_quote(symbol, api_key)
        else:
            data = payload.get("Global Quote", {})
            quote = Quote(
                symbol,
                parse_float(data.get("05. price")),
                parse_float(data.get("10. change percent")),
                "GLOBAL_QUOTE",
            )
        quotes.append(quote)
        raw_files.append(save_json(cache_name, payload))

    for symbol in CRYPTO_SYMBOLS:
        cache_name = f"{date_slug}_{symbol}_daily.json"
        payload = read_cached_json(cache_name)
        if payload is None:
            quote, payload = get_crypto_quote(symbol, api_key)
        else:
            series = payload.get("Time Series (Digital Currency Daily)", {})
            dates = sorted(series.keys(), reverse=True)
            latest = parse_float(series[dates[0]].get("4. close")) if dates else None
            previous = parse_float(series[dates[1]].get("4. close")) if len(dates) > 1 else None
            change_pct = (latest - previous) / previous * 100 if latest is not None and previous else None
            quote = Quote(symbol, latest, change_pct, "DIGITAL_CURRENCY_DAILY")
        quotes.append(quote)
        raw_files.append(save_json(cache_name, payload))

    news = get_news(api_key)
    raw_files.append(save_json(f"{date_slug}_news_sentiment.json", news))
    news_rows = summarize_news(news)
    history = extract_recent_recommendations()
    report = render_report_html(now, quotes, news_rows, history, raw_files)

    report_path = REPORT_DIR / f"{date_slug}_us_etf_brief.html"
    report_path.write_text(report, encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
