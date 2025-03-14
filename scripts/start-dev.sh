#!/bin/bash

set -euo pipefail  # Safe scripting options

CONTAINER="auth-db"
DB_USER="postgres"
DB_NAME="authdb"
DB_STARTUP_ELAPSED=0
DB_STARTUP_TIMEOUT=15
SPRINGBOOT_APP_PID=0

# ✅ Cleanup function to stop everything on exit
cleanup() {
    echo -e "\n🛑 Stopping services..."

    # ✅ Kill Spring Boot properly
    if [ "$SPRINGBOOT_APP_PID" -ne 0 ] && ps -p "$SPRINGBOOT_APP_PID" > /dev/null; then
        echo "🛑 Stopping Spring Boot (PID: $SPRINGBOOT_APP_PID)..."
        kill "$SPRINGBOOT_APP_PID" || true
        wait "$SPRINGBOOT_APP_PID" 2>/dev/null || true
    fi

    # ✅ Stop PostgreSQL container
    docker-compose down || echo "⚠️ Warning: docker-compose down failed."

    echo "✅ Cleanup complete."
}

# ✅ Trap `Ctrl + C` and script exit
trap cleanup EXIT

# ✅ Start PostgreSQL container if not running
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    echo "🚀 Starting Auth DB container..."
    docker-compose up -d
fi

# ✅ Wait for PostgreSQL to be ready
while ! docker exec "$CONTAINER" pg_isready -U "$DB_USER" > /dev/null 2>&1; do
    if [ "$DB_STARTUP_ELAPSED" -ge "$DB_STARTUP_TIMEOUT" ]; then
        echo "❌ PostgreSQL did not become ready within $DB_STARTUP_TIMEOUT seconds."
        exit 1
    fi
    sleep 2
    DB_STARTUP_ELAPSED=$((DB_STARTUP_ELAPSED+2))
done
echo "✅ PostgreSQL is ready."

# ✅ Ensure the database exists
if ! docker exec "$CONTAINER" psql -U "$DB_USER" -tAc \
    "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" > /dev/null 2>&1; then
    echo "🛠 Creating database '$DB_NAME'..."
    docker exec "$CONTAINER" psql -U "$DB_USER" -c "CREATE DATABASE $DB_NAME;"
fi

# ✅ Start Spring Boot in the foreground & capture its PID
echo "🚀 Starting Spring Boot application..."
./gradlew bootRun &
SPRINGBOOT_APP_PID=$!

# ✅ Wait for Spring Boot to exit
wait $SPRINGBOOT_APP_PID
