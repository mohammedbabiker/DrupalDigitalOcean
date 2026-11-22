# DRUPAL FULL LIFECYCLE RUNBOOK (DDEV -> GitHub CI/CD -> VPS)
## Domain : https://mohammedworkspace.my.id
## Server : /var/www/drupal (root@vps.mohammedworkspace.my.id)
## Backups: ~/drupal-backups/ (local Mac) | /var/backups/drupal/ (VPS)

### 0. Rules (Read Before Running Anything)

1. **Code & Config flow UP:** Local DDEV -> GitHub (`main`) -> GitHub Actions -> VPS (`release.yaml`).
2. **Content & Media flow DOWN:** Live VPS UI -> Local DDEV (optional sync).
3. **Composer on the VPS is read-only:** NEVER run `composer require` or `composer update` on the server. Only run them locally in DDEV; Ansible runs `composer install` from `composer.lock`.
4. **Uninstalls require 2 pushes:** Push 1 removes the module/theme from Drupal config (`drush cim`). Push 2 deletes the files (`composer remove`).

---

### 1. Local Dev Setup (DDEV) & Daily Branch Workflow

#### 1.1 Start Local Environment & Sync Repo
```bash
# 1. One-Time Local Environment Setup (DDEV)
ddev config --project-type=drupal10 --docroot=. --php-version=8.3 --database=mariadb:10.11
# 2. Start DDEV containers (Nginx, PHP, MariaDB)
ddev start
ddev composer install

# 3. Always branch off an up-to-date main
git switch main
git pull origin main

# 4. Create a clean feature branch
git switch -c feat/my-change

# 5. Take a quick local DB snapshot before risky edits
ddev snapshot --name=before-my-change

# 6. Open local site in browser (or get a one-time admin login link)
ddev launch
ddev drush uli
```

#### 1.2 Make Structural Changes, Export Config & Deploy (Standard Example)
```bash
# 1. Build content types, Views, fields, or blocks in the local Drupal UI
#    (Example: adding a new "Projects" content type)

# 2. Export Drupal configs into ("config/sync") on sites/default/settings.ddev.php "$settings['config_sync_directory'] = 'config/sync';"
ddev drush config:export -y

# 3. Review exactly what changed before committing
git status

# 4. Commit and push -> triggers GitHub Actions -> runs ansible/release.yaml
git add composer.json composer.lock config/sync/ modules/ themes/
git commit -m "feat: add Projects content type and view"
git push -u origin feat/my-change

# 5. Open PR, squash-merge into main, and watch CI/CD deploy live
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

---

### 2. Install a New Module (Example: Pathauto)

```bash
# 1. Start a branch
git switch main && git pull origin main
git switch -c feat/install-pathauto

# 2. Download the module via Composer (updates composer.json + composer.lock)
ddev composer require drupal/pathauto

# 3. Enable the module in Drupal
ddev drush pm:enable pathauto -y

# 4. Configure URL patterns in the UI (Configuration -> Search and metadata -> URL aliases)
ddev launch

# 5. Export config (records pathauto in config/sync/core.extension.yml + settings)
ddev drush config:export -y

# 6. Push & merge -> Ansible runs composer install, then drush config:import
git add composer.json composer.lock config/sync/
git commit -m "feat: install and configure pathauto"
git push -u origin feat/install-pathauto
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

---

### 3. Install & Activate a New Theme (Example: Gin Admin / Olivero Front)

```bash
# 1. Start a branch
git switch main && git pull origin main
git switch -c feat/install-gin-theme

# 2. Download the theme via Composer
ddev composer require drupal/gin

# 3. Enable the theme in Drupal
ddev drush theme:enable gin -y

# 4. Set as admin theme (or use "default" instead of "admin" for front-end theme)
ddev drush config:set system.theme admin gin -y
# ddev drush config:set system.theme default my_custom_theme -y

# 5. Clear cache, inspect locally, and export config
ddev drush cache:rebuild
ddev drush config:export -y

# 6. Push & merge to deploy
git add composer.json composer.lock config/sync/ themes/
git commit -m "feat: enable Gin admin theme"
git push -u origin feat/install-gin-theme
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

---

### 4. Uninstall Modules or Themes Safely (Strict 2-Push Workflow)

> **Why 2 pushes?** Ansible runs `composer install` BEFORE `drush config:import`.
> If you delete the files in the same commit, Drupal cannot run the module's
> database cleanup hooks during `config:import`.

#### Phase 1 — Push 1: Uninstall from Drupal Database (Keep Files for Now)
```bash
# 1. Start a branch and snapshot local DB
git switch main && git pull origin main
git switch -c chore/uninstall-pathauto
ddev snapshot --name=pre-uninstall

# 2. Check exact machine names of enabled non-core modules / themes
ddev drush pm:list --type=module --status=enabled --no-core
ddev drush pm:list --type=theme --status=enabled --no-core

# 3A. If uninstalling a MODULE:
ddev drush pm:uninstall pathauto -y

# 3B. If uninstalling a THEME (switch back to core themes first!):
# ddev drush theme:enable olivero claro -y
# ddev drush config:set system.theme default olivero -y
# ddev drush config:set system.theme admin claro -y
# ddev drush theme:uninstall old_theme_name -y

# 4. Export config ONLY (do NOT run composer remove yet!)
ddev drush config:export -y

# 5. Commit ONLY config/sync/ and deploy Push #1
git add config/sync/
git commit -m "chore: uninstall pathauto in Drupal config (step 1 of 2)"
git push -u origin chore/uninstall-pathauto
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

#### Phase 2 — Push 2: Delete Code Files via Composer
```bash
# 1. Pull main after Push #1 succeeds on the VPS
git switch main && git pull origin main
git switch -c chore/remove-pathauto-code

# 2. Remove package from Composer (or delete custom folder under modules/custom or themes/custom)
ddev composer remove drupal/pathauto

# 3. Commit composer.json + composer.lock and deploy Push #2
git add composer.json composer.lock
git commit -m "chore: remove drupal/pathauto package (step 2 of 2)"
git push -u origin chore/remove-pathauto-code
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

---

### 5. Update Drupal Core, Modules & Database

```bash
# 1. Start a branch and take a local snapshot
git switch main && git pull origin main
git switch -c chore/update-drupal-deps
ddev snapshot --name=pre-update

# 2. Check outdated Drupal packages
ddev composer outdated "drupal/*"

# 3. Update a specific package (or update core + all packages with: ddev composer update -W)
ddev composer update drupal/core-recommended drupal/pathauto -W

# 4. Run Drupal database schema updates locally
ddev drush updatedb -y

# 5. Rebuild cache and export any config schema updates
ddev drush cache:rebuild
ddev drush config:export -y

# 6. Verify site works locally, then push & merge
#    (Ansible automatically runs: composer install -> updb -> cim -> deploy:hook -> cr)
ddev launch
git add composer.json composer.lock config/sync/
git commit -m "chore: update Drupal core and contributed modules"
git push -u origin chore/update-drupal-deps
gh pr create --fill && gh pr merge --squash --delete-branch
gh run watch
```

---

### 6. Delete Content & Clean/Reset Local Site

#### 6.1 Delete Specific Content Locally (Keep Structure & DB)
```bash
# Delete all nodes of a specific content type (e.g., article)
ddev drush entity:delete node --bundle=article

# Delete specific node IDs (e.g., node 12 and 15)
ddev drush entity:delete node 12,15

# Delete all media items of a bundle (e.g., image)
ddev drush entity:delete media --bundle=image

# Rebuild cache
ddev drush cache:rebuild
```

#### 6.2 Strip Site Back to Clean Core (Keep Database & Core Content)
```bash
# 1. Snapshot first
ddev snapshot --name=pre-core-cleanup

# 2. Switch to core themes
ddev drush theme:enable olivero claro -y
ddev drush config:set system.theme default olivero -y
ddev drush config:set system.theme admin claro -y

# 3. List & uninstall all non-core themes and modules
ddev drush pm:list --type=theme --status=enabled --no-core
ddev drush theme:uninstall theme_1 theme_2 -y

ddev drush pm:list --type=module --status=enabled --no-core
ddev drush pm:uninstall module_1 module_2 -y

# 4. Remove packages with Composer & rebuild cache
ddev composer remove drupal/module_1 drupal/theme_1
ddev drush cache:rebuild
```

#### 6.3 Total Wipe: Brand-New Empty Local Database
```bash
# WARNING: Destroys all local content and DB tables
ddev drush site:install standard -y --account-name=admin --account-pass=admin

# Or roll back to any previous snapshot at any time:
ddev snapshot --list
ddev snapshot restore pre-core-cleanup
```

---

### 7. Add Live Content on Production

1. Log in at: `https://mohammedworkspace.my.id/user/login`
2. Publish real posts, pages, and media uploads directly in the production UI.
3. Never edit content types, Views, or module settings on production—always do structural work in DDEV (Section 1).

---

### 8. Sync Live Production Content Down to Local DDEV (Optional)

```bash
# Run whenever you want real production posts & uploaded images inside DDEV

# 1. Dump and download the live database
ssh root@vps.mohammedworkspace.my.id \
  "sudo -u www-data HOME=/tmp /var/www/drupal/vendor/bin/drush --root=/var/www/drupal sql:dump | gzip" \
  > /tmp/prod.sql.gz

# 2. Import into local DDEV and remove temp dump
ddev import-db --file=/tmp/prod.sql.gz && rm -f /tmp/prod.sql.gz

# 3. Sync uploaded media files (sites/default/files/)
rsync -avz --delete \
  root@vps.mohammedworkspace.my.id:/var/www/drupal/sites/default/files/ \
  sites/default/files/

# 4. Rebuild local cache
ddev drush cache:rebuild
```

---

### 9. Fresh Start / Rebuild Server on a New VPS (Terraform + Ansible + Auto-Restore)

```bash
# 1. Provision a brand-new DigitalOcean Droplet + DNS
cd terraform
terraform init
terraform apply

# 2. Configure full LEMP + Drupal stack & auto-restore DB + media from ~/drupal-backups/
cd ../ansible
ansible-playbook setup.yaml # certbot role may need to work alone!

# 3. Run ONLY if new code/config commits landed on main while the Droplet was offline
ansible-playbook release.yaml -e "github_repo_url=<YOUR_DRUPAL_REPO_URL>"

# 4. Verify live site & health
ssh root@vps.mohammedworkspace.my.id \
  "sudo -u www-data HOME=/tmp /var/www/drupal/vendor/bin/drush --root=/var/www/drupal status"
```

---

### 10. Backup to Mac & Hibernate VPS ($0/mo)

```bash
# 1. Encrypt & download live production DB + media files to ~/drupal-backups/
cd ansible
ansible-playbook backup.yaml

# 2. Verify backup files exist on your Mac before destroying the server!
ls -lh ~/drupal-backups/

# 3. Destroy DigitalOcean Droplet to stop hourly/monthly billing
cd ../terraform
terraform destroy
```

---

### 11. Quick VPS Troubleshooting & Rollback

#### 11.1 Fix Ansible Error: `Local modifications exist in /var/www/drupal (force=no)`
```bash
# SSH into VPS and inspect what drifted
ssh root@vps.mohammedworkspace.my.id
cd /var/www/drupal
git status
git diff --summary

# Fix A: Ignore file permission-only changes (from chmod/chown tasks)
git config core.fileMode false

# Fix B: Discard accidental server-side changes to composer.json / composer.lock
git checkout -- composer.json composer.lock

# Confirm working tree is clean, then re-run CI/CD deploy
git status
```

#### 11.2 Check Live Logs & Emergency Pre-Release DB Rollback
```bash
# View recent Drupal PHP/site errors on the VPS
ssh root@vps.mohammedworkspace.my.id \
  "sudo -u www-data HOME=/tmp /var/www/drupal/vendor/bin/drush --root=/var/www/drupal watchdog:show --severity=Error"

# List automatic pre-deploy backups created by release.yaml
ssh root@vps.mohammedworkspace.my.id "ls -lh /var/backups/drupal/"

# Restore a pre-deploy backup if a release ever goes wrong
ssh root@vps.mohammedworkspace.my.id \
  "gunzip -c /var/backups/drupal/pre-release-YYYYMMDD-HHMMSS.sql.gz | sudo -u www-data HOME=/tmp /var/www/drupal/vendor/bin/drush --root=/var/www/drupal sql:cli && sudo -u www-data HOME=/tmp /var/www/drupal/vendor/bin/drush --root=/var/www/drupal cache:rebuild"
```