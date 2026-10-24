"""On-demand web search and URL fetch for PiCode chat tools."""

from __future__ import annotations

import html as html_lib
import ipaddress
import re
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse

import httpx

from picode.activity import report as report_activity
from picode.i18n import t

_UA = "PiCode/cli (+https://pigpt.ir; local tool)"
_SEARCH_TIMEOUT = 20.0
_FETCH_TIMEOUT = 20.0
_MAX_BODY = 200_000
_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
_DDG_RESULT_RE = re.compile(
    r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
    re.I | re.S,
)
_DDG_SNIPPET_RE = re.compile(
    r'<a[^>]+class="result__snippet"[^>]*>(.*?)</a>|<div[^>]+class="result__snippet"[^>]*>(.*?)</div>',
    re.I | re.S,
)
_TAG_RE = re.compile(r"<[^>]+>")
_BLOCKED_HOSTS = {
    "localhost",
    "metadata.google.internal",
    "metadata.google",
}


def _strip_tags(text: str) -> str:
    cleaned = _TAG_RE.sub(" ", text or "")
    cleaned = html_lib.unescape(cleaned)
    return re.sub(r"\s+", " ", cleaned).strip()


def _resolve_ddg_href(href: str) -> str:
    raw = html_lib.unescape(href or "").strip()
    if not raw:
        return ""
    if raw.startswith("//"):
        raw = "https:" + raw
    parsed = urlparse(raw)
    if "duckduckgo.com" in (parsed.netloc or "") and parsed.path.startswith("/l/"):
        qs = parse_qs(parsed.query)
        uddg = qs.get("uddg") or []
        if uddg:
            return unquote(uddg[0])
    return raw


def _host_allowed(hostname: str) -> bool:
    host = (hostname or "").strip().lower().rstrip(".")
    if not host or host in _BLOCKED_HOSTS or host.endswith(".localhost"):
        return False
    if host == "0.0.0.0":
        return False
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return True
    return not (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_reserved
        or ip.is_multicast
        or ip.is_unspecified
    )


def validate_public_url(url: str) -> str:
    raw = (url or "").strip()
    if not raw:
        raise ValueError("Missing URL")
    parsed = urlparse(raw)
    if parsed.scheme not in ("http", "https"):
        raise ValueError("Only http/https URLs are allowed")
    if not parsed.netloc:
        raise ValueError("Invalid URL")
    host = parsed.hostname or ""
    if not _host_allowed(host):
        raise ValueError("URL host is not allowed (private/local blocked)")
    return raw


def web_search(query: str, *, max_results: int = 5) -> dict[str, Any]:
    q = (query or "").strip()
    if not q:
        raise ValueError("Missing search query")
    if len(q) > 500:
        raise ValueError("Search query too long")
    limit = max(1, min(int(max_results or 5), 8))
    report_activity("running", t("status.web_search", query=q[:60]))

    results: list[dict[str, str]] = []
    with httpx.Client(
        timeout=_SEARCH_TIMEOUT,
        follow_redirects=True,
        headers={"User-Agent": _UA, "Accept-Language": "en,fa;q=0.8"},
    ) as client:
        r = client.post(
            "https://html.duckduckgo.com/html/",
            data={"q": q},
        )
        r.raise_for_status()
        body = r.text

    titles = list(_DDG_RESULT_RE.finditer(body))
    snippets = list(_DDG_SNIPPET_RE.finditer(body))
    for i, match in enumerate(titles[:limit]):
        url = _resolve_ddg_href(match.group(1))
        title = _strip_tags(match.group(2)) or url
        snippet = ""
        if i < len(snippets):
            sn = snippets[i]
            snippet = _strip_tags(sn.group(1) or sn.group(2) or "")
        if not url:
            continue
        try:
            validate_public_url(url)
        except ValueError:
            continue
        results.append({"title": title[:200], "url": url, "snippet": snippet[:400]})

    return {
        "query": q,
        "provider": "duckduckgo-html",
        "source_note": "Results from PiCode web_search tool (DuckDuckGo HTML).",
        "results": results,
    }


def fetch_url(url: str, *, max_chars: int = 12_000) -> dict[str, Any]:
    target = validate_public_url(url)
    report_activity("running", t("status.web_fetch", url=target[:80]))
    limit = max(500, min(int(max_chars or 12_000), 20_000))
    with httpx.Client(
        timeout=_FETCH_TIMEOUT,
        follow_redirects=True,
        headers={"User-Agent": _UA, "Accept": "text/*,application/json;q=0.9,*/*;q=0.1"},
    ) as client:
        r = client.get(target)
        # Re-check final URL after redirects
        validate_public_url(str(r.url))
        r.raise_for_status()
        content_type = (r.headers.get("content-type") or "").split(";")[0].strip().lower()
        raw = r.content[:_MAX_BODY]
    text = raw.decode("utf-8", errors="replace")
    title = ""
    m = _TITLE_RE.search(text)
    if m:
        title = _strip_tags(m.group(1))[:200]
    if "html" in content_type or "<html" in text[:500].lower():
        text = _strip_tags(text)
    text = text.strip()
    if len(text) > limit:
        text = text[:limit] + "\n…(truncated)"
    return {
        "url": str(r.url),
        "status_code": r.status_code,
        "content_type": content_type,
        "title": title,
        "source_note": "Content from PiCode fetch_url tool.",
        "text": text,
    }


def format_search_note(data: dict[str, Any]) -> str:
    lines = [
        f"web_search ok — {data.get('source_note')}",
        f"query: {data.get('query')}",
    ]
    results = data.get("results") or []
    if not results:
        lines.append("(no results)")
        return "\n".join(lines)
    for i, item in enumerate(results, 1):
        lines.append(
            f"{i}. {item.get('title')}\n   {item.get('url')}\n   {item.get('snippet')}"
        )
    return "\n".join(lines)


def format_fetch_note(data: dict[str, Any]) -> str:
    return (
        f"fetch_url ok — {data.get('source_note')}\n"
        f"url: {data.get('url')}\n"
        f"status: {data.get('status_code')} · type: {data.get('content_type')}\n"
        f"title: {data.get('title') or '—'}\n"
        f"{data.get('text') or ''}"
    )
