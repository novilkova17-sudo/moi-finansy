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

# Android 17 / API 37.0 uses a minor-versioned platform package.
node <<'NODE_ANDROID_SDK'
const fs = require('fs');
const p = process.cwd() + '/apps/android/app/build.gradle.kts';
let src = fs.readFileSync(p, 'utf8');
src = src.replace(
  '    compileSdk = 37\n',
  '    compileSdk {\n        version = release(37) {\n            minorApiLevel = 0\n        }\n    }\n'
);
fs.writeFileSync(p, src);
NODE_ANDROID_SDK

# Keep the current Kotlin Android plugin compatible with AGP 9 during staging builds.
printf '\nandroid.newDsl=false\n' >> "$ROOT/apps/android/gradle.properties"

# Align Java and Kotlin bytecode targets on JDK 17.
node <<'NODE_ANDROID_JVM'
const fs = require('fs');
const p = process.cwd() + '/apps/android/app/build.gradle.kts';
let src = fs.readFileSync(p, 'utf8');
if (!src.includes('compileOptions {')) {
  const marker = '    defaultConfig {';
  src = src.replace(
    marker,
    '    compileOptions {\n        sourceCompatibility = JavaVersion.VERSION_17\n        targetCompatibility = JavaVersion.VERSION_17\n    }\n' + marker
  );
}
fs.writeFileSync(p, src);
NODE_ANDROID_JVM

# Material3 TopAppBar is still experimental in the current Compose line.
node <<'NODE_MATERIAL3_OPTIN'
const fs = require('fs');
const path = require('path');
const root = process.cwd() + '/apps/android/app/src/main/java';
function walk(dir) {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (entry.isFile() && p.endsWith('.kt')) {
      let src = fs.readFileSync(p, 'utf8');
      if (src.includes('TopAppBar(') && !src.includes('@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)')) {
        src = '@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)\n\n' + src;
        fs.writeFileSync(p, src);
      }
    }
  }
}
walk(root);
NODE_MATERIAL3_OPTIN

# Fix Android source compile blockers found by CI.
node <<'NODE_ANDROID_SOURCE_FIXES'
const fs = require('fs');

const budgetPath = process.cwd() + '/apps/android/app/src/main/java/com/moifinansy/app/features/budget/BudgetScreen.kt';
let budget = fs.readFileSync(budgetPath, 'utf8');
budget = budget.replace('onClick={save}){Text("Сохранить")}', 'onClick={save()}){Text("Сохранить")}');
fs.writeFileSync(budgetPath, budget);

const planPath = process.cwd() + '/apps/android/app/src/main/java/com/moifinansy/app/features/planning/PlanScreen.kt';
let plan = fs.readFileSync(planPath, 'utf8');
const oldSelect = '@Composable private fun Select(label:String,options:List<Pair<String,String>>,value:String,onChange:(String)->Unit){var open by remember{mutableStateOf(false)};Box{OutlinedButton(onClick={open=true},Modifier.fillMaxWidth()){Text("$label: "+(options.firstOrNull{it.first==value}?.second?:"—"),maxLines=1)};DropdownMenu(open,{open=false}){options.forEach{(id,name)->DropdownMenuItem(text={Text(name)},onClick={onChange(id);open=false})}}}}';
const newSelect = `@Composable
private fun Select(
    label: String,
    options: List<Pair<String, String>>,
    value: String,
    onChange: (String) -> Unit,
) {
    var open by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { option -> option.first == value }?.second ?: "—"
    Box {
        OutlinedButton(
            onClick = { open = true },
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("$label: $selectedLabel", maxLines = 1)
        }
        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false },
        ) {
            options.forEach { (id, name) ->
                DropdownMenuItem(
                    text = { Text(name) },
                    onClick = {
                        onChange(id)
                        open = false
                    },
                )
            }
        }
    }
}`;
if (!plan.includes(oldSelect)) throw new Error('Plan Select patch target not found');
plan = plan.replace(oldSelect, newSelect);
fs.writeFileSync(planPath, plan);

for (const variant of ['debug', 'staging']) {
  const p = process.cwd() + '/apps/android/app/src/' + variant + '/AndroidManifest.xml';
  let manifest = fs.readFileSync(p, 'utf8');
  if (!manifest.includes('xmlns:tools=')) {
    manifest = manifest.replace(
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">'
    );
  }
  manifest = manifest.replace(
    /<application\s+([^>]*?)android:usesCleartextTraffic="(true|false)"\s*\/>/s,
    (_m, before, value) => '<application\n        ' + before.trim() + (before.trim() ? '\n        ' : '') + 'android:usesCleartextTraffic="' + value + '"\n        tools:replace="android:usesCleartextTraffic" />'
  );
  fs.writeFileSync(p, manifest);
}
NODE_ANDROID_SOURCE_FIXES

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
