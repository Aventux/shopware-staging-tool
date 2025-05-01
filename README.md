# Shopware Staging Tool

This shell script automates the creation of a complete staging environment for a Shopware 6 project.  
It handles database export/import, file copying, URL rewrites, and full setup including CI processes or manual build steps.

> :warning: This script is designed for local development or self-hosted environments where you have direct access to filesystem and MySQL.

---

## :rocket: Features

- Dump your live Shopware 6 database using [`shopware-cli`](https://github.com/shopware/shopware-cli) or `mysqldump` as fallback
- Copy your live project files into a new staging folder
- Clear the staging database (with foreign key support)
- Import the live database dump into staging
- Automatically create a `staging.yaml` configuration file
- Replace `.env.local` with `.env.staging`
- Run `bin/console system:setup:staging` in the staging environment
- Rewrite all sales channel domain URLs to match staging
- Run either full `shopware-cli project ci` or manual build steps (`build-administration`, `build-storefront`, `cache:clear`)
- Text-based progress output with step counter and clear feedback

---

## :book: Requirements

- Either `shopware-cli` or `mysqldump` available in your `PATH`
- Local MySQL access
- Shopware 6 project structure

Install shopware-cli (if not already installed):

```bash
curl -s https://shopware.github.io/shopware-cli/install.sh | bash
```

More info: [https://github.com/shopware/shopware-cli](https://github.com/shopware/shopware-cli)

---

## :pencil: Configuration

Edit the top of the `setup-staging-env.sh` file to match your environment:

```bash
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
```

---

## :wrench: Usage

Clone or download the script from GitHub:

```bash
wget -O setup-staging-env.sh https://raw.githubusercontent.com/Aventux/shopware-staging-tool/main/setup-staging-env.sh && chmod +x setup-staging-env.sh
```

Run the script:
    
```bash
./setup-staging-env.sh
```

The script will walk you through each step and show a progress indicator.

If `shopware-cli` is not available, the script will automatically fall back to `mysqldump` and run the appropriate Shopware build and cache commands manually.

---

## :clap: Contributing

This tool builds upon [`shopware-cli`](https://github.com/shopware/shopware-cli)  
Special thanks to the Shopware team for providing such a powerful developer tool.

If you find bugs or want to contribute enhancements, feel free to open a pull request.

---

![Bash](https://img.shields.io/badge/language-bash-blue.svg)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
![Shopware](https://img.shields.io/badge/shopware-6.x-blue)
