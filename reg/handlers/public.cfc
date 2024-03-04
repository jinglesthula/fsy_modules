component extends="coldbox.system.EventHandler" {

	/**
	 * Default Action
	 */
	function index(
		event,
		rc,
		prc
	) {
		prc.message = "Hello From ColdBox";
	}

	function progressDrawer() {

	}

}
