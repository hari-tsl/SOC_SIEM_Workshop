<?php
# DVWA Configuration for SOC SIEM Lab

$DBMS = 'MySQL';

if (function_exists('mysqli_report')) {
    mysqli_report(MYSQLI_REPORT_OFF);
}

define ('MYSQL', 'mysql');
define ('SQLITE', 'sqlite');

$_DVWA = array();
$_DVWA[ 'db_server' ]   = '127.0.0.1';
$_DVWA[ 'db_database' ] = 'dvwa';
$_DVWA[ 'db_user' ]     = 'dvwa';
$_DVWA[ 'db_password' ] = 'dvwa';
$_DVWA[ 'db_port' ]     = '3306';

# Database management system to use: 'MySQL' or 'sqlite'
$_DVWA[ 'DBMS' ]        = 'MySQL';
$_DVWA[ 'db_type' ]     = 'mysql';
$_DVWA[ 'SQLI_DB' ]     = MYSQL;
$_DVWA[ 'SQLITE_DB' ]   = 'sqli.db';

# Default security level for training: low
$_DVWA[ 'default_security_level' ] = 'low';

# Default locale
$_DVWA[ 'default_locale' ] = 'en';

# Disable authentication
$_DVWA[ 'disable_authentication' ] = false;

# Default PHPIDS settings
$_DVWA[ 'default_php_ids_level' ] = 'disabled';
$_DVWA[ 'default_php_ids_verbose' ] = 'false';

# ReCAPTCHA settings (disabled for local training)
$_DVWA[ 'recaptcha_public_key' ]  = '';
$_DVWA[ 'recaptcha_private_key' ] = '';
?>
