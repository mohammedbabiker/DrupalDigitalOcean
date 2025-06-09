# Install the site with composer

##  Clone The Repo
```bash
  git clone git@github.com:mohammedbabiker/DrupalDigitalOcean.git drupal && cd drupal
```

## Install composer

```bash
  apt-get update && apt-get install composer -y
```

```bash
  composer install
```


## Export Database

```bash
  export PATH="/var/www/drupal/vendor/bin:$PATH"
```

```bash
  drush sql-dump --gzip --result-file=db/data.sql
```
- [success] Database dump saved to db/data.sql.gz

```bash
  zip -e db/data.zip db/data.sql.gz
```
- adding: db/data.sql.gz (deflated 2%)

## Import Database

```bash
  unzip -o db/data.zip db/data.sql.gz
```

```bash
  gzip -d db/data.sql.gz
```
### Create an empty database

```sql
  create database drupaldb;
  create user drupaluser@localhost identified by 'drupaluser@';
  grant all privileges on drupaldb.* to drupaluser@localhost identified by 'drupaluser@';
  flush privileges;
  ```

Then import the extracted database into it:

```bash
  mysql -u root -p drupaldb < db/data.sql
```

And insde mysql:

```sql
  use drupaldb;
  source /var/www/drupal/db/data.sql
```

**If not:**

```bash
  chown -R www-data:www-data /var/www/drupal
  chown -R root:root /var/www/drupal
```

### Import config files by editting `settings.php` and update sync file

cd into *sites/default/* & cp default.settings.php settings.php

search for config_sync on settings.php and update the path to *config/sync*

## Import Config file

```bash
  drush cim
```
