#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-lab_postgres}"
POSTGRES_USER="${POSTGRES_USER:-app_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-app_password_secure}"
POSTGRES_DB="${POSTGRES_DB:-app_db}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

require_container() {
  if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    echo "Container '$CONTAINER_NAME' is not running. Start it first with: docker compose up -d"
    exit 1
  fi
}

wait_for_postgres() {
  local max_attempts=30
  local attempt=1

  while [ "$attempt" -le "$max_attempts" ]; do
    if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d postgres >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    attempt=$((attempt + 1))
  done

  echo "PostgreSQL in container '$CONTAINER_NAME' did not become ready in time."
  exit 1
}

ensure_db_exists() {
  local exists
  exists=$(docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$POSTGRES_DB';")

  if [ -z "$exists" ]; then
    log "Creating database: $POSTGRES_DB"
    docker exec -i "$CONTAINER_NAME" createdb -U "$POSTGRES_USER" "$POSTGRES_DB"
  else
    log "Database already exists: $POSTGRES_DB"
  fi
}

ensure_user_exists() {
  local exists
  exists=$(docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$POSTGRES_USER';")

  if [ -z "$exists" ]; then
    log "Creating user: $POSTGRES_USER"
    docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 <<SQL
CREATE ROLE "$POSTGRES_USER" WITH LOGIN PASSWORD '$POSTGRES_PASSWORD';
SQL
  else
    log "User already exists: $POSTGRES_USER"
    docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 <<SQL
ALTER ROLE "$POSTGRES_USER" WITH LOGIN PASSWORD '$POSTGRES_PASSWORD';
SQL
  fi
}

seed_data() {
  log "Seeding sample data..."
  docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id),
    product_name VARCHAR(100) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    total_amount NUMERIC(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (username, email)
VALUES
    ('alice', 'alice@example.com'),
    ('bob', 'bob@example.com'),
    ('charlie', 'charlie@example.com')
ON CONFLICT (username) DO NOTHING;

INSERT INTO orders (user_id, product_name, quantity, total_amount)
SELECT id, 'Laptop', 1, 1500.00 FROM users WHERE username = 'alice'
ON CONFLICT DO NOTHING;

INSERT INTO orders (user_id, product_name, quantity, total_amount)
SELECT id, 'Mouse', 2, 80.00 FROM users WHERE username = 'bob'
ON CONFLICT DO NOTHING;
SQL

  log "Sample data inserted successfully."
}

main() {
  log "Starting PostgreSQL setup..."
  require_container
  wait_for_postgres
  ensure_db_exists
  ensure_user_exists
  seed_data
  log "Setup completed successfully."
}

main "$@"
