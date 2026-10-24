from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import shutil
import subprocess
import threading
import time
import webbrowser
from collections.abc import Callable
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

import httpx

from picode import BRAND_NAME, PRODUCT
from picode.language import contains_persian, terminal_text


class ApiHttpError(RuntimeError):
    """HTTP error from PiGPT API (status preserved for CLI UX)."""

    def __init__(self, status_code: int, detail: str):
        self.status_code = int(status_code)
        self.detail = str(detail)
        super().__init__(self.detail)


def _http_error_from_response(r: httpx.Response) -> ApiHttpError:
    detail = r.text
    try:
        body = r.json()
        if isinstance(body, dict):
            detail = body.get("detail") or detail
        elif isinstance(body, list):
            detail = str(body)
    except Exception:  # noqa: BLE001
        pass
    if isinstance(detail, list):
        detail = "; ".join(str(x) for x in detail)
    return ApiHttpError(r.status_code, str(detail))


def has_saved_token() -> bool:
    return bool(get_token())


def plan_display_name(plan: dict | None) -> str:
    if not plan:
        return "—"
    for key in ("name_en", "code", "name"):
        label = terminal_text(plan.get(key), "")
        if label:
            return label
    return "plan"


def model_display_name(model: dict) -> str:
    """Visible model name; strips display-only ``arvan_`` prefix (API id unchanged)."""
    from picode.model_picker import model_label

    return model_label(model)


_API_DETAIL_EXACT: dict[str, str] = {
    "کد نامعتبر یا منقضی است": "Invalid or expired code.",
    "کد احراز منقضی یا نامعتبر است": "Authorization code expired or invalid.",
    "نشست منقضی یا نامعتبر است": "Session expired or invalid.",
    "PKCE نامعتبر است": "Invalid PKCE verifier.",
    "redirect_uri مطابقت ندارد": "redirect_uri does not match.",
    "توکن در دسترس نیست": "Token not available.",
    "شناسهٔ مدل نامعتبر است": "Invalid model id.",
    "با redirect_uri باید code_challenge (PKCE S256) بفرستید": "redirect_uri requires code_challenge (PKCE S256).",
    "فقط code_challenge_method=S256 پشتیبانی می‌شود": "Only code_challenge_method=S256 is supported.",
}


def english_api_detail(detail: str) -> str:
    text = (detail or "").strip()
    if not text:
        return "Request failed."
    if text in _API_DETAIL_EXACT:
        return _API_DETAIL_EXACT[text]
    lowered = text.lower()
    if "not authenticated" in lowered or lowered == "unauthorized":
        return "Not authenticated."
    if "could not validate credentials" in lowered:
        return "Could not validate credentials."
    if "اعتبار" in text or "سقف" in text or "موجودی" in text:
        return "AI usage limit or balance — check /cost or upgrade in the app."
    if "مدل" in text and "نامعتبر" in text:
        return "Invalid model."
    if contains_persian(text):
        return "Request failed."
    return text


def print_api_error(console: Any, exc: BaseException) -> None:
    """User-facing API errors — never suggest re-login for quota/billing."""
    from picode.i18n import t

    if isinstance(exc, ApiHttpError):
        if exc.status_code == 401:
            console.print(f"[yellow]{t('warn.session_expired', product=PRODUCT)}[/yellow]")
            return
        detail = english_api_detail(exc.detail)
        if exc.status_code in (403, 429):
            console.print(f"[red]{t('warn.ai_usage', detail=detail)}[/red]")
            console.print(f"[dim]{t('warn.still_signed_in')}[/dim]")
            return
        console.print(f"[red]{detail}[/red]")
        return
    console.print(f"[red]{exc}[/red]")


def probe_session(*, token: str | None = None, base: str | None = None) -> str:
    """Session probe for REPL start: ok | missing | unauthorized | degraded."""
    t = token if token is not None else get_token()
    if not t:
        return "missing"
    try:
        ApiClient(base=base, token=t).me()
        return "ok"
    except ApiHttpError as exc:
        if exc.status_code == 401:
            return "unauthorized"
        return "degraded"
    except Exception:  # noqa: BLE001
        return "degraded"


def session_valid(*, token: str | None = None, base: str | None = None) -> bool:
    """True when saved credentials may be used (only explicit 401 is invalid)."""
    state = probe_session(token=token, base=base)
    return state not in ("missing", "unauthorized")


def config_dir() -> Path:
    base = Path(os.environ.get("PICODE_HOME") or (Path.home() / ".picode"))
    base.mkdir(parents=True, exist_ok=True)
    return base


def config_path() -> Path:
    return config_dir() / "config.json"


def load_config() -> dict[str, Any]:
    path = config_path()
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def save_config(data: dict[str, Any]) -> None:
    config_path().write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


DEFAULT_API = "https://pigpt.ir"


def api_base() -> str:
    cfg = load_config()
    return (
        os.environ.get("PICODE_API_URL")
        or cfg.get("api_url")
        or DEFAULT_API
    ).rstrip("/")


def get_token() -> str | None:
    env = os.environ.get("PICODE_TOKEN")
    if env and str(env).strip():
        return str(env).strip()
    cfg_tok = load_config().get("token")
    if isinstance(cfg_tok, str) and cfg_tok.strip():
        return cfg_tok.strip()
    return None


def pkce_pair() -> tuple[str, str]:
    """Return (code_verifier, code_challenge) for S256."""
    verifier = secrets.token_urlsafe(64)
    digest = hashlib.sha256(verifier.encode("ascii")).digest()
    challenge = base64.urlsafe_b64encode(digest).decode("ascii").rstrip("=")
    return verifier, challenge


def is_wsl() -> bool:
    """True when running under Windows Subsystem for Linux."""
    if os.environ.get("WSL_DISTRO_NAME") or os.environ.get("WSL_INTEROP"):
        return True
    try:
        text = Path("/proc/version").read_text(encoding="utf-8", errors="ignore").lower()
    except OSError:
        return False
    return "microsoft" in text or "wsl" in text


def open_system_browser(url: str) -> bool:
    """Best-effort open URL. On WSL prefer Windows browser; never raise."""
    if not url:
        return False

    if is_wsl():
        # Windows browser can complete auth on the public web origin; CLI polls.
        for argv in (
            ["cmd.exe", "/c", "start", "", url],
            [
                "powershell.exe",
                "-NoProfile",
                "-Command",
                f"Start-Process '{url}'",
            ],
        ):
            try:
                subprocess.run(
                    argv,
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=15,
                )
                return True
            except (FileNotFoundError, OSError, subprocess.TimeoutExpired):
                continue
        wslview = shutil.which("wslview")
        if wslview:
            try:
                subprocess.run(
                    [wslview, url],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=15,
                )
                return True
            except (OSError, subprocess.TimeoutExpired):
                pass

    try:
        return bool(webbrowser.open(url, new=1, autoraise=True))
    except Exception:  # noqa: BLE001
        return False


class ApiClient:
    def __init__(self, base: str | None = None, token: str | None = None):
        self.base = (base or api_base()).rstrip("/")
        self.token = token if token is not None else get_token()

    def _headers(self) -> dict[str, str]:
        h = {"User-Agent": f"{PRODUCT}/cli", "Accept": "application/json"}
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"
        return h

    def get(self, path: str, **kwargs: Any) -> Any:
        with httpx.Client(timeout=60) as client:
            r = client.get(f"{self.base}{path}", headers=self._headers(), **kwargs)
            if r.status_code >= 400:
                raise _http_error_from_response(r)
            return r.json()

    def post(self, path: str, json_body: dict | None = None, **kwargs: Any) -> Any:
        with httpx.Client(timeout=120) as client:
            r = client.post(
                f"{self.base}{path}",
                headers=self._headers(),
                json=json_body or {},
                **kwargs,
            )
            if r.status_code >= 400:
                raise _http_error_from_response(r)
            if not r.content:
                return {}
            return r.json()

    def start_device_login(
        self,
        *,
        redirect_uri: str | None = None,
        code_challenge: str | None = None,
        state: str | None = None,
    ) -> dict:
        body: dict[str, Any] = {"client_name": PRODUCT}
        if redirect_uri:
            body["redirect_uri"] = redirect_uri
            body["code_challenge"] = code_challenge
            body["code_challenge_method"] = "S256"
        if state:
            body["state"] = state
        return self.post("/api/v1/auth/cli/device", body)

    def poll_device(self, device_code: str) -> dict:
        return self.post("/api/v1/auth/cli/device/poll", {"device_code": device_code})

    def exchange_token(
        self,
        *,
        code: str,
        code_verifier: str,
        redirect_uri: str | None = None,
    ) -> dict:
        body: dict[str, Any] = {"code": code, "code_verifier": code_verifier}
        if redirect_uri:
            body["redirect_uri"] = redirect_uri
        return self.post("/api/v1/auth/cli/token", body)

    def me(self) -> dict:
        return self.get("/api/v1/me")

    def try_get(self, path: str) -> dict[str, Any] | None:
        """Best-effort GET for optional account endpoints; None on 4xx/5xx/network."""
        try:
            data = self.get(path)
        except Exception:  # noqa: BLE001
            return None
        return data if isinstance(data, dict) else None

    def usage_bundle(self) -> dict[str, Any]:
        """Account picture from /me plus optional /billing/wallet and /me/token-report."""
        me = self.me()
        out: dict[str, Any] = {"me": me if isinstance(me, dict) else {}}
        wallet = self.try_get("/api/v1/billing/wallet")
        if wallet:
            out["wallet"] = wallet
        report = self.try_get("/api/v1/me/token-report")
        if report:
            out["token_report"] = report
        return out

    def list_models(self) -> list[dict[str, Any]]:
        data = self.get("/api/v1/models")
        return data if isinstance(data, list) else []

    def chat(
        self,
        message: str,
        *,
        system: str | None = None,
        model_id: str | None = None,
        history: list[dict[str, str]] | None = None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {"message": message, "stream": False}
        if system:
            body["system"] = system
        if model_id:
            body["model_id"] = model_id
        if history:
            body["history"] = history
        data = self.post("/api/v1/cli/chat", body)
        if not isinstance(data, dict):
            return {"reply": str(data)}
        return data


def wait_for_device_token(client: ApiClient, device_code: str, interval: int = 3, timeout: int = 300) -> str:
    deadline = time.time() + timeout
    while time.time() < deadline:
        data = client.poll_device(device_code)
        status = data.get("status")
        if status == "approved" and data.get("access_token"):
            return str(data["access_token"])
        if status == "expired":
            raise RuntimeError("Sign-in session expired; run login again")
        if status == "denied":
            raise RuntimeError("Sign-in denied")
        time.sleep(max(1, int(data.get("interval") or interval)))
    raise RuntimeError("Sign-in timed out")


class _CallbackResult:
    def __init__(self) -> None:
        self.code: str | None = None
        self.state: str | None = None
        self.error: str | None = None
        self.event = threading.Event()


def _make_handler(result: _CallbackResult, expected_state: str):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
            return

        def do_GET(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            if parsed.path.rstrip("/") != "/callback":
                self.send_response(404)
                self.end_headers()
                return
            qs = parse_qs(parsed.query)
            state = (qs.get("state") or [None])[0]
            code = (qs.get("code") or [None])[0]
            err = (qs.get("error") or [None])[0]
            if err:
                result.error = str(err)
            elif state != expected_state:
                result.error = "state_mismatch"
            elif not code:
                result.error = "missing_code"
            else:
                result.code = str(code)
                result.state = str(state)
            result.event.set()
            body = (
                "<!doctype html><html lang=en><meta charset=utf-8>"
                f"<title>{BRAND_NAME}</title>"
                "<body style='font-family:sans-serif;text-align:center;padding:3rem'>"
                f"<h1>{BRAND_NAME}</h1>"
                "<p>Signed in. You can close this window and return to the terminal.</p>"
                "</body></html>"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def browser_login_with_pkce(
    client: ApiClient,
    *,
    timeout: int = 300,
    open_browser: bool = True,
    on_authorize_url: Callable[[str], None] | None = None,
) -> str:
    """Browser login with printed authorize URL + poll (WSL-safe) + optional PKCE loopback.

    Always invokes ``on_authorize_url`` with the full web authorize link so the user
    can copy-paste it. Completion prefers API poll after web approve (no dependency
    on Windows→WSL localhost). On non-WSL, also listens for PKCE loopback redirect.
    """
    # WSL: skip loopback — Windows browser often cannot reliably hit WSL 127.0.0.1.
    # Native Linux/macOS/Windows: PKCE loopback + parallel poll.
    use_loopback = not is_wsl()
    verifier = challenge = state = ""
    redirect_uri: str | None = None
    result = _CallbackResult()
    server: HTTPServer | None = None
    thread: threading.Thread | None = None

    if use_loopback:
        verifier, challenge = pkce_pair()
        state = secrets.token_urlsafe(24)
        server = HTTPServer(("127.0.0.1", 0), _make_handler(result, state))
        server.timeout = 0.5
        port = int(server.server_address[1])
        redirect_uri = f"http://127.0.0.1:{port}/callback"

        def _serve() -> None:
            assert server is not None
            while not result.event.is_set():
                server.handle_request()

        thread = threading.Thread(target=_serve, daemon=True)
        thread.start()

    data = client.start_device_login(
        redirect_uri=redirect_uri,
        code_challenge=challenge or None,
        state=state or None,
    )
    verify_url = str(data.get("verification_uri_complete") or data["verification_url"])
    device_code = data["device_code"]
    interval = int(data.get("interval") or 3)

    if on_authorize_url:
        on_authorize_url(verify_url)

    if open_browser:
        open_system_browser(verify_url)

    deadline = time.time() + timeout
    access: str | None = None
    try:
        while time.time() < deadline:
            if use_loopback and result.event.is_set() and (result.code or result.error):
                break
            try:
                polled = client.poll_device(device_code)
                if polled.get("status") == "approved" and polled.get("access_token"):
                    access = str(polled["access_token"])
                    break
                if polled.get("status") == "expired":
                    raise RuntimeError("Sign-in session expired")
                if polled.get("status") == "denied":
                    raise RuntimeError("Sign-in denied")
            except RuntimeError:
                raise
            except Exception:  # noqa: BLE001
                pass
            time.sleep(min(1.0, interval))
    finally:
        result.event.set()
        if thread is not None:
            thread.join(timeout=2)
        if server is not None:
            server.server_close()

    if access:
        return access

    if use_loopback:
        if result.error:
            raise RuntimeError(f"Callback error: {result.error}")
        if result.code:
            token_data = client.exchange_token(
                code=result.code,
                code_verifier=verifier,
                redirect_uri=redirect_uri,
            )
            token = token_data.get("access_token")
            if not token:
                raise RuntimeError("No access token from server")
            return str(token)

    raise RuntimeError(
        "No response from the browser. Open this URL, approve sign-in, then return to the terminal:\n"
        f"{verify_url}"
    )
