# Мои финансы — Release Candidate 0.8.0

Монорепозиторий персонального финансового сервиса: NestJS API, Next.js Web и Android Jetpack Compose.

## Что уже работает

### Финансовое ядро
- счета: дебетовые карты, кредитные карты, наличные, накопительные и другие;
- категории и подкатегории максимум в 2 уровня;
- расходы, доходы и переводы между собственными счетами;
- двойная ledger-модель для безопасного движения денег;
- защита offline-операций от двойного проведения через `clientRequestId`;
- Главная с реальными агрегатами;
- План и регулярные платежи, включая каждые N дней / каждые 14 дней;
- подтверждение План → фактическая операция → ledger → баланс;
- Бюджет: Среднее / План / Факт / Осталось;
- Аналитика: категории, donut, динамика, сравнение периодов, Plan/Fact и автоматические инсайты;
- кредиты, рассрочки, микрозаймы, «я должен / мне должны»;
- графики долгов автоматически попадают в План;
- уведомления о платежах, просрочках и бюджете.

### Пользовательский контур
- регистрация и вход;
- email verification;
- восстановление пароля;
- access + rotating refresh sessions;
- активные устройства / сессии и мгновенный revoke;
- смена пароля отзывает старые сессии;
- onboarding нового пользователя;
- профиль и настройки;
- Light / Dark / System;
- экспорт данных и удаление аккаунта;
- Android Keystore для токенов;
- Web HttpOnly cookies;
- Android offline read-cache и offline queue для операций.

### Release Candidate hardening
- production fail-fast конфигурация;
- HTTPS-only release URL на Android;
- security headers;
- readiness PostgreSQL + проверка версии schema migration;
- rate limit публичных auth-endpoint'ов через PostgreSQL;
- email outbox с retry/backoff и idempotency key;
- client error reporting с redaction чувствительных полей;
- логические PostgreSQL backup/restore scripts;
- financial integrity SQL checks;
- production Docker Compose + опциональный Caddy HTTPS edge;
- GitHub Actions для API/Web и Android;
- production-auth staging gate + phone-installable staging APK;
- Render Blueprint для API + Web + PostgreSQL;
- portable Node migration runner для managed hosting;
- signed Android release workflow.

## Архитектура

```text
apps/
  api/       NestJS API
  web/       Next.js Web cabinet
  android/   Kotlin + Jetpack Compose

db/
  migrations/
  seeds/
design/references/   утвержденные Mobile/Web Light/Dark референсы
docs/                архитектура, beta/RC checklist, deploy/runbooks
scripts/             smoke, backup, restore, integrity, release scripts
```

Бизнес-логика расчетов живет на backend. Android и Web не должны независимо пересчитывать баланс, budget fact, обязательные платежи и аналитику.

## Быстрый локальный старт

Требования:
- Node.js 24 LTS;
- PostgreSQL 17;
- Android Studio / Android SDK для мобильной части.

```bash
cp .env.example .env
# замените ACCESS_TOKEN_SECRET

docker compose up -d postgres
npm install
npm run db:migrate
npm run dev:api
npm run dev:web
```

Android Emulator использует debug API `http://10.0.2.2:4000`.

## Полезные проверки

```bash
npm run smoke:auth
npm run smoke:analytics
npm run smoke:debts
npm run smoke:notifications
npm run smoke:beta
npm run smoke:rc
API_URL=https://<staging-api-host> npm run smoke:staging
npm run integrity
bash scripts/validate-release-repo.sh
```

## Production / staging

```bash
cp .env.production.example .env.production
# заполнить секреты и реальные HTTPS URL

./scripts/check-production-env.sh .env.production

docker compose --env-file .env.production \
  -f docker-compose.production.yml \
  -f docker-compose.edge.yml \
  up -d --build
```

Production stack:
1. PostgreSQL;
2. one-shot migration runner;
3. API;
4. Web;
5. optional Caddy edge для TLS;
6. ops profiles для integrity и backup.

Для managed staging также подготовлен `render.yaml`. Подробности: `docs/staging-deployment.md`, `docs/database-migrations.md`, `docs/backup-restore.md`.

## Android release

Release build требует HTTPS API и внешний upload keystore.

```bash
export MF_API_BASE_URL=https://api.your-domain.example
export MF_KEYSTORE_PATH=/secure/moi-finansy-upload.jks
export MF_KEYSTORE_PASSWORD='...'
export MF_KEY_ALIAS='...'
export MF_KEY_PASSWORD='...'
./scripts/build-android-release.sh
```

GitHub workflow `Android signed release` выпускает APK и AAB как artifacts.

Для первого реального телефона используется отдельный `staging` APK с публичным HTTPS API. Подробнее: `docs/android-release.md` и `docs/first-device-test.md`.

## Важное beta-ограничение offline

Просмотр последних синхронизированных Главной, счетов, операций и Плана доступен offline. Offline-запись поддерживается для расхода, дохода и перевода. Изменение бюджета, Плана, долгов и профиля пока требует соединения.

## Статус проверки в этой среде

Синтаксис shell/JSON и структура проекта проверяются локально. Полный `npm install` в текущей рабочей среде упирается в сетевой timeout, поэтому фактический Node/Android build должен быть подтвержден CI или локальной машиной с доступом к registry/Android SDK.

## Следующий milestone

RC → staging → физический Android-девайс → beta acceptance checklist → исправления → 1.0 public beta.
