# Install the site with composer

``` bash
git clone git@github.com:mohammedbabiker/DrupalDigitalOcean.git drupal && cd drupal
```

``` bash
composer install
```

### Change ` setting.php ` in order to import config files
> on setting.php serch for config_sync
> and uncomment the line and change sync path to `config/sync`

### Import Database



### Import Config file

``` bash
drush cim
```
