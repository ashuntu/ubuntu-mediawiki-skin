/**
 * Theme toggle button - cycles through os → night → day → os.
 *
 * @param {Record<string,import('../skins.ubuntu.clientPreferences/clientPreferences.js').ClientPreference>} config
 * @param {import('../skins.ubuntu.clientPreferences/clientPreferences.js').UserPreferencesApi} userPreferences
 */
function init( config, userPreferences ) {
	const toggleButton = document.querySelector( '.theme-toggle' );
	if ( !toggleButton ) {
		return;
	}
	// Const alias with the nullability narrowed away, so closures capture a non-null type (TS 4.9).
	const button = /** @type {Element} */ ( toggleButton );

	const featureName = 'skin-theme';
	const cycle = [ 'day', 'night', 'os' ];
	const clientPreferences = require( /** @type {string} */ ( 'skins.ubuntu.clientPreferences' ) );

	// Maps each theme value to the message key describing the *next* theme in the cycle.
	const nextThemeMessageKey = /** @type {Record<string, string>} */ ( {
		day: 'skin-theme-toggle-switch-to-night',
		night: 'skin-theme-toggle-switch-to-os',
		os: 'skin-theme-toggle-switch-to-day'
	} );

	/**
	 * @param {string} currentValue
	 */
	function updateAriaLabel( currentValue ) {
		const msgKey = nextThemeMessageKey[ currentValue ] || 'skin-theme-toggle-label';
		const msg = mw.msg( msgKey );
		button.setAttribute( 'aria-label', msg );
		button.setAttribute( 'title', msg );
	}

	updateAriaLabel( String( mw.user.clientPrefs.get( featureName ) ) );

	button.addEventListener( 'click', () => {
		const current = String( mw.user.clientPrefs.get( featureName ) );
		const currentIndex = cycle.indexOf( current );
		const nextValue = cycle[ ( currentIndex + 1 ) % cycle.length ];
		clientPreferences.toggleDocClassAndSave( featureName, nextValue, config, userPreferences );
		updateAriaLabel( nextValue );
	} );
}

module.exports = { init };
