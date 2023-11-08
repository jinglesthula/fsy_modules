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

	function updateData(
		event,
		rc,
		prc
	) {
		local.file = FileOpen("#ExpandPath("/o3/scratch")#/fsy_prereg.json", "write")

		local.dao = getModel("dao@ds")
		local.json = {
			"counts" = {
				"started" = local.dao.countStarted().started,
				"linked" = local.dao.countLinked().linked,
				"joined" = local.dao.countJoined().joined,
				"prefs" = local.dao.countSession().session,
				"completed" = local.dao.countCompleted().completed,
				"withdrawn" = local.dao.countWithdrawn().withdrawn,
				"selfServeStart" = local.dao.countSelfServeStart().selfServeStart,
				"assistedStart" = local.dao.countAssistedStart().assistedStart,
				"selfServeCompleted" = local.dao.countSelfServeCompleted().selfServeCompleted,
				"assistedCompleted" = local.dao.countAssistedCompleted().assistedCompleted
			},
			"overTime" = local.dao.dataOverTime()
		}

		local.json.counts[ "parentStart" ] = local.json.counts.started - local.json.counts.selfServeStart - local.json.counts.assistedStart
		local.json.counts[ "parentCompleted" ] = local.json.counts.completed - local.json.counts.selfServeCompleted - local.json.counts.assistedCompleted

		try {
			FileWrite(local.file, SerializeJSON(local.json))
		} finally {
			FileClose(local.file);
		}

		event.noRender()
	}

	function updateSchedulerData(
		event,
		rc,
		prc
	) {
		local.file = FileOpen("#ExpandPath("/o3/scratch")#/fsy_prereg_scheduler.json", "write")

		local.dao = getModel("dao@ds")
		local.data = local.dao.schedulerData();

		try {
			FileWrite(local.file, SerializeJSON(local.data))
		} finally {
			FileClose(local.file);
		}

		event.noRender()
	}

	function corsTest(
		event,
		rc,
		prc
	) {
		arguments.event.renderData(type = "JSON", data = { hello = "world" });
	}

}
