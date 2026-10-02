import io
import json
import unittest
from urllib.parse import parse_qs, urlparse

from server.app import handler_for
from server.auth import ApiError, AuthService, Config


class FakeYandex:
    subject = 'verified-yandex-id'
    calls = 0
    def exchange(self, code, verifier):
        self.calls += 1
        if not code or len(verifier) < 43:
            raise ValueError('bad proof')
        return self.subject


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.time = 1000000
        self.yandex = FakeYandex()
        self.service = AuthService(Config(pepper='test-only-pepper-' * 3, dev_delivery=True,
            yandex_client_id='test-app', yandex_client_secret='test-secret'),
            yandex=self.yandex, now=lambda: self.time)
        self.addCleanup(self.service.close)

    def login(self, email='anna@example.test'):
        challenge = self.service.email_start(email, 'test-ip')
        return self.service.email_verify(challenge['challengeId'], challenge['binding'], challenge['devCode'])

    def error(self, code, action):
        with self.assertRaises(ApiError) as caught:
            action()
        self.assertEqual(caught.exception.code, code)

    def test_verified_email_returns_same_account_and_tokens_are_not_stored(self):
        first = self.login()
        self.time += 61
        second = self.login()
        self.assertEqual(first['accountId'], second['accountId'])
        self.assertNotEqual(first['sessionToken'], second['sessionToken'])
        row = self.service.db.execute('SELECT * FROM sessions WHERE id=?', (first['sessionId'],)).fetchone()
        self.assertNotEqual(row['token_hash'], first['sessionToken'])
        self.assertNotEqual(row['csrf_hash'], first['csrfToken'])

    def test_wrong_codes_exhaust_attempts_and_replay_is_rejected(self):
        challenge = self.service.email_start('anna@example.test', 'ip')
        wrong = '000000' if challenge['devCode'] != '000000' else '111111'
        for _ in range(5):
            self.error('invalid_or_expired_code', lambda: self.service.email_verify(challenge['challengeId'], challenge['binding'], wrong))
        self.error('invalid_or_expired_code', lambda: self.service.email_verify(challenge['challengeId'], challenge['binding'], challenge['devCode']))
        self.time += 61
        valid = self.service.email_start('anna@example.test', 'ip')
        self.service.email_verify(valid['challengeId'], valid['binding'], valid['devCode'])
        self.error('invalid_or_expired_code', lambda: self.service.email_verify(valid['challengeId'], valid['binding'], valid['devCode']))

    def test_code_is_bound_to_client_and_expires(self):
        challenge = self.service.email_start('anna@example.test', 'ip')
        self.error('invalid_or_expired_code', lambda: self.service.email_verify(challenge['challengeId'], 'other-device', challenge['devCode']))
        self.time += 601
        self.error('invalid_or_expired_code', lambda: self.service.email_verify(challenge['challengeId'], challenge['binding'], challenge['devCode']))

    def test_rate_limits_cooldown_and_development_rejects_real_email(self):
        self.service.email_start('anna@example.test', 'ip')
        self.error('try_later', lambda: self.service.email_start('anna@example.test', 'ip'))
        for _ in range(4):
            self.time += 61
            self.service.email_start('anna@example.test', 'ip')
        self.time += 61
        self.error('try_later', lambda: self.service.email_start('anna@example.test', 'ip'))
        self.error('email_domain_not_enabled', lambda: self.service.email_start('real@gmail.com', 'ip'))
        actual = AuthService(Config(pepper='test-only-pepper-' * 3))
        self.addCleanup(actual.close)
        self.error('mail_transport_not_configured', lambda: actual.email_start('anna@example.test', 'ip'))

    def test_cleanup_does_not_bypass_resend_cooldown_and_csrf_can_refresh(self):
        signed = self.login()
        self.service.cleanup()
        self.error('try_later', lambda: self.service.email_start('anna@example.test', 'ip'))
        refreshed = self.service.csrf(signed['sessionToken'])['csrfToken']
        self.error('csrf_failed', lambda: self.service.require_csrf(signed['sessionToken'], signed['csrfToken']))
        self.service.require_csrf(signed['sessionToken'], refreshed)

    def test_oauth_pkce_binding_and_replay(self):
        flow = self.service.oauth_start()
        params = parse_qs(urlparse(flow['authorizationUrl']).query)
        self.assertEqual(params['code_challenge_method'], ['S256'])
        self.assertEqual(params['scope'], ['login:info'])
        self.assertNotIn('client_secret', params)
        state = params['state'][0]
        self.error('invalid_oauth_state', lambda: self.service.oauth_complete(state, 'attacker', 'code'))
        self.assertEqual(self.yandex.calls, 0)
        signed = self.service.oauth_complete(state, flow['binding'], 'code')
        self.assertTrue(signed['accountId'])
        self.error('invalid_oauth_state', lambda: self.service.oauth_complete(state, flow['binding'], 'code'))
        self.assertEqual(self.yandex.calls, 1)

    def test_linking_is_explicit_and_cannot_take_another_identity(self):
        first = self.login()
        second = self.login('bob@example.test')
        self.time += 61
        challenge = self.service.email_start('bob@example.test', 'ip', purpose='link', token=first['sessionToken'])
        self.error('identity_linked_elsewhere', lambda: self.service.email_verify(challenge['challengeId'], challenge['binding'], challenge['devCode']))
        self.assertEqual(self.service.me(second['sessionToken'])['id'], second['accountId'])
        flow = self.service.oauth_start(token=first['sessionToken'])
        state = parse_qs(urlparse(flow['authorizationUrl']).query)['state'][0]
        linked = self.service.oauth_complete(state, flow['binding'], 'code')
        self.assertEqual(linked, {'accountId': first['accountId'], 'linked': True})
        self.assertEqual(len(self.service.me(first['sessionToken'])['identities']), 2)

    def test_last_identity_and_fresh_auth_and_revoked_link_session(self):
        signed = self.login()
        self.error('last_identity_required', lambda: self.service.unlink(signed['sessionToken'], 'email'))
        flow = self.service.oauth_start(token=signed['sessionToken'])
        state = parse_qs(urlparse(flow['authorizationUrl']).query)['state'][0]
        self.service.revoke(signed['sessionToken'], signed['sessionId'])
        self.error('reauthentication_required', lambda: self.service.oauth_complete(state, flow['binding'], 'code'))
        self.time += 61
        signed = self.login()
        self.time += 601
        self.error('reauthentication_required', lambda: self.service.delete_account(signed['sessionToken']))

    def test_accounts_cannot_revoke_each_others_sessions_and_deletion_cascades(self):
        first, second = self.login(), self.login('bob@example.test')
        self.service.revoke(first['sessionToken'], second['sessionId'])
        self.assertEqual(len(self.service.sessions(second['sessionToken'])), 1)
        self.service.delete_account(first['sessionToken'])
        self.error('session_expired', lambda: self.service.me(first['sessionToken']))
        self.assertEqual(len(self.service.me(second['sessionToken'])['identities']), 1)
        self.assertEqual(self.service.db.execute('SELECT count(*) FROM accounts').fetchone()[0], 1)

    def request(self, path, body, headers=None):
        class Connection:
            output = b''
            def makefile(self, *_):
                return io.BytesIO(request)
            def sendall(self, data):
                self.output += data
        payload = json.dumps(body).encode()
        parts = [f'POST {path} HTTP/1.0', 'Host: 127.0.0.1:8030', 'Content-Type: application/json', f'Content-Length: {len(payload)}']
        parts.extend(f'{key}: {value}' for key, value in (headers or {}).items())
        request = ('\r\n'.join(parts) + '\r\n\r\n').encode() + payload
        connection = Connection()
        handler_for(self.service, 8030)(connection, ('127.0.0.1', 9000), object())
        header, response = connection.output.split(b'\r\n\r\n', 1)
        return header.decode(), json.loads(response)

    def test_http_origin_csrf_and_cloud_gate(self):
        signed = self.login()
        headers, response = self.request('/api/auth/email/start', {'email': 'bob@example.test'}, {'Origin': 'https://attacker.invalid'})
        self.assertIn('403', headers)
        self.assertEqual(response['error'], 'origin_rejected')
        headers, response = self.request('/api/account/delete', {'confirmation': 'DELETE'}, {'Authorization': 'Bearer ' + signed['sessionToken']})
        self.assertEqual(response['error'], 'csrf_failed')
        headers, response = self.request('/api/account/snapshot', {'consent': True}, {
            'Authorization': 'Bearer ' + signed['sessionToken'], 'X-CSRF-Token': signed['csrfToken'],
        })
        self.assertIn('423', headers)
        self.assertEqual(response['error'], 'health_data_processing_not_enabled')
        self.assertIn('Cache-Control: no-store', headers)


if __name__ == '__main__':
    unittest.main()
