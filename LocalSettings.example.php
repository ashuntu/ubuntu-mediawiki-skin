<?php
# See https://www.mediawiki.org/wiki/Manual:Configuration_settings

if (!defined('MEDIAWIKI')) {
    exit;
}

# Site
$wgSitename = "Ubuntu Wiki";
$wgServer = "http://localhost:" . (getenv('UBUNTU_SKIN_PORT') ?: '8081');
$wgScriptPath = "";
$wgResourceBasePath = $wgScriptPath;
$wgLanguageCode = "en";
$wgLocaltimezone = "UTC";

# Database (matches docker-compose.yml defaults)
$wgDBtype = "mysql";
$wgDBserver = "db";
$wgDBname = "mediawiki";
$wgDBuser = "mediawiki";
$wgDBpassword = "mediawiki";

# Keys — replace with unique values for any non-local deployment
$wgSecretKey = "change-me";
$wgUpgradeKey = "change-me";

# Uploads
$wgEnableUploads = false;
$wgUseInstantCommons = true;

# Skin
# The UbuntuWiki extension is required by the Ubuntu skin. It provides shared
# styles, webfonts, the cookie consent banner, footer links, and code block
# enhancements. See https://github.com/ubuntu/ubuntu-mediawiki-extension
wfLoadExtension('UbuntuWiki');
wfLoadSkin('Ubuntu');
$wgDefaultSkin = 'ubuntu';

# Logo — uses the Ubuntu logo shipped by the UbuntuWiki extension.
# Replace with your own image path to use a custom logo.
$wgLogos = [
    '1x'   => "$wgResourceBasePath/extensions/UbuntuWiki/resources/images/Tag-CoF-Orange-Digital.svg",
    'icon' => "$wgResourceBasePath/extensions/UbuntuWiki/resources/images/Tag-CoF-Orange-Digital.svg",
];

unset($wgFooterIcons['poweredby']);

# Cookie consent & Google Tag Manager
# Enable the Canonical cookie policy consent banner (provided by the UbuntuWiki
# extension, which also adds a "Manage your tracker settings" footer link).
$wgUbuntuCookieConsentEnabled = true;

# Google Tag Manager container ID (leave empty to disable). The extension
# injects the GTM snippets itself; when the consent banner is enabled, gtag
# consent defaults are set to denied inline ahead of GTM, so consent is
# established before GTM initialises.
$wgUbuntuGTMContainerID = '';

# Extensions
wfLoadExtension('WikiEditor');
wfLoadExtension('VisualEditor');
wfLoadExtension('SyntaxHighlight_GeSHi');

$wgDefaultUserOptions['visualeditor-newwikitext'] = 1;
$wgHiddenPrefs[] = 'visualeditor-newwikitext';

# Debug (disable in production)
$wgShowExceptionDetails = true;
