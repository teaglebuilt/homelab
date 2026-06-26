#!/bin/sh
# Idempotent FreshRSS provisioning: install, create user, import feeds.
# Safe to run on every pod start. Feeds/users/entries live in Postgres, so this
# converges a fresh cluster to the desired declarative state with no manual UI setup.
set -eu

cd /var/www/FreshRSS

echo "[provision] waiting for postgres at ${DB_HOST}..."
attempt=0
until php -r '
  $h = getenv("DB_HOST"); $b = getenv("DB_BASE");
  $u = getenv("DB_USER"); $p = getenv("DB_PASSWORD");
  try { new PDO("pgsql:host=$h;dbname=$b", $u, $p); exit(0); }
  catch (Throwable $e) { exit(1); }
' 2>/dev/null; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "[provision] postgres not reachable after $attempt attempts" >&2
    exit 1
  fi
  sleep 3
done
echo "[provision] postgres reachable"

if [ ! -f data/config.php ]; then
  echo "[provision] running do-install"
  ./cli/do-install.php \
    --default-user "${DEFAULT_USER}" \
    --auth-type form \
    --environment production \
    --base-url "${BASE_URL}" \
    --language en \
    --api-enabled \
    --db-type pgsql \
    --db-host "${DB_HOST}" \
    --db-base "${DB_BASE}" \
    --db-user "${DB_USER}" \
    --db-password "${DB_PASSWORD}"
else
  echo "[provision] config.php present; skipping do-install"
fi

if ./cli/list-users.php | grep -Fxq "${DEFAULT_USER}"; then
  echo "[provision] user ${DEFAULT_USER} already exists"
else
  echo "[provision] creating user ${DEFAULT_USER}"
  ./cli/create-user.php \
    --user "${DEFAULT_USER}" \
    --password "${ADMIN_PASSWORD}" \
    --api-password "${ADMIN_API_PASSWORD}" \
    --language en
fi

# Import every OPML seed mounted at /opml (feeds are deduplicated by xmlUrl,
# so re-importing on every start is safe and converges to the declared state).
imported=0
for opml in /opml/*.opml; do
  [ -e "$opml" ] || continue
  echo "[provision] importing feeds from ${opml} (idempotent)"
  ./cli/import-for-user.php --user "${DEFAULT_USER}" --filename "${opml}"
  imported=$((imported + 1))
done
[ "$imported" -eq 0 ] && echo "[provision] no OPML seeds found; skipping feed import"

# Ensure the data dir is writable by the runtime user (apache drops to www-data).
chown -R www-data:www-data data || true

echo "[provision] done"
