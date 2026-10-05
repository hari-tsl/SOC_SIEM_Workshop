<?php
# DVWA Configuration for SOC SIEM Lab

$_DVWA = array();
$_DVWA[ 'db_server' ]   = '127.0.0.1';
$_DVWA[ 'db_database' ] = 'dvwa';
$_DVWA[ 'db_user' ]     = 'dvwa';
$_DVWA[ 'db_password' ] = 'dvwa';
$_DVWA[ 'db_port' ]     = '3306';

# Default security level for training: low
$_DVWA[ 'default_security_level' ] = 'low';

# Default PHPIDS settings
$_DVWA[ 'default_php_ids_level' ] = 'disabled';
$_DVWA[ 'default_php_ids_verbose' ] = 'false';

# ReCAPTCHA settings (disabled for local training)
$_DVWA[ 'recaptcha_public_key' ]  = '';
$_DVWA[ 'recaptcha_private_key' ] = '';
?>
