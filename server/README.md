# Серверная основа аккаунтов

Исполняемый development API на Python 3.11+ без внешних пакетов. SQLite содержит только аккаунты, подтверждённые способы входа, одноразовые запросы и сеансы. Данные лекарств не принимаются. Flutter пока использует независимый локальный демо-контроллер.

Сервис слушает только `127.0.0.1`. Он не предназначен для публикации или обработки реальных медицинских данных. HTTP, однопоточный `HTTPServer`, SQLite и локальные лимиты следует заменить перед production-запуском согласно [плану](../docs/accounts.md).

## Запуск из корня проекта

```bash
export APP_PEPPER="$(python3 -c 'import secrets; print(secrets.token_urlsafe(48))')"
export APP_DEV_MAIL=1
python3 -m server.app
```

Не выводите APP_PEPPER в журнал и не включайте `.env` в Git. Изменение pepper аннулирует существующие коды и сессии; production требует управляемой ротации. SQLite-файл создаётся в игнорируемом `server/.data/` с правами 0600. Переменные перечислены в `.env.example`; автоматического чтения `.env` нет.

```bash
python3 -m unittest discover -s server/tests -v
```

## Контракт API

Все POST принимают JSON, ответы — JSON с `Cache-Control: no-store`. Ошибки: `{"error":"machine_readable_code"}`. Нет wildcard CORS; браузерные запросы должны идти с того же origin. Flutter web на другом порту намеренно не подключён. Нативный клиент использует Bearer, браузер — HttpOnly cookie.

| Метод и маршрут | Тело / результат |
| --- | --- |
| GET `/api/health` | Development и `cloudEnabled:false` |
| GET `/api/auth/providers` | RU-политика и фактически настроенные провайдеры |
| POST `/api/auth/email/start` | `email`, `purpose:signin\|link`; возвращает `challengeId`, `binding`, TTL 600, retry 60 |
| POST `/api/auth/email/verify` | `challengeId`, `binding`, `code`, необязательный `device`; возвращает ID аккаунта/сеанса, токен и CSRF либо результат привязки |
| POST `/api/auth/yandex/start` | `purpose:signin\|link`; возвращает `authorizationUrl`, устанавливает привязку в HttpOnly SameSite=Lax cookie |
| GET `/api/auth/yandex/callback` | `state`, `code`; сверяет cookie, меняет код через сервер, проверяет ID и client_id, устанавливает сессию |
| GET `/api/account` | Собственный аккаунт и идентификаторы |
| GET `/api/account/csrf` | Новый CSRF для текущей сессии; прежний аннулируется, нужен после callback/reload |
| GET `/api/account/sessions` | Только собственные действующие сеансы |
| POST `/api/account/sessions/revoke` | `sessionId`; чужой сеанс не отзывается |
| POST `/api/account/identities/unlink` | `provider`; свежий вход, последний способ защищён |
| POST `/api/auth/logout` | `{}`; завершение текущего сеанса |
| POST `/api/account/delete` | `confirmation:DELETE`; свежий вход, каскадное удаление dev-записей аккаунта |
| POST `/api/account/snapshot`, `/api/account/health-consent` | Всегда 423, облако не включается клиентской галочкой |

Защищённые POST и начало привязки требуют `X-CSRF-Token`. Сессия имеет абсолютный срок 30 дней и предел бездействия 7 дней; чувствительные операции требуют сессии не старше 10 минут. Пока повторный вход создаёт новую сессию; отдельный production challenge реаутентификации ещё нужен. Название устройства — сообщение клиента, а не проверенный fingerprint. GET CSRF не разрешён стороннему origin посредством CORS; frontend читает его только с origin API. При обновлении CSRF в другой вкладке нужно получить актуальный токен.

OTP случайный, шесть цифр, действует десять минут, пять попыток, повторная выдача аннулирует прежний код. Лимиты: пять запросов на адрес и двадцать на IP за 15 минут, пауза 60 секунд. Dev-код возвращается только при `APP_DEV_MAIL=1` и только на `example.test`. Реальные адреса даже при расширении allowlist не получают dev-код. Без SMTP и без dev-режима выдача возвращает 503.

SMTP использует TLS (`SMTP_SSL`), параметры `SMTP_HOST`, `SMTP_PORT`, `SMTP_FROM`, `SMTP_USER`, `SMTP_PASSWORD`. До отправки настоящих писем нужны договоры и проверка трансграничных потоков; allowlist доменов по умолчанию — только `example.test`. Письмо содержит только код входа.

Яндекс включается при наличии client ID и secret. Минимальный scope — `login:info`; PKCE S256, state и cookie binding защищают поток, код/состояние одноразовые, срок десять минут. Токен провайдера не сохраняется. Callback не отдаёт токены в URL или JSON браузеру. Для нативного клиента нужен отдельный одноразовый ticket exchange и проверенные app links; текущий callback предназначен для same-origin браузера. Production cookie должен иметь Secure и действовать по HTTPS; текущий HTTP разрешён только loopback.

Токены, CSRF, OTP и nonce хранятся как HMAC-хеши; временный PKCE verifier удаляется при завершении/истечении. Email и внешний subject — персональные данные, хранятся в открытых столбцах SQLite; HMAC не означает шифрование всей БД. Журнал HTTP выключен, чтобы исключить OAuth-коды из URL. Production требует мониторинг без секретов, независимый аудит, шифрование/управление ключами, лимиты на все ресурсоёмкие операции, обработку сбоев почты и процедуры удаления резервных копий.

`migrations/001_accounts.sql` фиксирует будущую PostgreSQL-модель аккаунтов, владения и приватной истории. Она не применяется этим API и не содержит готовой реализации синхронизации или RLS; публичный запуск по ней без серверных проверок прав недопустим.
