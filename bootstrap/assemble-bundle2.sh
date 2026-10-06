#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_B64="${RUNNER_TEMP:-/tmp}/moi-finansy-source.b64"
TMP_TGZ="${RUNNER_TEMP:-/tmp}/moi-finansy-source.tar.gz"

cd "$ROOT"
cat bundle2/part-*.b64 > "$TMP_B64"
base64 --decode "$TMP_B64" > "$TMP_TGZ"

EXPECTED="27007763a1f15c222246a3578fee3cb9945abf585150df82cd37a616e62ba41e"
ACTUAL="$(sha256sum "$TMP_TGZ" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "Source bundle checksum mismatch: $ACTUAL" >&2
  exit 1
fi

tar -xzf "$TMP_TGZ" -C "$ROOT"

# Apply small staging/build fixes that landed after the source bundle snapshot.
cp "$ROOT/bootstrap/patches/reset-password-page.tsx" "$ROOT/apps/web/app/reset-password/page.tsx"
cp "$ROOT/bootstrap/patches/verify-email-page.tsx" "$ROOT/apps/web/app/verify-email/page.tsx"
cp "$ROOT/bootstrap/patches/api-tsconfig.json" "$ROOT/apps/api/tsconfig.json"
cp "$ROOT/bootstrap/patches/debts.module.ts" "$ROOT/apps/api/src/debts/debts.module.ts"
cp "$ROOT/bootstrap/patches/notifications.module.ts" "$ROOT/apps/api/src/notifications/notifications.module.ts"

# Android API 36 compatibility for hosted CI runners.
sed -i 's/compileSdk = 37/compileSdk = 36/; s/targetSdk = 37/targetSdk = 36/' "$ROOT/apps/android/app/build.gradle.kts"

# Keep the current Kotlin Android plugin compatible with AGP 9 during staging builds.
printf '\nandroid.newDsl=false\n' >> "$ROOT/apps/android/gradle.properties"

# Fix account deletion cascade blockers (budget_items/categories and ledger_entries/accounts).
node <<'NODE'
const fs = require('fs');
const p = process.cwd() + '/apps/api/src/auth/auth.service.ts';
let src = fs.readFileSync(p, 'utf8');
const old = `    await this.audit(userId,'ACCOUNT_DELETE','USER',userId,{});
    await this.db.query(\`DELETE FROM users WHERE id=$1\`,[userId]);
    return {success:true};
`;
const replacement = `    await this.audit(userId,'ACCOUNT_DELETE','USER',userId,{});
    await this.db.transaction(async client=>{
      await client.query(
        \`DELETE FROM budget_items WHERE budget_id IN (SELECT id FROM budgets WHERE user_id=$1)\`,
        [userId],
      );
      await client.query(\`DELETE FROM ledger_entries WHERE user_id=$1\`,[userId]);
      await client.query(\`DELETE FROM users WHERE id=$1\`,[userId]);
    });
    return {success:true};
`;
if (!src.includes(old)) throw new Error('Account deletion patch target not found');
fs.writeFileSync(p, src.replace(old, replacement));
NODE

echo "Source bundle unpacked successfully."
