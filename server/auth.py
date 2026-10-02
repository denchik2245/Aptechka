"""Executable development foundation. Only synthetic accounts should be used.

Tokens and one-time codes are HMAC hashed at rest; no provider token is persisted.
Public deployment requires the production controls documented in docs/accounts.md.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class ApiError(Exception):
    def __init__(self, status: int, code: str):
        self.status, self.code = status, code
        super().__init__(code)


@dataclass(frozen=True)
class Config:
    pepper: str
    database: str = ':memory:'
    dev_delivery: bool = False
    allowed_email_domains: tuple[str, ...] = ('example.test',)
    yandex_client_id: str = ''
    yandex_client_secret: str = ''
    yandex_redirect_uri: str = 'http://127.0.0.1:8030/api/auth/yandex/callback'

    def __post_init__(self):
        if len(self.pepper.encode()) < 32:
            raise ValueError('APP_PEPPER must contain at least 32 bytes')
        if not self.yandex_redirect_uri.startswith(('https://', 'http://127.0.0.1:')):
            raise ValueError('OAuth redirect URI must be HTTPS or loopback in development')


SCHEMA = '''
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS identities (
  provider TEXT NOT NULL CHECK(provider IN ('email','yandex')),
  subject TEXT NOT NULL, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL, PRIMARY KEY(provider, subject), UNIQUE(account_id, provider)
);
CREATE TABLE IF NOT EXISTS sessions (
  id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE, csrf_hash TEXT NOT NULL, created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL, device TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS email_challenges (
  id TEXT PRIMARY KEY, email TEXT NOT NULL, code_hash TEXT NOT NULL, binding_hash TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK(purpose IN ('signin','link')), session_id TEXT,
  created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
  consumed INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS oauth_challenges (
  state_hash TEXT PRIMARY KEY, binding_hash TEXT NOT NULL, verifier TEXT NOT NULL,
  session_id TEXT, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
  consumed INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS rate_events (key_hash TEXT NOT NULL, occurred_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS rate_events_key ON rate_events(key_hash, occurred_at);
'''


class YandexClient:
    def __init__(self, config: Config):
        self.config = config

    def exchange(self, code: str, verifier: str) -> str:
        payload = urlencode({
            'grant_type': 'authorization_code', 'code': code, 'code_verifier': verifier,
            'client_id': self.config.yandex_client_id,
            'client_secret': self.config.yandex_client_secret,
            'redirect_uri': self.config.yandex_redirect_uri,
        }).encode()
        # Endpoints are fixed. Secrets stay in a POST body/header, never in logs or URLs.
        with urlopen(Request('https://oauth.yandex.ru/token', data=payload,
                             headers={'Content-Type': 'application/x-www-form-urlencoded'}), timeout=10) as response:
            token = json.load(response)['access_token']
        with urlopen(Request('https://login.yandex.ru/info?format=json',
                             headers={'Authorization': f'OAuth {token}'}), timeout=10) as response:
            user = json.load(response)
        if user.get('client_id') != self.config.yandex_client_id or not isinstance(user.get('id'), str):
            raise ApiError(401, 'invalid_provider_response')
        # Do not use email, display name or a client-provided ID as identity proof.
        return user['id']


class AuthService:
    def __init__(self, config: Config, delivery=None, yandex=None, now=None):
        self.config = config
        self.db = sqlite3.connect(config.database, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.executescript(SCHEMA)
        self.delivery = delivery
        self.yandex = yandex or YandexClient(config)
        self.now = now or (lambda: int(time.time()))

    def close(self):
        self.db.close()

    def digest(self, kind: str, value: str) -> str:
        return hmac.new(self.config.pepper.encode(), f'{kind}:{value}'.encode(), hashlib.sha256).hexdigest()

    @contextmanager
    def transaction(self):
        self.db.execute('BEGIN IMMEDIATE')
        try:
            yield
            self.db.execute('COMMIT')
        except BaseException:
            self.db.execute('ROLLBACK')
            raise

    def _session(self, token: str, *, fresh=False):
        session = self.db.execute('SELECT * FROM sessions WHERE token_hash=?',
                                  (self.digest('session', token),)).fetchone()
        if not session or session['expires_at'] <= self.now() or session['last_seen_at'] < self.now() - 7 * 86400:
            raise ApiError(401, 'session_expired')
        if fresh and session['created_at'] < self.now() - 600:
            raise ApiError(401, 'reauthentication_required')
        return session

    def _challenge_session(self, session_id):
        if session_id is None:
            return None
        session = self.db.execute('SELECT * FROM sessions WHERE id=?', (session_id,)).fetchone()
        if not session or session['expires_at'] <= self.now() or session['created_at'] < self.now() - 600:
            raise ApiError(401, 'reauthentication_required')
        return session

    def require_csrf(self, token, csrf):
        session = self._session(token)
        if not hmac.compare_digest(session['csrf_hash'], self.digest('csrf', csrf)):
            raise ApiError(403, 'csrf_failed')

    def _rate_limit(self, email: str, ip: str):
        now = self.now()
        keys = [(self.digest('email_rate', email), 5), (self.digest('ip_rate', ip), 20)]
        with self.transaction():
            self.db.execute('DELETE FROM rate_events WHERE occurred_at < ?', (now - 900,))
            for key, limit in keys:
                count = self.db.execute('SELECT count(*) FROM rate_events WHERE key_hash=?', (key,)).fetchone()[0]
                if count >= limit:
                    raise ApiError(429, 'try_later')
            last = self.db.execute('SELECT max(occurred_at) FROM rate_events WHERE key_hash=?', (keys[0][0],)).fetchone()[0]
            if last is not None and last > now - 60:
                raise ApiError(429, 'try_later')
            for key, _ in keys:
                self.db.execute('INSERT INTO rate_events VALUES (?, ?)', (key, now))

    def email_start(self, email: str, ip: str, *, purpose='signin', token=''):
        if not isinstance(email, str):
            raise ApiError(400, 'invalid_email')
        email = email.strip().lower()
        if len(email) > 254 or not re.fullmatch(r'[a-z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-z0-9.-]+\.[a-z]{2,}', email):
            raise ApiError(400, 'invalid_email')
        domain = email.rsplit('@', 1)[1]
        if domain not in self.config.allowed_email_domains:
            raise ApiError(400, 'email_domain_not_enabled')
        # Demo transport can NEVER be used to bypass proof of a real mailbox.
        if self.config.dev_delivery and domain != 'example.test':
            raise ApiError(400, 'development_requires_test_address')
        if purpose not in ('signin', 'link'):
            raise ApiError(400, 'invalid_purpose')
        session = self._session(token, fresh=True) if purpose == 'link' else None
        if not self.config.dev_delivery and self.delivery is None:
            raise ApiError(503, 'mail_transport_not_configured')
        self._rate_limit(email, ip)
        challenge, binding = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
        code = f'{secrets.randbelow(1000000):06d}'
        now = self.now()
        with self.transaction():
            self.db.execute('UPDATE email_challenges SET consumed=1 WHERE email=? AND consumed=0', (email,))
            self.db.execute('INSERT INTO email_challenges(id,email,code_hash,binding_hash,purpose,session_id,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?)',
                            (challenge, email, self.digest('otp', f'{challenge}:{code}'), self.digest('binding', binding),
                             purpose, session['id'] if session else None, now, now + 600))
        if not self.config.dev_delivery:
            try:
                self.delivery(email, code)
            except Exception:
                self.db.execute('UPDATE email_challenges SET consumed=1 WHERE id=?', (challenge,))
                raise ApiError(503, 'mail_delivery_failed') from None
        result = {'challengeId': challenge, 'binding': binding, 'expiresIn': 600, 'retryAfter': 60}
        if self.config.dev_delivery:
            result['devCode'] = code
        return result

    def _identity(self, provider: str, subject: str, session=None):
        existing = self.db.execute('SELECT account_id FROM identities WHERE provider=? AND subject=?',
                                   (provider, subject)).fetchone()
        if session:
            account_id = session['account_id']
            if existing and existing['account_id'] != account_id:
                raise ApiError(409, 'identity_linked_elsewhere')
            other = self.db.execute('SELECT subject FROM identities WHERE account_id=? AND provider=?', (account_id, provider)).fetchone()
            if other and other['subject'] != subject:
                raise ApiError(409, 'provider_already_linked')
        elif existing:
            account_id = existing['account_id']
        else:
            account_id = str(uuid.uuid4())
            self.db.execute('INSERT INTO accounts VALUES (?,?,?)', (account_id, 'Мой аккаунт', self.now()))
        if not existing:
            self.db.execute('INSERT INTO identities VALUES (?,?,?,?)', (provider, subject, account_id, self.now()))
        return account_id

    def _issue(self, account_id, device):
        token, csrf, session_id = secrets.token_urlsafe(32), secrets.token_urlsafe(32), str(uuid.uuid4())
        now = self.now()
        self.db.execute('INSERT INTO sessions VALUES (?,?,?,?,?,?,?,?)',
                        (session_id, account_id, self.digest('session', token), self.digest('csrf', csrf), now, now + 30 * 86400, now, str(device)[:80]))
        return {'accountId': account_id, 'sessionId': session_id, 'sessionToken': token, 'csrfToken': csrf}

    def email_verify(self, challenge: str, binding: str, code: str, *, device='Development device'):
        error = None
        result = None
        with self.transaction():
            row = self.db.execute('SELECT * FROM email_challenges WHERE id=?', (challenge,)).fetchone()
            if not row or row['consumed'] or row['expires_at'] <= self.now() or row['attempts'] >= 5:
                raise ApiError(401, 'invalid_or_expired_code')
            if not hmac.compare_digest(row['binding_hash'], self.digest('binding', binding)):
                raise ApiError(401, 'invalid_or_expired_code')
            if not hmac.compare_digest(row['code_hash'], self.digest('otp', f'{challenge}:{code}')):
                self.db.execute('UPDATE email_challenges SET attempts=attempts+1 WHERE id=?', (challenge,))
                error = ApiError(401, 'invalid_or_expired_code')
            else:
                session = self._challenge_session(row['session_id'])
                try:
                    account = self._identity('email', row['email'], session)
                    result = {'accountId': account, 'linked': True} if session else self._issue(account, device)
                except ApiError as identity_error:
                    error = identity_error
                self.db.execute('UPDATE email_challenges SET consumed=1 WHERE id=?', (challenge,))
        if error:
            raise error
        return result

    def oauth_start(self, *, token=''):
        if not self.config.yandex_client_id or not self.config.yandex_client_secret:
            raise ApiError(503, 'yandex_not_configured')
        session = self._session(token, fresh=True) if token else None
        state, binding, verifier = (secrets.token_urlsafe(32) for _ in range(3))
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
        now = self.now()
        self.db.execute('INSERT INTO oauth_challenges VALUES (?,?,?,?,?,?,0)',
                        (self.digest('oauth', state), self.digest('binding', binding), verifier, session['id'] if session else None, now, now + 600))
        return {'authorizationUrl': 'https://oauth.yandex.ru/authorize?' + urlencode({
            'response_type': 'code', 'client_id': self.config.yandex_client_id,
            'redirect_uri': self.config.yandex_redirect_uri, 'scope': 'login:info',
            'state': state, 'code_challenge': challenge, 'code_challenge_method': 'S256',
            'force_confirm': 'yes',
        }), 'binding': binding}

    def oauth_complete(self, state: str, binding: str, code: str):
        state_hash = self.digest('oauth', state)
        with self.transaction():
            row = self.db.execute('SELECT * FROM oauth_challenges WHERE state_hash=?', (state_hash,)).fetchone()
            if not row or row['consumed'] or row['expires_at'] <= self.now() or not hmac.compare_digest(row['binding_hash'], self.digest('binding', binding)):
                raise ApiError(401, 'invalid_oauth_state')
            self.db.execute('UPDATE oauth_challenges SET consumed=1, verifier="" WHERE state_hash=?', (state_hash,))
        try:
            subject = self.yandex.exchange(code, row['verifier'])
        except Exception:
            raise ApiError(401, 'provider_authentication_failed') from None
        if not isinstance(subject, str) or not subject.strip():
            raise ApiError(401, 'provider_authentication_failed')
        with self.transaction():
            session = self._challenge_session(row['session_id'])
            account = self._identity('yandex', subject, session)
            return {'accountId': account, 'linked': True} if session else self._issue(account, 'Yandex browser login')

    def me(self, token):
        session = self._session(token)
        self.db.execute('UPDATE sessions SET last_seen_at=? WHERE id=?', (self.now(), session['id']))
        account = self.db.execute('SELECT * FROM accounts WHERE id=?', (session['account_id'],)).fetchone()
        identities = self.db.execute('SELECT provider,subject FROM identities WHERE account_id=?', (session['account_id'],)).fetchall()
        return {'id': account['id'], 'name': account['name'], 'identities': [dict(item) for item in identities],
                'cloudEnabled': False, 'mode': 'development'}

    def csrf(self, token):
        session = self._session(token)
        csrf = secrets.token_urlsafe(32)
        self.db.execute('UPDATE sessions SET csrf_hash=? WHERE id=?', (self.digest('csrf', csrf), session['id']))
        return {'csrfToken': csrf}

    def sessions(self, token):
        session = self._session(token)
        rows = self.db.execute('SELECT id,device,created_at,expires_at,last_seen_at FROM sessions WHERE account_id=? AND expires_at>? AND last_seen_at>=?',
                               (session['account_id'], self.now(), self.now() - 7 * 86400)).fetchall()
        return [{'id': row['id'], 'device': row['device'], 'createdAt': row['created_at'], 'current': row['id'] == session['id']} for row in rows]

    def revoke(self, token, session_id):
        session = self._session(token)
        self.db.execute('DELETE FROM sessions WHERE id=? AND account_id=?', (session_id, session['account_id']))

    def unlink(self, token, provider):
        session = self._session(token, fresh=True)
        with self.transaction():
            count = self.db.execute('SELECT count(*) FROM identities WHERE account_id=?', (session['account_id'],)).fetchone()[0]
            if count <= 1:
                raise ApiError(409, 'last_identity_required')
            self.db.execute('DELETE FROM identities WHERE account_id=? AND provider=?', (session['account_id'], provider))
            self.db.execute('DELETE FROM sessions WHERE account_id=? AND id<>?', (session['account_id'], session['id']))

    def delete_account(self, token):
        session = self._session(token, fresh=True)
        with self.transaction():
            email_subjects = self.db.execute('SELECT subject FROM identities WHERE account_id=? AND provider="email"', (session['account_id'],)).fetchall()
            for row in email_subjects:
                self.db.execute('DELETE FROM email_challenges WHERE email=?', (row['subject'],))
                self.db.execute('DELETE FROM rate_events WHERE key_hash=?', (self.digest('email_rate', row['subject']),))
            self.db.execute('DELETE FROM email_challenges WHERE session_id IN (SELECT id FROM sessions WHERE account_id=?)', (session['account_id'],))
            self.db.execute('DELETE FROM oauth_challenges WHERE session_id IN (SELECT id FROM sessions WHERE account_id=?)', (session['account_id'],))
            self.db.execute('DELETE FROM accounts WHERE id=?', (session['account_id'],))

    def cleanup(self):
        now = self.now()
        self.db.execute('DELETE FROM email_challenges WHERE expires_at<=? OR consumed=1', (now,))
        self.db.execute('DELETE FROM oauth_challenges WHERE expires_at<=? OR consumed=1', (now,))
        self.db.execute('DELETE FROM sessions WHERE expires_at<=? OR last_seen_at<?', (now, now - 7 * 86400))
        self.db.execute('DELETE FROM rate_events WHERE occurred_at<?', (now - 900,))
