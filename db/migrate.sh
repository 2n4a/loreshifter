set -euo pipefail

echo "Running migrations..."

until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; do
  echo "Waiting for database to be ready..."
  sleep 1
done

for f in /migrations/*.sql; do
  echo "Applying migration: $(basename "$f")"
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo "All migrations applied successfully."
