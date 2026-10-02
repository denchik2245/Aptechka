"""Loopback-only HTTP adapter for development of the account API."""
from __future__ import annotations

import json
import os
import smtplib
import ssl
from email.message import EmailMessage
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from server.auth import ApiError, AuthService, Config


def smtp_delivery(email, code):
    host, sender = os.environ['SMTP_HOST'], os.environ['SMTP_FROM']
    message = EmailMessage()
    message['From'], message['To'], message['Subject'] = sender, email, 'Код входа в Аптечку'
    message.set_content(f'Код входа: {code}\nДействует 10 минут. Никому не сообщайте код. Если вы не запрашивали вход, проигнорируйте письмо.')
    with smtplib.SMTP_SSL(host, int(os.environ.get('SMTP_PORT', '465')), context=ssl.create_default_context(), timeout=10) as client:
        client.login(os.environ['SMTP_USER'], os.environ['SMTP_PASSWORD'])
        client.send_message(message)


def handler_for(service: AuthService, port: int):
    allowed_origin = f'http://127.0.0.1:{port}'

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            # The default access logger would expose OAuth codes in the request URL.
            pass

        def _cookie(self, name):
            cookie = SimpleCookie()
            cookie.load(self.headers.get('Cookie', ''))
            return cookie[name].value if name in cookie else ''

        def _token(self):
            header = self.headers.get('Authorization', '')
            return header[7:] if header.startswith('Bearer ') else self._cookie('aptechka_session')

        def _response(self, status, body, cookies=()):
            payload = json.dumps(body, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'")
            for cookie in cookies:
                self.send_header('Set-Cookie', cookie)
            self.end_headers()
            self.wfile.write(payload)

        def _session_response(self, result, *, callback=False):
            cookies = []
            if 'sessionToken' in result:
                cookies.append(f"aptechka_session={result['sessionToken']}; HttpOnly; SameSite=Strict; Path=/api; Max-Age=2592000")
            if callback:
                cookies.append('aptechka_oauth=; HttpOnly; SameSite=Lax; Path=/api/auth/yandex/callback; Max-Age=0')
                result = {key: value for key, value in result.items() if key not in ('sessionToken', 'csrfToken')}
            self._response(200, result, cookies)

        def do_GET(self):
            try:
                service.cleanup()
                parsed = urlparse(self.path)
                if parsed.path == '/api/health':
                    self._response(200, {'mode': 'development', 'cloudEnabled': False})
                elif parsed.path == '/api/auth/providers':
                    self._response(200, {'region': 'RU', 'providers': [
                        {'id': 'email', 'enabled': service.config.dev_delivery or service.delivery is not None},
                        {'id': 'yandex', 'enabled': bool(service.config.yandex_client_id and service.config.yandex_client_secret)},
                        {'id': 'vk', 'enabled': False, 'reason': 'not_configured'},
                        {'id': 'google', 'enabled': False, 'reason': 'disabled_for_ru'},
                        {'id': 'apple', 'enabled': False, 'reason': 'distribution_review_required'},
                    ]})
                elif parsed.path == '/api/account':
                    self._response(200, service.me(self._token()))
                elif parsed.path == '/api/account/sessions':
                    self._response(200, {'sessions': service.sessions(self._token())})
                elif parsed.path == '/api/account/csrf':
                    self._response(200, service.csrf(self._token()))
                elif parsed.path == '/api/auth/yandex/callback':
                    query = parse_qs(parsed.query)
                    result = service.oauth_complete(query.get('state', [''])[0], self._cookie('aptechka_oauth'), query.get('code', [''])[0])
                    self._session_response(result, callback=True)
                else:
                    raise ApiError(404, 'not_found')
            except ApiError as error:
                self._response(error.status, {'error': error.code})
            except Exception:
                self._response(500, {'error': 'internal_error'})

        def do_POST(self):
            try:
                # No wildcard CORS, redirects, or trust in X-Forwarded-For at this layer.
                origin = self.headers.get('Origin')
                if origin is not None and origin != allowed_origin:
                    raise ApiError(403, 'origin_rejected')
                if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
                    raise ApiError(415, 'json_required')
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 131072:
                    raise ApiError(413, 'invalid_body_size')
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict):
                    raise ApiError(400, 'invalid_json')
                path, token = urlparse(self.path).path, self._token()
                protected = path.startswith('/api/account') or path == '/api/auth/logout' or body.get('purpose') == 'link'
                if protected:
                    service.require_csrf(token, self.headers.get('X-CSRF-Token', ''))
                service.cleanup()
                if path == '/api/auth/email/start':
                    self._response(200, service.email_start(body.get('email'), self.client_address[0], purpose=body.get('purpose', 'signin'), token=token))
                elif path == '/api/auth/email/verify':
                    result = service.email_verify(body['challengeId'], body['binding'], body['code'], device=body.get('device', 'Development device'))
                    self._session_response(result)
                elif path == '/api/auth/yandex/start':
                    if body.get('purpose', 'signin') not in ('signin', 'link'):
                        raise ApiError(400, 'invalid_purpose')
                    linking = body.get('purpose') == 'link'
                    result = service.oauth_start(token=token if linking else '')
                    binding = result.pop('binding')
                    self._response(200, result, [f'aptechka_oauth={binding}; HttpOnly; SameSite=Lax; Path=/api/auth/yandex/callback; Max-Age=600'])
                elif path == '/api/auth/logout':
                    session = service._session(token)
                    service.revoke(token, session['id'])
                    self._response(200, {'signedOut': True}, ['aptechka_session=; HttpOnly; SameSite=Strict; Path=/api; Max-Age=0'])
                elif path == '/api/account/sessions/revoke':
                    service.revoke(token, body['sessionId'])
                    self._response(200, {'revoked': True})
                elif path == '/api/account/identities/unlink':
                    service.unlink(token, body['provider'])
                    self._response(200, {'unlinked': True})
                elif path == '/api/account/delete':
                    if body.get('confirmation') != 'DELETE':
                        raise ApiError(400, 'confirmation_required')
                    service.delete_account(token)
                    self._response(200, {'deleted': True}, ['aptechka_session=; HttpOnly; SameSite=Strict; Path=/api; Max-Age=0'])
                elif path in ('/api/account/snapshot', '/api/account/health-consent'):
                    # A client checkbox/flag is NOT evidence of legally valid health-data consent.
                    raise ApiError(423, 'health_data_processing_not_enabled')
                else:
                    raise ApiError(404, 'not_found')
            except ApiError as error:
                self._response(error.status, {'error': error.code})
            except (KeyError, ValueError, TypeError):
                self._response(400, {'error': 'invalid_request'})
            except Exception:
                self._response(500, {'error': 'internal_error'})

    return Handler


def main():
    port = int(os.environ.get('APP_PORT', '8030'))
    database = Path(os.environ.get('APP_DATABASE', 'server/.data/accounts.sqlite'))
    database.parent.mkdir(parents=True, exist_ok=True)
    config = Config(
        pepper=os.environ.get('APP_PEPPER', ''), database=str(database),
        dev_delivery=os.environ.get('APP_DEV_MAIL') == '1',
        allowed_email_domains=tuple(item.strip().lower() for item in os.environ.get('APP_EMAIL_DOMAINS', 'example.test').split(',')),
        yandex_client_id=os.environ.get('YANDEX_CLIENT_ID', ''),
        yandex_client_secret=os.environ.get('YANDEX_CLIENT_SECRET', ''),
        yandex_redirect_uri=os.environ.get('YANDEX_REDIRECT_URI', f'http://127.0.0.1:{port}/api/auth/yandex/callback'),
    )
    delivery = smtp_delivery if os.environ.get('SMTP_HOST') else None
    service = AuthService(config, delivery=delivery)
    database.chmod(0o600)
    # This adapter deliberately cannot be bound publicly. It is not a production service.
    server = HTTPServer(('127.0.0.1', port), handler_for(service, port))
    print(f'Development account API: http://127.0.0.1:{port} (cloud storage disabled)', flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        service.close()


if __name__ == '__main__':
    main()
