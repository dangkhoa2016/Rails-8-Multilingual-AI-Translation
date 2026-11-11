#!/usr/bin/env python3
"""Read-only inference/browser acceptance for Rails 8 Multilingual AI Translation.

Requires Playwright+Chromium/Firefox/WebKit, a disposable administrator account and a running
Rails application. It never submits translation requests or contacts providers.
It creates and removes one unique glossary entry to exercise browser forms.
Run on an isolated preview/database, not on production.
"""
import os
import sys
import uuid
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get("BROWSER_BASE_URL", "http://127.0.0.1:3108").rstrip("/")
ENGINE = os.environ.get("BROWSER_ENGINE", "chromium").lower()
if ENGINE not in ("chromium", "firefox", "webkit"):
    sys.exit("BROWSER_ENGINE must be chromium, firefox or webkit.")
EMAIL = os.environ.get("BROWSER_ADMIN_EMAIL")
PASSWORD = os.environ.get("BROWSER_ADMIN_PASSWORD")
if not EMAIL or not PASSWORD:
    sys.exit("Set BROWSER_ADMIN_EMAIL and BROWSER_ADMIN_PASSWORD in the shell (not in source control).")
url = urlsplit(BASE)
if url.scheme != "http" or url.hostname not in ("127.0.0.1", "localhost"):
    sys.exit("Browser acceptance must target a local disposable Rails preview, not a remote/production URL.")


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    token = "browser-" + uuid.uuid4().hex[:12]
    source_term = "<img src=x onerror=window.__translation_browser_xss=1>" + token
    target_term = "preferred " + token
    errors = []
    csp_violations = []
    requests_to_providers = []
    with sync_playwright() as playwright:
        browser_type = getattr(playwright, ENGINE)
        options = {"headless": True}
        if ENGINE == "chromium":
            options["args"] = ["--no-sandbox", "--disable-dev-shm-usage"]
        browser = browser_type.launch(**options)
        print("BROWSER_ENGINE=" + ENGINE, flush=True)
        context = browser.new_context(viewport={"width": 1440, "height": 900})
        context.expose_function("recordTranslationCspViolation",
                                lambda value: csp_violations.append(value))
        context.add_init_script("""document.addEventListener('securitypolicyviolation', event => {
          window.recordTranslationCspViolation(event.violatedDirective + ':' + event.blockedURI);
        });""")
        page = context.new_page()
        page.set_default_timeout(15000)
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("request", lambda request:
                requests_to_providers.append(request.url)
                if request.method == "POST" and
                ("/admin/translations" in request.url or "/v1/jobs/translations" in request.url or
                 "/v1/chat/completions" in request.url) else None)
        created = False
        try:
            page.goto(BASE + "/login", wait_until="domcontentloaded")
            expect(page.locator("input[name='email']")).to_be_visible()
            page.locator("input[name='email']").fill(EMAIL)
            page.locator("input[name='password']").fill(PASSWORD)
            page.locator("form[action='/login'] input[type='submit']").click()
            expect(page.locator("a.app-nav-link[href='/admin/dashboard']")).to_be_visible()
            print("PASS browser login + authenticated navigation")
            browser_cookies = context.cookies(BASE)
            session_cookies = [c for c in browser_cookies
                               if c["name"] == "_translation_workspace_session"]
            check(len(session_cookies) == 1 and session_cookies[0]["httpOnly"],
                  "Session cookie lacks HttpOnly")
            check(session_cookies[0]["sameSite"] == "Lax", "Session SameSite policy changed")
            guest = browser.new_context()
            guest_page = guest.new_page()
            guest_page.goto(BASE + "/admin/glossary_entries", wait_until="domcontentloaded")
            expect(guest_page.locator("form[action='/login']")).to_be_visible()
            guest.close()
            print("PASS anonymous access restriction and protected session cookie")

            page.goto(BASE + "/admin/dashboard", wait_until="networkidle")
            expect(page.locator("select[name='ui_theme']")).to_be_visible()
            # Importmap and Stimulus initialize asynchronously after DOM readiness.
            # Ensure event handlers are attached before simulated fast interaction.
            page.wait_for_timeout(350)
            page.locator("select[name='ui_theme']").select_option("dark")
            expect(page.locator("html")).to_have_attribute("data-theme", "dark")
            page.reload(wait_until="networkidle")
            expect(page.locator("html")).to_have_attribute("data-theme", "dark")
            page.locator("select[name='ui_theme']").select_option("light")
            expect(page.locator("html")).to_have_attribute("data-theme", "light")
            print("PASS dark/light theme immediate update and persistence")

            page.goto(BASE + "/admin/translations/new", wait_until="networkidle")
            text_area = page.locator("textarea[name='source_text']")
            expect(text_area).to_be_visible()
            draft = "Unsubmitted draft — giữ nguyên Unicode 🎉"
            text_area.fill(draft)
            page.locator("select[name='ui_locale']").select_option("vi")
            expect(page.locator("html")).to_have_attribute("lang", "vi")
            expect(page.locator("textarea[name='source_text']")).to_have_value(draft)
            page.locator("select[name='ui_locale']").select_option("en")
            expect(page.locator("html")).to_have_attribute("lang", "en")
            expect(page.locator("textarea[name='source_text']")).to_have_value(draft)
            print("PASS locale switching preserves unsent translation draft")

            page.goto(BASE + "/admin/glossary_entries")
            expect(page.locator("a[href='/admin/glossary_entries/new']").first).to_be_visible()
            page.locator("a[href='/admin/glossary_entries/new']").first.click()
            expect(page.locator("input[name='glossary_entry[source_language]']")).to_be_visible()
            page.locator("input[name='glossary_entry[source_language]']").fill("English")
            page.locator("input[name='glossary_entry[target_language]']").fill("Vietnamese")
            page.locator("input[name='glossary_entry[source_term]']").fill(source_term)
            page.locator("input[name='glossary_entry[target_term]']").fill(target_term)
            page.locator("textarea[name='glossary_entry[notes]']").fill("Non-sensitive disposable acceptance fixture")
            page.locator(".glossary-form input[type='submit']").click()
            expect(page.locator(".glossary-entry-row").filter(has_text=token)).to_be_visible()
            created = True
            check(page.evaluate("window.__translation_browser_xss === undefined"),
                  "Glossary term was interpreted as executable script.")
            check(page.locator(".glossary-entry-row img").count() == 0, "Unsafe HTML markup in glossary list.")
            row = page.locator(".glossary-entry-row").filter(has_text=token)
            edit_href = row.locator("a[href*='/edit']").get_attribute("href")
            delete_form = row.locator("form[action*='/glossary_entries/']")
            delete_url = delete_form.get_attribute("action")
            check(edit_href and delete_url, "Missing editable glossary entry links")
            page.goto(BASE + edit_href)
            page.locator("input[name='glossary_entry[target_term]']").fill("revised " + token)
            page.locator(".glossary-form input[type='submit']").click()
            expect(page.locator(".glossary-entry-row").filter(has_text="revised " + token)).to_be_visible()
            print("PASS glossary create/edit, escaping and safe rendering")

            page.goto(BASE + "/admin/help")
            expect(page.locator("details.help-faq")).to_have_count(9)
            page.locator("details.help-faq").nth(1).locator("summary").click()
            expect(page.locator("details.help-faq").nth(1)).to_have_attribute("open", "")
            page.goto(BASE + "/admin/translations")
            expect(page.locator("form[method='get']")).to_be_visible()
            print("PASS Help Center interactions and History filters")

            page.set_viewport_size({"width": 390, "height": 844})
            page.goto(BASE + "/admin/dashboard")
            mobile_toggle = page.locator(".app-mobile-menu")
            expect(mobile_toggle).to_be_visible()
            mobile_toggle.click()
            expect(page.locator(".app-shell")).to_have_class("app-shell is-admin nav-mobile-open")
            page.keyboard.press("Escape")
            check("nav-mobile-open" not in page.locator(".app-shell").get_attribute("class"),
                  "Mobile nav did not close on Escape.")
            for path, page_name in (
                ("/admin/translations/new", "Translation Studio"),
                ("/admin/glossary_entries", "Glossary"),
            ):
                page.goto(BASE + path, wait_until="networkidle")
                for width in (320, 375, 390, 768):
                    page.set_viewport_size({"width": width, "height": 844})
                    check(page.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 2"),
                          f"Horizontal overflow in {page_name} at {width}px")
            print("PASS responsive mobile menu, keyboard dismissal and viewport overflow checks")

            page.goto(BASE + "/admin/glossary_entries")
            page.set_viewport_size({"width": 1440, "height": 900})
            row = page.locator(".glossary-entry-row").filter(has_text=token)
            expect(row).to_be_visible()
            page.on("dialog", lambda dialog: dialog.accept())
            row.locator("form button").click()
            expect(page.locator(".glossary-entry-row").filter(has_text=token)).to_have_count(0)
            created = False
            print("PASS glossary deletion and cleanup")

            page.goto(BASE + "/admin/dashboard")
            response = page.request.get(BASE + "/admin/dashboard")
            check(response.status == 200, "Dashboard HTTP status not successful")
            headers = response.headers
            check("content-security-policy" in headers, "CSP header missing")
            check("frame-ancestors 'none'" in headers["content-security-policy"], "Frame embedding not blocked")
            check("'unsafe-inline'" not in headers["content-security-policy"], "Unsafe CSP inline bypass")
            check("'unsafe-eval'" not in headers["content-security-policy"], "Unsafe CSP eval bypass")
            check(not csp_violations, "CSP violations in browser: " + repr(csp_violations))
            # API requests share the browser's authenticated cookies but not
            # the form's CSRF token. A state-changing POST must be rejected.
            csrf_probe = page.request.post(BASE + "/admin/glossary_entries",
                data={
                    "glossary_entry[source_language]": "en",
                    "glossary_entry[target_language]": "vi",
                    "glossary_entry[source_term]": "CSRF-probe-" + token,
                    "glossary_entry[target_term]": "rejected"
                }, max_redirects=0)
            check(csrf_probe.status in (403, 422),
                  "Authenticated state-changing POST without CSRF token was not rejected: " +
                  str(csrf_probe.status))
            check(not requests_to_providers, "Unexpected translation POST/inference call: " + str(requests_to_providers))
            check(not errors, "JavaScript page errors: " + repr(errors))
            print("PASS CSRF protection, strict CSP, no browser JS errors and zero inference calls")
            print("BROWSER_ACCEPTANCE=PASS:" + ENGINE)
        finally:
            if created:
                # Do not discard test data silently; fail loudly with the fixture ID
                # so it can be cleaned explicitly if a UI assertion fails.
                print("CLEANUP_REQUIRED: glossary test term contains", token, file=sys.stderr)
            browser.close()


if __name__ == "__main__":
    main()
