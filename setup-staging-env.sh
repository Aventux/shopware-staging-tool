#!/bin/bash
# -----------------------------------------------------------------------------
# Shopware Staging Tool
# Automates the setup of a Shopware 6 staging environment
#
# Copyright (c) 2025 Aventux GmbH
# Licensed under the MIT License
# https://github.com/Aventux/shopware-staging-tool
# -----------------------------------------------------------------------------


# ----------------------------------
# Configuration
# ----------------------------------

LIVE_DB_HOST="localhost"
LIVE_DB_USER="root"
LIVE_DB_PASS="root"
LIVE_DB_NAME="sw669"

STAGING_DB_HOST="localhost"
STAGING_DB_USER="root"
STAGING_DB_PASS="root"
STAGING_DB_NAME="sw669_staging"

LIVE_PATH="/path/to/your/live-shop"
STAGING_PATH="/path/to/your/staging-shop"

LIVE_URL="https://live.example.com"
STAGING_URL="https://staging.example.com"

STEP=0
USE_SHOPWARE_CLI=false

# ----------------------------------
# Helper: progress bar
# ----------------------------------
progress() {
  STEP=$((STEP+1))
  echo ""
  echo "[$STEP/11] ➤ $1..."
}

# ----------------------------------
# Helper: command result check
# ----------------------------------
check_success() {
  if [ $? -eq 0 ]; then
    echo "✅ $1 completed."
  else
    echo "❌ Error during: $1"
    exit 1
  fi
}

# ----------------------------------
# Requirements
# ----------------------------------
progress "Checking for dump tool (shopware-cli or mysqldump)"

if command -v shopware-cli &> /dev/null; then
  echo "✅ shopware-cli is available – will be used for DB dump and CI."
  USE_SHOPWARE_CLI=true
elif command -v mysqldump &> /dev/null; then
  echo "⚠️ shopware-cli not found, but ✅ mysqldump is available – will be used as fallback."
  USE_SHOPWARE_CLI=false
else
  echo "❌ Neither shopware-cli nor mysqldump is installed. Cannot proceed."
  exit 1
fi

# ----------------------------------
# Create DB dump from live
# ----------------------------------
progress "Creating database dump from live"

if [ "$USE_SHOPWARE_CLI" = true ]; then
  shopware-cli project dump --clean \
    --host "$LIVE_DB_HOST" \
    --username "$LIVE_DB_USER" \
    --password "$LIVE_DB_PASS" \
    --output "staging.sql" \
    "$LIVE_DB_NAME"
  check_success "Dump via shopware-cli"
else
  echo "⚠️ Using mysqldump fallback..."
  mysqldump -h "$LIVE_DB_HOST" -u "$LIVE_DB_USER" -p"$LIVE_DB_PASS" "$LIVE_DB_NAME" > staging.sql
  check_success "Dump via mysqldump"
fi

# ----------------------------------
# Remove existing staging directory
# ----------------------------------
progress "Removing existing staging project folder"
if [ -d "$STAGING_PATH" ]; then
  rm -rf "$STAGING_PATH"
  check_success "Staging folder deletion"
fi

# ----------------------------------
# Copy live project to staging
# ----------------------------------
progress "Copying live project to staging"
cp -r "$LIVE_PATH/" "$STAGING_PATH"
check_success "Project copy"

# ----------------------------------
# Drop all tables in staging DB
# ----------------------------------
progress "Clearing staging database"
TABLES=$(MYSQL_PWD="$STAGING_DB_PASS" mysql -h "$STAGING_DB_HOST" -u "$STAGING_DB_USER" -Nse \
"SELECT table_name FROM information_schema.tables WHERE table_schema = '$STAGING_DB_NAME';")

if [ -n "$TABLES" ]; then
  echo "SET FOREIGN_KEY_CHECKS=0;" > drop_all.sql
  for table in $TABLES; do
    echo "DROP TABLE \`$table\`;" >> drop_all.sql
  done
  echo "SET FOREIGN_KEY_CHECKS=1;" >> drop_all.sql

  MYSQL_PWD="$STAGING_DB_PASS" mysql -h "$STAGING_DB_HOST" -u "$STAGING_DB_USER" "$STAGING_DB_NAME" < drop_all.sql
  rm drop_all.sql
  check_success "Dropping tables"
else
  echo "No tables found – skipping."
fi

# ----------------------------------
# Import dump into staging DB
# ----------------------------------
progress "Importing dump into staging database"
MYSQL_PWD="$STAGING_DB_PASS" mysql -h "$STAGING_DB_HOST" -u "$STAGING_DB_USER" "$STAGING_DB_NAME" < staging.sql
check_success "Import dump"

# ----------------------------------
# Create staging.yaml
# ----------------------------------
progress "Creating staging.yaml config"
STAGING_CONFIG_FILE="$STAGING_PATH/config/packages/staging.yaml"
mkdir -p "$(dirname "$STAGING_CONFIG_FILE")"

cat > "$STAGING_CONFIG_FILE" <<EOF
shopware:
    staging:
        mailing:
            disable_delivery: true
        storefront:
            show_banner: true
        administration:
            show_banner: true
        sales_channel:
            domain_rewrite:
                - type: prefix
                  match: $LIVE_URL
                  replace: $STAGING_URL
        elasticsearch:
            check_for_existence: true
EOF
check_success "Create staging.yaml"

# ----------------------------------
# Replace .env.local
# ----------------------------------
progress "Replacing .env.local"
if [ -f "$STAGING_PATH/.env.local" ]; then
  rm "$STAGING_PATH/.env.local"
  check_success "Delete .env.local"
fi

if [ -f "$STAGING_PATH/.env.staging" ]; then
  cp "$STAGING_PATH/.env.staging" "$STAGING_PATH/.env.local"
  check_success "Copy .env.staging to .env.local"
else
  echo "❌ .env.staging not found!"
  exit 1
fi

# ----------------------------------
# Run Shopware staging setup
# ----------------------------------
progress "Running system:setup:staging"
cd "$STAGING_PATH" || { echo "❌ Cannot change directory to $STAGING_PATH"; exit 1; }

echo "yes" | ./bin/console system:setup:staging
check_success "Staging setup"

# ----------------------------------
# Replace URLs in sales_channel_domain
# ----------------------------------
progress "Replacing URLs in sales_channel_domain"
mysql -h "$STAGING_DB_HOST" -u "$STAGING_DB_USER" -p"$STAGING_DB_PASS" "$STAGING_DB_NAME" -e \
"UPDATE sales_channel_domain SET url = REPLACE(url, '$LIVE_URL', '$STAGING_URL');"
check_success "URL rewrite"

# ----------------------------------
# Run CI process
# ----------------------------------
progress "Building assets / CI process"

if [ "$USE_SHOPWARE_CLI" = true ]; then
  shopware-cli project ci "$STAGING_PATH"
  check_success "CI process via shopware-cli"
else
  echo "⚠️ Running manual build commands..."
  ./bin/build-administration.sh
  check_success "Administration build"

  ./bin/build-storefront.sh
  check_success "Storefront build"

  ./bin/console cache:clear
  check_success "Cache clear"
fi

# ----------------------------------
# Done
# ----------------------------------
echo ""
echo "✅ Staging environment successfully created at: $STAGING_URL"
