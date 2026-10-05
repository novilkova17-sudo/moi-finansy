# Render staging bootstrap

Render build commands unpack the source bundle before installing dependencies.

API build:
```bash
bash bootstrap/assemble-bundle2.sh && npm install && npm --workspace @moi-finansy/api run build
```

API start:
```bash
node scripts/migrate-db.mjs && npm --workspace @moi-finansy/api run start
```

Web build:
```bash
bash bootstrap/assemble-bundle2.sh && npm install && npm --workspace @moi-finansy/web run build
```

Web start:
```bash
npm --workspace @moi-finansy/web run start
```
