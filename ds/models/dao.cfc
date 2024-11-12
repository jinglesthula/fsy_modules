component threadSafe extends="o3.internal.cfc.model" {
	property name="injector" inject="wirebox";

	variables.dsn = { prod = "fsyweb_pro", dev = "fsyweb_dev", local = "fsyweb_local" };

	variables.dsn.scheduler = variables.dsn.local
	variables.dsn.prereg = variables.dsn.prod
	variables.realProgram = 80001114
	variables.trainingProgram = structKeyExists(application, "trainingProgram") ? application.trainingProgram : 80061378
	variables.ticket = "FSY-2883"
	variables.ticketName = reReplace(variables.ticket, "-", "_", "all")
	variables.existingTrainingSectionCN = queryExecute("
		-- get the earliest non-core training session
		select TOP 1 pm_session_id
		from pm_session
			inner join pm_location on pm_location = pm_location_id
			inner join product on product = product_id
		where program = :program
			and session_type = 'FSY Training'
		order by pm_session.start_date
	", { program = variables.trainingProgram }, { datasource: variables.dsn.local }).pm_session_id;
	variables.sessions = {
		ab_calgary_01 = 10001637,
		ab_calgary_02 = 10001655,
		ab_calgary_03 = 10001668,
		ak_anchorage_01 = 10001607,
		az_flagstaff_03 = 10001716,
		az_flagstaff_04A = 10001722,
		az_prescott_01 = 10001811,
		az_prescott_02 = 10001812,
		az_tempe_01 = 10001671,
		az_thatcher_03 = 10001609,
		az_thatcher_05 = 10001627,
		az_thatcher_06 = 10001638, // 6/29
		az_tucson_02_es = 10001670,
		ca_rohnert_park_01 = 10001610,
		ca_rohnert_park_02 = 10001618,
		co_colorado_springs_01 = 10001602,
		co_colorado_springs_02 = 10001612,
		co_colorado_springs_03 = 10001620,
		co_fort_collins_01 = 10001603,
		co_fort_collins_02 = 10001613,
		fl_deland_01 = 10001833,
		id_caldwell_01 = 10001858,
		ma_amherst_01 = 10001640,
		mn_st_joseph = 10001650, // 7/6
		mt_billings = 10001829,
		or_monmouth_02 = 10001776,
		tx_denton_01 = 10001813,
		tx_denton_02 = 10001815,
		tx_san_antonio_01 = 10001643,
		ut_cedar_city_01 = 10001781,
		ut_cedar_city_02 = 10001784,
		ut_ephraim_01A = 10001757,
		ut_ephraim_03B = 10001762,
		ut_logan_01 = 10001783,
		ut_logan_02 = 10001788,
		ut_orem_01 = 80001990,
		ut_orem_02 = 10001836,
		ut_provo_01A = 10001685, // 5/25
		ut_provo_02A = 10001688, // 6/1
		ut_provo_03A = 10001694, // 6/8
		ut_provo_04A = 10001738, // 6/15
		ut_provo_05A = 10001741, // 6/22
		ut_provo_06A = 10001707,
		ut_provo_08A = 10001717, // 7/13
		ut_provo_01B = 10001686,
		ut_provo_02B = 10001689,
		ut_provo_03B = 10001695,
		ut_provo_05B = 10001742,
		ut_provo_06B = 10001708,
		ut_provo_02C = 10001690,
		ut_provo_06C = 10001709,
		ut_st_george_02 = 10001606,
		va_buena_vista_01 = 10001790,
		va_buena_vista_02 = 10001793,
		vt_castleton = 10001866,
		wa_seattle_01 = 10001795,
		wa_tacoma_01 = 10001835,
		core = 10052040,
		cn_0A = 10052041
	};

	public query function countStarted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as started from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countLinked() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as linked
			from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
				and context.status = 'Active'
				and prereg_link is not null
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countJoined() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as joined
			from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
				and context.status = 'Active'
				and prereg_link is not null
				and prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countSession() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(context_id) as session
			from (
				select context_id
				from FSY.DBO.context
					inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.program = @program
				where product = @program
					and context_type = 'Enrollment'
				group by context_id
			) data
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countCompleted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as completed from FSY.DBO.event where event_type = 'preRegReceived'
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countWithdrawn() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as withdrawn from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
				and context.status = 'Canceled'
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countSelfServeStart() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as selfServeStart
			from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
				and person = left(created_by, 8)
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countAssistedStart() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as assistedStart
			from context
				inner join person on person.person_id = left(context.created_by, 8)
				inner join pers_job pj on pj.person = person.person_id
			where context_id in (
				select context_id
				from FSY.DBO.context
				where product = @program
					and context_type = 'Enrollment'
					and person <> left(created_by, 8)
			)
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countSelfServeCompleted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as selfServeCompleted
			from FSY.DBO.context
				inner join terms_acceptance ta on ta.person = context.person
					and ta.program = context.product
					and left(ta.created_by, 8) = cast(context.person as nvarchar)
			where product = @program
				and context_type = 'Enrollment'
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public query function countAssistedCompleted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as assistedCompleted
			from context
				inner join terms_acceptance ta on ta.person = context.person
					and ta.program = context.product
				inner join person on cast(person.person_id as nvarchar) = left(ta.created_by, 8)
				inner join pers_job pj on pj.person = person.person_id
			where context_id in (
				select context_id
				from FSY.DBO.context
				where product = @program
					and context_type = 'Enrollment'
					and person <> left(created_by, 8)
			)
		",
			{},
			{ datasource: variables.dsn.prereg }
		);
	}

	public struct function dataOverTime() {
		local.range = QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			SELECT prereg_start, sysdatetime() as now from product where product_id = @program
		",
			{},
			{ datasource: variables.dsn.prereg }
		)

		local.start = local.range.prereg_start
		local.end = local.range.now
		local.increment = application.preregIncrement
		local.slices = Ceiling(local.end.diff("h", local.start) / local.increment)

		local.json = { "labels" = [], "starts" = [], "completions" = [], "assistedStarts" = [], "selfServeStarts" = [], "parentStarts" = [] }

		for (i = 0; i < local.slices; i++) {
			local.sliceStart = local.start.add("h", i * local.increment)
			local.sliceEnd = local.start.add("h", i * local.increment + local.increment)
			local.json.labels.append(DateTimeFormat(local.sliceStart, "m/d H:nn"))

			// starts
			local.slice = QueryExecute(
				"
				declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

				select count(*) as total
				from FSY.DBO.context
				where product = @program
					and context_type = 'Enrollment'
					and context.created >= :start
					and context.created < :end
			",
				{ start = { value = local.sliceStart, cfsqltype = "timestamp" }, end = { value = local.sliceEnd, cfsqltype = "timestamp" } },
				{ datasource: variables.dsn.prereg }
			);

			local.json.starts.append(local.slice.total)

			// completions
			local.slice = QueryExecute(
				"
				declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

				select count(*) as total
				from FSY.DBO.event where event_type = 'preRegReceived'
					and event.occurred >= :start
					and event.occurred < :end
			",
				{ start = { value = local.sliceStart, cfsqltype = "timestamp" }, end = { value = local.sliceEnd, cfsqltype = "timestamp" } },
				{ datasource: variables.dsn.prereg }
			);

			local.json.completions.append(local.slice.total)

			// assisted starts
			local.slice = QueryExecute(
				"
				declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

				select count(*) as total
				from context
					inner join person on person.person_id = left(context.created_by, 8)
					inner join pers_job pj on pj.person = person.person_id
				where context_id in (
					select context_id
					from FSY.DBO.context
					where product = @program
						and context_type = 'Enrollment'
						and person <> left(created_by, 8)
						and context.created >= :start
						and context.created < :end
				)
			",
				{ start = { value = local.sliceStart, cfsqltype = "timestamp" }, end = { value = local.sliceEnd, cfsqltype = "timestamp" } },
				{ datasource: variables.dsn.prereg }
			);

			local.json.assistedStarts.append(local.slice.total)

			// self-serve starts
			local.slice = QueryExecute(
				"
				declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

				select count(*) as total
				from FSY.DBO.context
				where product = @program
					and context_type = 'Enrollment'
					and person = left(created_by, 8)
					and context.created >= :start
					and context.created < :end
			",
				{ start = { value = local.sliceStart, cfsqltype = "timestamp" }, end = { value = local.sliceEnd, cfsqltype = "timestamp" } },
				{ datasource: variables.dsn.prereg }
			);

			local.json.selfServeStarts.append(local.slice.total)
			local.json.parentStarts.append(
				local.json.starts[ local.json.starts.len() ] - local.json.assistedStarts[ local.json.assistedStarts.len() ] - local.json.selfServeStarts[
					local.json.selfServeStarts.len()
				]
			)
		}

		return local.json
	}

	public struct function schedulerData() {
		// Basic overview

		local.preferenceBreakdown = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program) as total_sp_records,
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program and priority = 1) as p_1,
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program and priority = 2) as p_2,
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program and priority = 3) as p_3,
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program and priority = 4) as p_4,
			(select count(*) from FSY.DBO.session_preference sp where sp.program = @program and priority = 5) as p_5
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.linkStats = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select
				count(*) as link_preference_size_count, link_preference_size
			from (
				select count(*) link_preference_size
				from Session_Preference sp
				where sp.program = @program
				group by sp.prereg_link
			) data
			group by link_preference_size
			order by link_preference_size
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.linkMemberStats = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select
				count(link_member_count) as link_member_count_number, link_member_count
			from (
				select count(*) link_member_count
				from context
				where context.product = @program
					and context.context_type = 'Enrollment'
					and context.status <> 'Canceled'
				group by context.prereg_link
			) data
			group by link_member_count
			order by link_member_count
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.basicCounts = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many people preregistered
			-- how many links were there
			-- how many linked were there
			-- how many singles were there
			select (
					select count(*) from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
					inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
					where context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program
			) as preregistered, (
					select count(distinct sp.prereg_link) from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
					inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
					where context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program and sp.prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
			) as link_count, (
					select count(*) from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
					inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
					where context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program and sp.prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
			) as linked, (
					select count(*) from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
					inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
					where context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program and sp.prereg_link like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
			) as singles
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		// What went right

		local.timedStats = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many assignments were made per/minute (average) +
			-- how many people got assigned +
			-- how many assignments were made per/min average +
			-- how long did the scheduler run +

			declare @minutes float = (cast((
				select cast(datediff(second, min(context.created), max(context.created)) as float) / 60.0 from FSY.DBO.context
					inner join product on product.product_id = context.product and product.master_type = 'Section'
				where product.program = @program
					and context_type = 'Enrollment'
					and context.status <> 'Canceled'
				) as float))

			select
			round(
				cast((select count(context_id) from FSY.DBO.context
					inner join product on product.product_id = context.product and product.master_type = 'Section'
				where product.program = @program
					and context_type = 'Enrollment'
					and context.status <> 'Canceled'
				) as float) /
				case when @minutes = 0 then 1 else @minutes end, 2
			) as average_assignments_per_minute,
			(
			select count(context_id) as assigned from FSY.DBO.context inner join product on product.product_id = context.product and product.master_type = 'Section'
			where product.program = @program and context_type = 'Enrollment' and context.status <> 'Canceled'
			) as total_assigned,
			(
			select round(cast(datediff(second, min(context.created), max(context.created)) as float) / 60.0, 2) from FSY.DBO.context
				inner join product on product.product_id = context.product and product.master_type = 'Section'
			where product.program = @program
				and context_type = 'Enrollment'
				and context.status <> 'Canceled'
			) as scheduler_duration_minutes
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.preregUnassigned = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many people who pre-registered didn't get assigned
			select count(context.context_id) as preregistered_unassigned from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
			inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
			left join (
					context section inner join product product_s on product_s.product_id = section.product and product_s.program = @program and product_s.master_type = 'Section'
			) on section.person = context.person and section.context_type = 'Enrollment' and section.status <> 'Canceled'
			where context.context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program and section.context_id is null
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.assignedByChoice = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many got their 1st choice (2nd, 3rd, etc.)
			select
			(
					select count(context.context_id) from context inner join product on product_id = product and product.master_type = 'Section' inner join context context_p on context_p.person = context.person and context_p.product = product.program
					inner join session_preference sp on sp.prereg_link = context_p.prereg_link and sp.program = product.program and sp.priority = 1
					inner join pm_session on pm_session.product = context.product
					where product.program = @program and cast(pm_session.participant_start_date as date) = sp.start_date and pm_session.pm_location = sp.pm_location and context.context_type = 'Enrollment' and context.status <> 'Canceled'
			) as got_1,
			(
					select count(context.context_id) from context inner join product on product_id = product and product.master_type = 'Section' inner join context context_p on context_p.person = context.person and context_p.product = product.program
					inner join session_preference sp on sp.prereg_link = context_p.prereg_link and sp.program = product.program and sp.priority = 2
					inner join pm_session on pm_session.product = context.product
					where product.program = @program and cast(pm_session.participant_start_date as date) = sp.start_date and pm_session.pm_location = sp.pm_location and context.context_type = 'Enrollment' and context.status <> 'Canceled'
			) as got_2,
			(
					select count(context.context_id) from context inner join product on product_id = product and product.master_type = 'Section' inner join context context_p on context_p.person = context.person and context_p.product = product.program
					inner join session_preference sp on sp.prereg_link = context_p.prereg_link and sp.program = product.program and sp.priority = 3
					inner join pm_session on pm_session.product = context.product
					where product.program = @program and cast(pm_session.participant_start_date as date) = sp.start_date and pm_session.pm_location = sp.pm_location and context.context_type = 'Enrollment' and context.status <> 'Canceled'
			) as got_3,
			(
					select count(context.context_id) from context inner join product on product_id = product and product.master_type = 'Section' inner join context context_p on context_p.person = context.person and context_p.product = product.program
					inner join session_preference sp on sp.prereg_link = context_p.prereg_link and sp.program = product.program and sp.priority = 4
					inner join pm_session on pm_session.product = context.product
					where product.program = @program and cast(pm_session.participant_start_date as date) = sp.start_date and pm_session.pm_location = sp.pm_location and context.context_type = 'Enrollment' and context.status <> 'Canceled'
			) as got_4,
			(
					select count(context.context_id) from context inner join product on product_id = product and product.master_type = 'Section' inner join context context_p on context_p.person = context.person and context_p.product = product.program
					inner join session_preference sp on sp.prereg_link = context_p.prereg_link and sp.program = product.program and sp.priority = 5
					inner join pm_session on pm_session.product = context.product
					where product.program = @program and cast(pm_session.participant_start_date as date) = sp.start_date and pm_session.pm_location = sp.pm_location and context.context_type = 'Enrollment' and context.status <> 'Canceled'
			) as got_5
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.fullSessions = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- which sessions got filled up
			select *, case when (max_enroll_f - enrolled_f = 0) and (max_enroll_m - enrolled_m = 0) then 1 else 0 end as full_session
			from (
			select
					section.title,
					option_f.max_enroll as max_enroll_f,
					option_m.max_enroll as max_enroll_m,
					(
							select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
							and product.product_id = option_f.product_id
					) as enrolled_f,
					(
							select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
							and product.product_id = option_m.product_id
					) as enrolled_m
			from FSY.DBO.product section
			inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
			inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
			where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
			) data
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.fullSessionCount = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many sessions got filled up
			select sum(full_session) as num_full_sessions
			from (
					select *, case when (max_enroll_f - enrolled_f = 0) and (max_enroll_m - enrolled_m = 0) then 1 else 0 end as full_session
					from (
					select
							section.title,
							option_f.max_enroll as max_enroll_f,
							option_m.max_enroll as max_enroll_m,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_f.product_id
							) as enrolled_f,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_m.product_id
							) as enrolled_m
					from FSY.DBO.product section
					inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
					inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
					where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
					) data
			) data2
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.fullPlaceTimes = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- which place/times got filled up
			select pm_location, start_date, count(pm_session_id) as sessions_at_place_time, sum(full_session) as full_sessions
			from (
					select *, case when (max_enroll_f - enrolled_f = 0) and (max_enroll_m - enrolled_m = 0) then 1 else 0 end as full_session
					from (
					select
							pm_session_id,
							pm_session.pm_location,
							cast(pm_session.participant_start_date as date) as start_date,
							option_f.max_enroll as max_enroll_f,
							option_m.max_enroll as max_enroll_m,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_f.product_id
							) as enrolled_f,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_m.product_id
							) as enrolled_m
					from FSY.DBO.product section
					inner join pm_session ON pm_session.product = section.product_id
					inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
					inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
					where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
					) data
			) data2
			group by pm_location, start_date
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.fullPlaceTimesCounts = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many place/times got filled up vs still have space
			select
					sum(case when sessions_at_place_time - full_sessions = 0 then 1 else 0 end) as full_place_times,
					sum(case when sessions_at_place_time - full_sessions > 0 then 1 else 0 end) as place_times_with_space
			from (
					select pm_location, start_date, count(pm_session_id) as sessions_at_place_time, sum(full_session) as full_sessions
					from (
							select *, case when (max_enroll_f - enrolled_f = 0) and (max_enroll_m - enrolled_m = 0) then 1 else 0 end as full_session
							from (
							select
									pm_session_id,
									pm_session.pm_location,
									cast(pm_session.participant_start_date as date) as start_date,
									option_f.max_enroll as max_enroll_f,
									option_m.max_enroll as max_enroll_m,
									(
											select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
											and product.product_id = option_f.product_id
									) as enrolled_f,
									(
											select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
											and product.product_id = option_m.product_id
									) as enrolled_m
							from FSY.DBO.product section
							inner join pm_session ON pm_session.product = section.product_id
							inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
							inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
							where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
							) data
					) data2
					group by pm_location, start_date
			) data3
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.singleGenderFull = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- which sessions have one gender full but not the other
			select
					*,
					case when max_enroll_f - enrolled_f = 0 then 1 else 0 end as full_f,
					case when max_enroll_m - enrolled_m = 0 then 1 else 0 end as full_m,
					case when (
							(max_enroll_f - enrolled_f > 0 and max_enroll_m - enrolled_m = 0)
							or (max_enroll_f - enrolled_f = 0 and max_enroll_m - enrolled_m > 0)
					) then 1 else 0 end as single_gender_full
			from (
			select
					section.title,
					option_f.max_enroll as max_enroll_f,
					option_m.max_enroll as max_enroll_m,
					(
							select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
							and product.product_id = option_f.product_id
					) as enrolled_f,
					(
							select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
							and product.product_id = option_m.product_id
					) as enrolled_m
			from FSY.DBO.product section
			inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
			inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
			where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
			) data
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.singleGenderFullCount = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many sessions have one gender full but not the other
			select sum(single_gender_full) as single_gender_full
			from (
					select
							*,
							case when max_enroll_f - enrolled_f = 0 then 1 else 0 end as full_f,
							case when max_enroll_m - enrolled_m = 0 then 1 else 0 end as full_m,
							case when (
									(max_enroll_f - enrolled_f > 0 and max_enroll_m - enrolled_m = 0)
									or (max_enroll_f - enrolled_f = 0 and max_enroll_m - enrolled_m > 0)
							) then 1 else 0 end as single_gender_full
					from (
					select
							section.title,
							option_f.max_enroll as max_enroll_f,
							option_m.max_enroll as max_enroll_m,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Female' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_f.product_id
							) as enrolled_f,
							(
									select count(context.context_id) from context inner join product on product.product_id = context.product and product.housing_type = 'Male' and context.context_type = 'Enrollment' and context.status <> 'Canceled'
									and product.product_id = option_m.product_id
							) as enrolled_m
					from FSY.DBO.product section
					inner join option_item oi_f ON oi_f.section = section.product_id inner join product option_f on option_f.product_id = oi_f.item and option_f.housing_type = 'Female'
					inner join option_item oi_m ON oi_m.section = section.product_id inner join product option_m on option_m.product_id = oi_m.item and option_m.housing_type = 'Male'
					where section.program = @program and section.master_type = 'Section' and section.status <> 'Canceled'
					) data
			) data2
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.linksPlacedCounts = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many link groups (not my's) were placed vs not placed vs partially placed
			/* */
			select
				isNull(sum(placed), 0) as placed,
				isNull(sum(unplaced), 0) as unplaced,
				isNull(sum(partially_placed), 0) as partially_placed
			from (
			/* */
			select
					prereg_link,
					sum(case when group_size = group_placed then 1 else 0 end) as placed,
					sum(case when group_placed = 0 then 1 else 0 end) as unplaced,
					sum(case when group_size <> group_placed and group_placed > 0 then 1 else 0 end) as partially_placed
			from (
					select
									context.prereg_link,
									count(context.prereg_link) as group_size,
									count(section.context_id) as group_placed
							from FSY.DBO.context
									inner join event on event.event_object = 'context' and event.event_object_id = context.context_id and event.event_type = 'preRegReceived'
									inner join session_preference sp_1 on sp_1.prereg_link = context.prereg_link and sp_1.priority = 1 -- not used other than to make sure they had at least one
									left join (
											session_preference sp
											inner join pm_session ps on ps.pm_location = sp.pm_location and cast(ps.PARTICIPANT_START_DATE as date) = sp.start_date
											inner join context section on section.product = ps.product and section.status <> 'Canceled' and section.context_type = 'Enrollment'
									) on sp.prereg_link = context.prereg_link and section.person = context.person
							where context.product = @program
									and context.context_type = 'Enrollment'
									and context.status <> 'Canceled'
									and context.prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							group by context.prereg_link
			) data
			group by prereg_link
			/* */
			) data2
			/* */
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.assignedByGenderCounts = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many males were placed, how many females
			select
					sum(case when person.gender = 'F' then 1 else 0 end) as placed_f,
					sum(case when person.gender = 'M' then 1 else 0 end) as placed_m,
					count(section.context_id) as placed_total
			from FSY.DBO.context
					inner join person on person.person_id = context.person
					inner join event on event.event_object = 'context' and event.event_object_id = context.context_id and event.event_type = 'preRegReceived'
					inner join session_preference sp on sp.prereg_link = context.prereg_link
					inner join pm_session ps on ps.pm_location = sp.pm_location and cast(ps.PARTICIPANT_START_DATE as date) = sp.start_date
					inner join context section on section.product = ps.product and section.status <> 'Canceled' and section.context_type = 'Enrollment' and section.person = context.person
			where context.product = @program
					and context.context_type = 'Enrollment'
					and context.status <> 'Canceled'
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.assignedByLinkType = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many males were placed, how many females
			select
					(
						select count(program_c.context_id)
						from context program_c
							inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
							left join (
								context section
								inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
							) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
						where program_c.product = @program
							and program_c.context_type = 'Enrollment'
							and program_c.status <> 'Canceled'
							and exists(
								select sp.prereg_link from session_preference sp where sp.program = @program and sp.prereg_link = program_c.prereg_link
							)
							and program_c.prereg_link like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							and section.context_id is not null
					) AS assigned_my,
					(
						select count(program_c.context_id)
						from context program_c
							inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
							left join (
								context section
								inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
							) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
						where program_c.product = @program
							and program_c.context_type = 'Enrollment'
							and program_c.status <> 'Canceled'
							and exists(
								select sp.prereg_link from session_preference sp where sp.program = @program and sp.prereg_link = program_c.prereg_link
							)
							and program_c.prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							and section.context_id is not null
					) AS assigned_linked,
					(
						select count(program_c.context_id)
						from context program_c
							inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
							left join (
								context section
								inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
							) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
						where program_c.product = @program
							and program_c.context_type = 'Enrollment'
							and program_c.status <> 'Canceled'
							and exists(
								select sp.prereg_link from session_preference sp where sp.program = @program and sp.prereg_link = program_c.prereg_link
							)
							and program_c.prereg_link like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							and section.context_id is null
					) AS unassigned_my,
					(
						select count(program_c.context_id)
						from context program_c
							inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
							left join (
								context section
								inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
							) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
						where program_c.product = @program
							and program_c.context_type = 'Enrollment'
							and program_c.status <> 'Canceled'
							and exists(
								select sp.prereg_link from session_preference sp where sp.program = @program and sp.prereg_link = program_c.prereg_link
							)
							and program_c.prereg_link not like 'my[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
							and section.context_id is null
					) AS unassigned_linked
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.assignedByReservationType = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many were placed or not placed, by reservation or not
			select
					(
						select isnull(sum(contexts), 0)
						from (
							select count(distinct program_c.context_id) as contexts
							from context program_c
								inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
								inner join fsy_unit ward ON ward.unit_number = cast(program_c.lds_unit_no as varchar)
								inner join fsy_unit stake ON stake.unit_number = ward.parent
								left join session_preference sp on sp.program = program_c.product and sp.prereg_link = program_c.prereg_link and sp.priority = 1
								left join (
									context section
									inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
								) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
								left join (
										fsy_session_unit fsu_w
										inner join pm_session pm_session_w on pm_session_w.pm_session_id = fsu_w.pm_session
										inner join product product_w on product_w.product_id = pm_session_w.product
								) on fsu_w.fsy_unit = ward.unit_number and product_w.program = program_c.product
								left join (
										fsy_session_unit fsu_s
										inner join pm_session pm_session_s on pm_session_s.pm_session_id = fsu_s.pm_session
										inner join product product_s on product_s.product_id = pm_session_s.product
								) on fsu_s.fsy_unit = stake.unit_number and product_s.program = program_c.product
							where program_c.product = @program
								and program_c.context_type = 'Enrollment'
								and program_c.status <> 'Canceled'
								and sp.prereg_link is not null
								and (
									(fsu_w.pm_session is null and (fsu_s.male is not null or fsu_s.female is not null))
									or (fsu_w.pm_session is not null and (fsu_w.male is not null or fsu_w.female is not null))
								)
								and section.context_id is not null
							group by program_c.context_id
						) data
					) AS assigned_reserved,
					(
						select isnull(sum(contexts), 0)
						from (
							select count(distinct program_c.context_id) as contexts
							from context program_c
								inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
								inner join fsy_unit ward ON ward.unit_number = cast(program_c.lds_unit_no as varchar)
								inner join fsy_unit stake ON stake.unit_number = ward.parent
								left join session_preference sp on sp.program = program_c.product and sp.prereg_link = program_c.prereg_link and sp.priority = 1
								left join (
									context section
									inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
								) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
								left join (
										fsy_session_unit fsu_w
										inner join pm_session pm_session_w on pm_session_w.pm_session_id = fsu_w.pm_session
										inner join product product_w on product_w.product_id = pm_session_w.product
								) on fsu_w.fsy_unit = ward.unit_number and product_w.program = program_c.product
								left join (
										fsy_session_unit fsu_s
										inner join pm_session pm_session_s on pm_session_s.pm_session_id = fsu_s.pm_session
										inner join product product_s on product_s.product_id = pm_session_s.product
								) on fsu_s.fsy_unit = stake.unit_number and product_s.program = program_c.product
							where program_c.product = @program
								and program_c.context_type = 'Enrollment'
								and program_c.status <> 'Canceled'
								and sp.prereg_link is not null
								and not (
									(fsu_w.pm_session is null and (fsu_s.male is not null or fsu_s.female is not null))
									or (fsu_w.pm_session is not null and (fsu_w.male is not null or fsu_w.female is not null))
								)
								and section.context_id is not null
							group by program_c.context_id
						) data
					) AS assigned_regular,
					(
						select sum(contexts)
						from (
							select count(distinct program_c.context_id) as contexts
							from context program_c
								inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
								inner join fsy_unit ward ON ward.unit_number = cast(program_c.lds_unit_no as varchar)
								inner join fsy_unit stake ON stake.unit_number = ward.parent
								left join session_preference sp on sp.program = program_c.product and sp.prereg_link = program_c.prereg_link and sp.priority = 1
								left join (
									context section
									inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
								) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
								left join (
										fsy_session_unit fsu_w
										inner join pm_session pm_session_w on pm_session_w.pm_session_id = fsu_w.pm_session
										inner join product product_w on product_w.product_id = pm_session_w.product
								) on fsu_w.fsy_unit = ward.unit_number and product_w.program = program_c.product
								left join (
										fsy_session_unit fsu_s
										inner join pm_session pm_session_s on pm_session_s.pm_session_id = fsu_s.pm_session
										inner join product product_s on product_s.product_id = pm_session_s.product
								) on fsu_s.fsy_unit = stake.unit_number and product_s.program = program_c.product
							where program_c.product = @program
								and program_c.context_type = 'Enrollment'
								and program_c.status <> 'Canceled'
								and sp.prereg_link is not null
								and (
									(fsu_w.pm_session is null and (fsu_s.male is not null or fsu_s.female is not null))
									or (fsu_w.pm_session is not null and (fsu_w.male is not null or fsu_w.female is not null))
								)
								and section.context_id is null
							group by program_c.context_id
						) data
					) AS unassigned_reserved,
					(
						select sum(contexts)
						from (
							select count(distinct program_c.context_id) as contexts
							from context program_c
								inner join event on event.event_object = 'context' and event.event_object_id = program_c.context_id and event.event_type = 'preRegReceived'
								inner join fsy_unit ward ON ward.unit_number = cast(program_c.lds_unit_no as varchar)
								inner join fsy_unit stake ON stake.unit_number = ward.parent
								left join session_preference sp on sp.program = program_c.product and sp.prereg_link = program_c.prereg_link and sp.priority = 1
								left join (
									context section
									inner join product on product.product_id = section.product and product.program = @program and product.master_type = 'Section'
								) on section.person = program_c.person and section.status <> 'Canceled' and section.context_type = 'Enrollment'
								left join (
										fsy_session_unit fsu_w
										inner join pm_session pm_session_w on pm_session_w.pm_session_id = fsu_w.pm_session
										inner join product product_w on product_w.product_id = pm_session_w.product
								) on fsu_w.fsy_unit = ward.unit_number and product_w.program = program_c.product
								left join (
										fsy_session_unit fsu_s
										inner join pm_session pm_session_s on pm_session_s.pm_session_id = fsu_s.pm_session
										inner join product product_s on product_s.product_id = pm_session_s.product
								) on fsu_s.fsy_unit = stake.unit_number and product_s.program = program_c.product
							where program_c.product = @program
								and program_c.context_type = 'Enrollment'
								and program_c.status <> 'Canceled'
								and sp.prereg_link is not null
								and not (
									(fsu_w.pm_session is null and (fsu_s.male is not null or fsu_s.female is not null))
									or (fsu_w.pm_session is not null and (fsu_w.male is not null or fsu_w.female is not null))
								)
								and section.context_id is null
							group by program_c.context_id
						) data
					) AS unassigned_regular
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		local.unassignedParticipants = variables.utils.queryToStruct(
			QueryExecute(
				"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			-- how many people who pre-registered didn't get assigned
			select context.context_id  from context inner join event on event_object = 'context' and event_object_id = context_id and event_type = 'preRegReceived'
			inner join session_preference sp on sp.prereg_link = context.prereg_link and sp.priority = 1
			left join (
					context section inner join product product_s on product_s.product_id = section.product and product_s.program = @program and product_s.master_type = 'Section'
			) on section.person = context.person and section.context_type = 'Enrollment' and section.status <> 'Canceled'
			where context.context_type = 'Enrollment' and context.status <> 'Canceled' and context.product = @program and section.context_id is null
			",
				{},
				{ datasource: variables.dsn.scheduler }
			)
		);

		// FIKSME: code these here and put UI up for them
		// What went wrong

		return {
			"preferenceBreakdown" = local.preferenceBreakdown,
			"timedStats" = local.timedStats,
			"linkStats" = local.linkStats,
			"basicCounts" = local.basicCounts,
			"preregUnassigned" = local.preregUnassigned,
			"assignedByChoice" = local.assignedByChoice,
			"fullSessions" = local.fullSessions,
			"fullSessionCount" = local.fullSessionCount,
			"fullPlaceTimes" = local.fullPlaceTimes,
			"fullPlaceTimesCounts" = local.fullPlaceTimesCounts,
			"singleGenderFull" = local.singleGenderFull,
			"singleGenderFullCount" = local.singleGenderFullCount,
			"linksPlacedCounts" = local.linksPlacedCounts,
			"assignedByGenderCounts" = local.assignedByGenderCounts,
			"assignedByLinkType" = local.assignedByLinkType,
			"assignedByReservationType" = local.assignedByReservationType,
			"linkMemberStats" = local.linkMemberStats,
			"unassignedParticipants" = local.unassignedParticipants
		}
	}

	// Testing utils

	// begin individual setup helper functions

	function createProgram() {
		application.progress.append({ currentStep: "createProgram", tick: getTickCount() })

		QueryExecute(
			"
			insert into product (
			status,
			short_title,
			title,
			department,
			product_type,
			master_type,
			start_date,
			end_date,
			web_enroll_start,
			web_enroll_end,
			enroll_start,
			enroll_end,
			include_in_enrollment_total,
			created_by
		)
		select
			status,
			concat(short_title, '_#variables.ticketName#'),
			concat(title, '_#variables.ticketName#'),
			department,
			product_type,
			master_type,
			start_date,
			end_date,
			web_enroll_start,
			web_enroll_end,
			enroll_start,
			enroll_end,
			include_in_enrollment_total,
			created_by
			from product where product_id = :realProgram
		",
			{ realProgram = variables.realProgram },
			{
				datasource: variables.dsn.local,
				result = "local.result"
			}
		);

		writeDump({ program: local.result.generatedKey})

		return local.result.generatedkey;
	}

	// just get the current cntl_value program
	private numeric function getProgram() {
		return getModel("controlValue").getItem("CURRENT_FSY_PROGRAM")
	}

	public void function setControlValueToCreatedProgram(
		numeric product_id
	) {
		if (isDefined("application.progress"))
			application.progress.append({ currentStep: "setControlValue", tick: getTickCount() })

		QueryExecute(
			"
			update cntl_value set value = :product_id, updated_by = :created_by where control = 'current_fsy_program'
		",
			{ product_id = arguments.product_id, created_by: variables.ticket },
			{ datasource: variables.dsn.local }
		);
	}

	private struct function createFullSection(
		required numeric program,
		numeric female = 10,
		numeric male = 10
	) {
		application.progress.append({ currentStep: "createFullSection", tick: getTickCount() })

		local.data = {}
		local.time = now()

		// ensure unique short_title
		local.result = QueryExecute(
			"
			select top 1 title
			from product
			where master_type = 'Section'
				and short_title like '%_#variables.ticketName#'
			order by created desc
		",
			{},
			{ datasource: variables.dsn.local }
		);

		if (local.result.recordCount == 0) local.next = 1;
		else {
			local.match = reFind("Section_(\d+)_#variables.ticketName#", local.result.title, 1, true)
			local.next = Mid(local.result.title, local.match.pos[ 2 ], local.match.len[ 2 ]) + 1
		}

		// section
		QueryExecute(
			"
			insert into product (
				status,
				short_title,
				title,
				department,
				product_type,
				master_type,
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				enroll_start,
				enroll_end,
				program,
				include_in_enrollment_total,
				created_by
			)
			select
				'Active',
				concat('Section_', :next, '_#variables.ticketName#'),
				concat('Section_', :next, '_#variables.ticketName#'),
				department,
				product_type,
				'Section',
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				:enroll_start,
				:enroll_end,
				:program,
				include_in_enrollment_total,
				created_by
			from product where product_id = :realProgram
		",
			{
				next = local.next,
				program = arguments.program,
				realProgram = variables.realProgram,
				enroll_start = { value = local.time, cfsqltype="timestamp"},
				enroll_end = { value = dateadd("m", 1, local.time), cfsqltype="timestamp"}
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.section = local.result.generatedKey

		// female housing
		QueryExecute(
			"
			insert into product (
				status,
				short_title,
				title,
				department,
				product_type,
				master_type,
				option_type,
				housing_type,
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				enroll_start,
				enroll_end,
				max_space,
				max_enroll,
				gender,
				program,
				include_in_enrollment_total,
				created_by
			)
			select
				'Active',
				concat('FemaleHousing_', :next, '_#variables.ticketName#'),
				concat('FemaleHousing_', :next, '_#variables.ticketName#'),
				department,
				product_type,
				'Option',
				'Housing',
				'Female',
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				:enroll_start,
				:enroll_end,
				:max_enroll,
				:max_enroll,
				'F',
				:program,
				include_in_enrollment_total,
				created_by
			from product where product_id = :realProgram
		",
			{
				next = local.next,
				program = arguments.program,
				realProgram = variables.realProgram,
				max_enroll = arguments.female,
				enroll_start = { value = local.time, cfsqltype="timestamp"},
				enroll_end = { value = dateadd("m", 1, local.time), cfsqltype="timestamp"}
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.female = local.result.generatedKey

		// male housing
		QueryExecute(
			"
			insert into product (
				status,
				short_title,
				title,
				department,
				product_type,
				master_type,
				option_type,
				housing_type,
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				enroll_start,
				enroll_end,
				max_space,
				max_enroll,
				gender,
				program,
				include_in_enrollment_total,
				created_by
			)
			select
				'Active',
				concat('MaleHousing_', :next, '_#variables.ticketName#'),
				concat('MaleHousing_', :next, '_#variables.ticketName#'),
				department,
				product_type,
				'Option',
				'Housing',
				'Male',
				start_date,
				end_date,
				web_enroll_start,
				web_enroll_end,
				:enroll_start,
				:enroll_end,
				:max_enroll,
				:max_enroll,
				'M',
				:program,
				include_in_enrollment_total,
				created_by
			from product where product_id = :realProgram
		",
			{
				next = local.next,
				program = arguments.program,
				realProgram = variables.realProgram,
				max_enroll = arguments.male,
				enroll_start = { value = local.time, cfsqltype="timestamp"},
				enroll_end = { value = dateadd("m", 1, local.time), cfsqltype="timestamp"}
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.male = local.result.generatedKey

		// option group
		QueryExecute(
			"
			insert into option_group (
				section,
				name,
				min_choice,
				max_choice,
				created_by
			)
			select
				:section,
				'Housing',
				1,
				1,
				created_by
			from product where product_id = :realProgram
		",
			{
				realProgram = variables.realProgram,
				section = local.data.section

			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.optionGroup = local.result.recordcount > 0

		// female option_item
		QueryExecute(
			"
			insert into option_item (
				section,
				name,
				item,
				created_by
			)
			select
				:section,
				'Housing',
				:item,
				created_by
			from product where product_id = :realProgram
		",
			{
				realProgram = variables.realProgram,
				section = local.data.section,
				item = local.data.female
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.optionItemF = local.result.recordcount > 0

		// male option_item
		QueryExecute(
			"
			insert into option_item (
				section,
				name,
				item,
				created_by
			)
			select
				:section,
				'Housing',
				:item,
				created_by
			from product where product_id = :realProgram
		",
			{
				realProgram = variables.realProgram,
				section = local.data.section,
				item = local.data.male
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		)

		local.data.optionItemM = local.result.recordcount > 0

		return local.data
	}

	private numeric function createPerson(
		required string gender
	) {
		application.progress.append({ currentStep: "createPerson", tick: getTickCount() })

		QueryExecute(
			"
			insert into person (first_name, last_name, gender, birthdate, lds_account_id, created_by)
			values ('First_#variables.ticketName#', 'Last_#variables.ticketName#', :gender, '2008-01-01', :church_id, :created_by)
		",
			{ gender = arguments.gender, church_id = "#Floor(Rand() * 100000000)##Floor(Rand() * 100000000)#", created_by: variables.ticket },
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.result.generatedKey
	}

	private numeric function createProgramContext(
		required numeric program,
		required numeric person,
		required numeric ward,
		required numeric stake,
		string prereg_link = ""
	) {
		application.progress.append({ currentStep: "createProgramContext", tick: getTickCount() })

		QueryExecute(
			"
			insert into context (person, product, context_type, status, prereg_link, lds_unit_no, stake, created_by)
			values (:person, :product, 'Enrollment', 'Active', :prereg_link, :ward, :stake, :created_by)
		",
			{
				person = arguments.person,
				product = arguments.program,
				prereg_link = arguments.prereg_link,
				ward = arguments.ward,
				stake = arguments.stake,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		if (arguments.prereg_link == "")
			QueryExecute(
				"
				update context set prereg_link = :prereg_link, updated_by = :created_by where context_id = :context_id
			",
				{ prereg_link = "my#local.result.generatedkey#", context_id = local.result.generatedkey,
				created_by = variables.ticket },
				{ datasource: variables.dsn.local }
			);

		return local.result.generatedkey
	}

	private numeric function createHireContext(
		required numeric person,
		required numeric program
	) {
		application.progress.append({ currentStep: "createHireContext", tick: getTickCount() })

		QueryExecute(
			"
			insert into context (person, product, context_type, status, created_by)
			values (:person, :product, 'Hired Staff', 'Active', :created_by)
		",
			{
				person = arguments.person,
				product = arguments.program,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.result.generatedkey
	}

	private struct function createHiringInfo(
		required numeric context,
		string hired_position = "Counselor",
		string state = "UT",
		string country = "USA"
	) {
		application.progress.append({ currentStep: "createHiringInfo", tick: getTickCount() })

		QueryExecute(
			"
			insert into hiring_info (context, application_type, hired_position, interview_score, state, country, auto_schedule, created_by)
			values (:context, 'FSY', :hired_position, 9, :state, :country, 'Y', :created_by)
		",
			{
				context = arguments.context,
				hired_position = arguments.hired_position,
				state = arguments.state,
				country = arguments.country,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.result
	}

	private void function createAvailability(
		required numeric context,
		required array weeksAvailable,
		numeric number_of_weeks = 1,
		numeric pm_location = 0,
		string start_date = ""
	) {
		application.progress.append({ currentStep: "createAvailability", tick: getTickCount() })

		arguments.created_by = variables.ticket
		QueryExecute(
			"
			insert into hires_availability (
				context,
				number_of_weeks,
				#arguments.pm_location == 0 ? "" : "pm_location,"#
				#arguments.start_date == "" ? "" : "start_date,"#
				created_by
			)
			values (
				:context,
				:number_of_weeks,
				#arguments.pm_location == 0 ? "" : ":pm_location,"#
				#arguments.start_date == "" ? "" : ":start_date,"#
				:created_by
			)
		",
			arguments, { datasource: variables.dsn.local, result = "local.result" }
		);

		local.ha_id = local.result.generatedkey

		for (local.week in arguments.weeksAvailable) {
			QueryExecute(
				"
				insert into availability_week (hires_availability, start_date, type, created_by)
				values (:id, :start_date, 'Session', :created_by)
			",
				{
					id: local.ha_id,
					start_date: local.week,
				created_by = variables.ticket
				},
				{ datasource: variables.dsn.local, result = "local.result" }
			);
		}

	}

	private void function createTrainingTravel(
		required numeric context,
		string state = "UT",
		string country = "USA"
	) {
		application.progress.append({ currentStep: "createTrainingTravel", tick: getTickCount() })

		QueryExecute(
			"
			insert into training_travel (context, country, state, created_by)
			values (:context, :country, :state, :created_by)
		",
			{
				context: arguments.context,
				state: arguments.state,
				country: arguments.country,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local }
		);
	}

	private void function createPreRegReceivedEvent(
		required numeric context_id
	) {
		application.progress.append({ currentStep: "createPreRegReceivedEvent", tick: getTickCount() })

		QueryExecute(
			"
			insert into event (event_object, event_object_id, event_type) values ('CONTEXT', :context_id, 'preRegReceived')
		",
			{ context_id = arguments.context_id },
			{ datasource: variables.dsn.local }
		);
	}

	private numeric function createPMLocation() {
		application.progress.append({ currentStep: "createPMLocation", tick: getTickCount() })

		// TODO: see if country is necessary - hopefully that'll just be on the product ¯\_(ツ)_/¯
		QueryExecute(
			"
			insert into pm_location (name, created_by) values ('This is the place', :created_by)
		",
			{
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.result.generatedkey
	}

	private void function createSessionPreference(
		required numeric program,
		required string prereg_link,
		required numeric pm_location,
		required string start_date,
		numeric priority = 1
	) {
		application.progress.append({ currentStep: "createSessionPreference", tick: getTickCount() })

		local.joinCheck = queryExecute("
			select * from session_preference where program = :program and prereg_link = :prereg_link and priority = :priority
		", {
			program: program,
			prereg_link: prereg_link,
			priority: priority
		}, { datasource: variables.dsn.local });

		local.args = Duplicate(arguments)
		local.args.created_by = variables.ticket
		if (local.joinCheck.recordCount == 0)
		QueryExecute(
			"
			insert into session_preference (program, prereg_link, pm_location, start_date, priority, created_by)
			values (:program, :prereg_link, :pm_location, :start_date, :priority, :created_by)
		",
			local.args,
			{ datasource: variables.dsn.local }
		);
	}

	private numeric function createWard(
		required numeric stake
	) {
		application.progress.append({ currentStep: "createWard", tick: getTickCount() })

		// ensure unique unit_number
		local.next = QueryExecute(
			"
			select top 1 unit_number + 1 as unit_number
			from fsy_unit
			order by unit_number desc
		",
			{},
			{ datasource: variables.dsn.local }
		);

		QueryExecute(
			"
			insert into fsy_unit (unit_number, name, [type], parent, created_by)
			values (:unit_number, :name, 'Ward', :parent, :created_by)
		",
			{ unit_number = local.next.unit_number, parent = arguments.stake, name = "ward_#local.next.unit_number#_variables.ticket",
				created_by = variables.ticket },
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.next.unit_number
	}

	private numeric function createStake() {
		application.progress.append({ currentStep: "createStake", tick: getTickCount() })

		// ensure unique unit_number
		local.next = QueryExecute(
			"
			select top 1 unit_number + 1 as unit_number
			from fsy_unit
			order by unit_number desc
		",
			{},
			{ datasource: variables.dsn.local }
		);

		QueryExecute(
			// Utah American Fork Area Coordinating Council
			"
			insert into fsy_unit (unit_number, name, [type], parent, created_by)
			values (:unit_number, :name, 'Stake', 466344, :created_by)
		",
			{ unit_number = local.next.unit_number, name = "stake_#local.next.unit_number#_#variables.ticket#",
				created_by = variables.ticket },
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.next.unit_number
	}

	private numeric function createPMSession(
		required numeric pm_location,
		required string start_date,
		required numeric product
	) {
		application.progress.append({ currentStep: "createPMSession", tick: getTickCount() })

		QueryExecute(
			"
			insert into pm_session (title, department, session_type, product, pm_location, start_date, end_date, participant_start_date, participant_end_date, created_by)
			values (:title, 'FSY', 'FSY', :product, :pm_location, :start_date, :end_date, :participant_start_date, :participant_end_date, :created_by)
		",
			{
				title = "session_#arguments.pm_location#_#arguments.start_date#",
				product = arguments.product,
				pm_location = arguments.pm_location,
				start_date = dateFormat(dateAdd("d", -1, arguments.start_date), "yyyy-mm-dd"),
				end_date = dateFormat(dateAdd("d", 6, arguments.start_date), "yyyy-mm-dd"),
				participant_start_date = arguments.start_date,
				participant_end_date = dateFormat(dateAdd("d", 5, arguments.start_date), "yyyy-mm-dd"),
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.result" }
		);

		return local.result.generatedkey
	}

	private struct function createEnrollment(numeric person_id, numeric section, numeric housing) {
		application.progress.append({ currentStep: "createEnrollment", tick: getTickCount() })

		QueryExecute(
			"
			insert into context (person, product, context_type, status, pending_status, created_by)
			values (:person, :product, 'Enrollment', 'Reserved', 'Active', :created_by)
		",
			{
				person = person_id,
				product = section,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.section" }
		)

		QueryExecute(
			"
			insert into context (person, product, context_type, status, pending_status, choice_for, created_by)
			values (:person, :product, 'Enrollment', 'Reserved', 'Active', :section, :created_by)
		",
			{
				person = person_id,
				product = housing,
				section = local.section.generatedkey,
				created_by = variables.ticket
			},
			{ datasource: variables.dsn.local, result = "local.housing" }
		)

		return {
			section = local.section.generatedkey,
			housing = local.housing.generatedkey
		}
	}

	private void function createFSURecords(
		required numeric pm_session,
		required numeric fsy_unit,
		numeric female = 0,
		numeric male = 0
	) {
		application.progress.append({ currentStep: "createFSURecords", tick: getTickCount() })

		queryExecute("
			insert into fsy_session_unit (pm_session, fsy_unit, female, male, source, created_by)
			values (:pm_session, :fsy_unit, :female, :male, 'Participant', :created_by)
		",
		{
			pm_session = arguments.pm_session,
			fsy_unit = arguments.fsy_unit,
			female = { value=arguments.female, cfsqltype="cf_sql_numeric", null=(arguments.female == 0) },
			male = { value=arguments.male, cfsqltype="cf_sql_numeric", null=(arguments.male == 0) },
			created_by = variables.ticket
		}, { datasource: variables.dsn.local });
	}

	// END individual setup helper functions

	// Begin actual test case setup functions

	// just put all the above functions through their paces; ignore this
	private void function kitchenSink() {
		program = createProgram()
		setControlValueToCreatedProgram(program)
		writedump(createFullSection(program))
		stake = createStake()
		ward = createWard(stake)
		writedump({ ward: ward, stake: stake })
		person = createPerson('M')
		program_c = createProgramContext(program, person, ward, stake)
		createPreRegReceivedEvent(program_c)
		pm_location = createPMLocation()
		start_date = '2024-06-01'
		prereg_link = "my#program_c#" // for example, but could use a non-my passed in earlier
		createSessionPreference(program, prereg_link, pm_location, start_date)
		pm_session = createPMSession(pm_location, start_date)
		writedump({ pm_session: pm_session })
		createFSURecords(pm_session, stake)
	}

	/*
		All the test cases

		0 *** Happy path (ignore this one; testing whether the test data setup code can output something the actual scheduler can successfully work with; not so useful to run if all other below cases are being run)
				a - 1 session; 1 bed; 1 participant; they get assigned

		1 *** assign people in a random order (to make it fair)
				... best tested with a few runthroughs and take the average
				a - 1 session; 1 bed; 2 participants = ~50% of the time each is placed and the other not

		2 *** penalize link groups (to make it unfair)
				... best tested with a few runthroughs and take the average
				a - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 12 unlinked participants = 20 people placed
				b - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 20 unlinked participants = group penalty applies, 20 people placed
				c - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 100 unlinked participants = group penalty more apparent, 20 people placed

		3 *** never sell more than max_enroll beds
				a - 1 session; 1 bed; 2 participants = 1 placed; 1 not placed

		4 *** honor unit reservations
				a - 1 session; 1 beds; 1 participant; 1 other unit w/ 1 open reserved bed = 1 not placed
				b - 1 session; 2 beds; 2 participants; 1 other unit w/ 1 open reserved bed = 1 placed; 1 not placed
				c - 1 session; 2 beds; 1 participant; P's unit w/ 1 open reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed
				d - 1 session; 2 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 not placed
				e - 1 session; 3 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed

		5 *** everyone in a given link is placed, or no one in the link is placed
				a - 1 session; 1 bed; 2 linked participants; 2 not placed
				b - 1 session; 2 beds; 2 linked participants; 2 placed
				c - 1 session; 1 M bed/ 1 F bed; 2 linked participants, M and F; 2 placed
				d - 1 session; 2 M bed; 2 linked participants, M and F; 2 not placed
				e - 2 sessions; 1 bed each; 2 linked participants; 2 not placed

		6 *** if a link is placed, all the members are placed in the same pm_session (not split up over concurrent sessions)
				a - 2 sessions; 1 full bed and 1 open bed each; 2 linked participants = 2 not placed
				b - 2 sessions; 2 open beds each; 2 linked participants = 2 placed same session

		7 *** we give people their highest priority preference possible (i.e., after randomizing assign as many 1st priorities as we can, then 2, then 3, etc.)
				a - 1 session A, 1 session B; 1 open bed each session; 3 participants, each w/ p1 A, p2 B = 1 placed in A, 1 placed in B, 1 not placed
				b - 1 session A, 1 session B; 2 open beds A, 1 open bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z placed in B
				c - 1 session A, 1 session B; 2 open beds A, 1 full bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z not placed
				d - 2 placetimes A and B; A is full; 1 participant w/ p1 A, p2 B = 1 placed in B
				e - 5 sessions; 1 participant; cycle through p1-5 for each session = placed in the right one each time

		8 *** maximize the number of people we place overall (without violating any of the above rules)
				... this may be best tested by doing the full run

	*/

	// First a few li'l helper functions for more concise test case functions
		private struct function baseSetup() {
			program = createProgram()
			setControlValueToCreatedProgram(program)

			return {
				program: program,
				start_date = '2024-06-01'
			}
		}
		private struct function newUnits() {
			stake = createStake()
			return {
				stake: stake,
				ward = createWard(stake)
			}
		}
		private struct function newParticipant(string gender, struct base, any s, any start_date = "", string prereg_link = "", female = 0, male = 0, struct u = {}) {
			if (u.isEmpty())
				u = newUnits()

			if (!isArray(s))
				s = [s]

			if (isSimpleValue(start_date) && start_date == "")
				start_date = [base.start_date]

			if (!isArray(start_date))
				start_date = [start_date]

			if (start_date.len() < s.len())
				for (local.i = start_date.len(); i <= s.len(); local.i++)
					start_date.append(b.start_date) // just pad with the base


			person = createPerson(gender)
			program_c = createProgramContext(program, person, u.ward, u.stake, prereg_link)
			createPreRegReceivedEvent(program_c)
			for (local.i = 1; local.i <= s.len(); local.i++) {
				createFSURecords(s[local.i].pm_session, u.stake, female, male)
				createSessionPreference(base.program, prereg_link == "" ? "my#program_c#" : prereg_link, s[local.i].pm_location, start_date[local.i], local.i)
			}

			return {
				person: person,
				u: u,
				program_c: program_c
			}
		}
		private struct function newSession(struct base, numeric female = 10, numeric male = 10, numeric pm_location = 0, start_date = "") {
			if (pm_location == 0)
				pm_location = createPMLocation()

			if (start_date == "")
				start_date = base.start_date

			sectionInfo = createFullSection(base.program, female, male)

			return {
				pm_location: pm_location,
				sectionInfo: sectionInfo,
				pm_session: createPMSession(pm_location, start_date, sectionInfo.section)
			}
		}

		// 0 *** ignore this, similar to the kitchenSink function above

		private void function happyPath() {
			program = createProgram()
			setControlValueToCreatedProgram(program)
			sectionInfo = createFullSection(program)
			writedump(sectionInfo)
			stake = createStake()
			ward = createWard(stake)
			writedump({ ward: ward, stake: stake })
			person = createPerson('M')
			program_c = createProgramContext(program, person, ward, stake)
			createPreRegReceivedEvent(program_c)
			pm_location = createPMLocation()
			start_date = '2024-06-01'
			prereg_link = "my#program_c#" // for example, but could use a non-my passed in earlier
			createSessionPreference(program, prereg_link, pm_location, start_date)
			pm_session = createPMSession(pm_location, start_date, sectionInfo.section)
			writedump({ pm_session: pm_session })
			createFSURecords(pm_session, stake)
		}

		// 1 *** assign people in a random order (to make it fair)

		//		... best tested with a few runthroughs and take the average
		//		a - 1 session; 1 bed; 2 participants = ~50% of the time each is placed and the other not
		// verify with a query like:
		/*
			select * from FSY.DBO.person where created_by like 'FSY-#variables.ticketName#%'

			select person, product, context_type, context.status, pending_status, choice_for, context.created, context.created_by
			from FSY.DBO.context inner join product on product = product_id where product.master_type = 'Section' and short_title like 'Section_%_#variables.ticketName#' order by context.created desc
		*/
		private void function setup_1_a() {
			b = baseSetup()

			//1 session; 1 bed
			s = newSession(b, 0, 1)

			// 2 participants
			p1 = newParticipant('M', b, s)
			p2 = newParticipant('M', b, s)
		}

		// 2 *** penalize link groups (to make it unfair)
		//		... best tested with a few runthroughs and take the average (at least for b and c; a should always fit all 20)

		//		a - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 12 unlinked participants = 20 people placed
		private void function setup_2_a() {
			b = baseSetup()

			//1 session; 20 beds
			s = newSession(b, 0, 20)

			// 2 linked participants
			newParticipant('M', b, s, "", "alpha")
			newParticipant('M', b, s, "", "alpha")

			// 6 linked participants
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")

			for (i = 1; i <= 12; i++) newParticipant('M', b, s)
		}

		//		b - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 20 unlinked participants = group penalty applies, 20 people placed
		// results:
		// 18 2 2 6 x6
		// 12 8 8 0 x1
		// 20 0 0 8 x1
		private void function setup_2_b() {
			b = baseSetup()

			//1 session; 20 beds
			s = newSession(b, 0, 20)

			// 2 linked participants
			newParticipant('M', b, s, "", "alpha")
			newParticipant('M', b, s, "", "alpha")

			// 6 linked participants
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")

			for (i = 1; i <= 20; i++) newParticipant('M', b, s)
		}

		//		c - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 100 unlinked participants = group penalty more apparent, 20 people placed
		// results:
		// 20 0 80 8 x2
		private void function setup_2_c() {
			b = baseSetup()

			//1 session; 20 beds
			s = newSession(b, 0, 20)

			// 2 linked participants
			newParticipant('M', b, s, "", "alpha")
			newParticipant('M', b, s, "", "alpha")

			// 6 linked participants
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")
			newParticipant('M', b, s, "", "bravo")

			for (i = 1; i <= 100; i++) newParticipant('M', b, s)
		}

		// 3 *** never sell more than max_enroll beds

		//		a - 1 session; 1 bed; 2 participants = 1 placed; 1 not placed
		private void function setup_3_a() {
			b = baseSetup()

			// 1 session; 1 bed
			s = newSession(b, 0, 1)

			// 2 participants
			newParticipant('M', b, s)
			newParticipant('M', b, s)
		}

		// 4 *** honor unit reservations

		//		a - 1 session; 1 bed; 1 participant; 1 other unit w/ 1 open reserved bed = 1 not placed
		private void function setup_4_a() {
			b = baseSetup()

			// 1 session; 1 bed
			s = newSession(b, 0, 1)

			// 1 participant
			newParticipant('M', b, s)

			// 1 other unit w/ 1 open reserved bed
			createFSURecords(s.pm_session, createStake(), 0, 1)
		}

		//		b - 1 session; 2 beds; 2 participants; 1 other unit w/ 1 open reserved bed = 1 placed; 1 not placed
		private void function setup_4_b() {
			b = baseSetup()

			// 1 session; 2 beds
			s = newSession(b, 0, 2)

			// 2 participants
			newParticipant('M', b, s)
			newParticipant('M', b, s)

			// 1 other unit w/ 1 open reserved bed
			createFSURecords(s.pm_session, createStake(), 0, 1)
		}

		//		c - 1 session; 2 beds; 1 participant; P's unit w/ 1 open reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed
		private void function setup_4_c() {
			b = baseSetup()

			// 1 session; 2 beds
			s = newSession(b, 0, 2)

			// 1 participant; unit has 1 open reserved bed
			newParticipant('M', b, s, "", "", 0, 1)

			// 1 other unit w/ 1 open reserved bed
			createFSURecords(s.pm_session, createStake(), 0, 1)
		}

		//		d - 1 session; 2 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 not placed (and yes, 1 already "placed")
		private void function setup_4_d() {
			b = baseSetup()

			// 1 session; 2 beds
			s = newSession(b, 0, 2)

			// 1 participant; unit has 1 open reserved bed
			p = newParticipant('M', b, s, "", "", 0, 1)

			// 1 filled reserved bed
			p2 = newParticipant(gender = 'M', base = b, s = s, u = p.u)
			createEnrollment(p2.person, s.sectionInfo.section, s.sectionInfo.male)

			// 1 other unit w/ 1 open reserved bed
			createFSURecords(s.pm_session, createStake(), 0, 1)
		}

		//		e - 1 session; 3 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed
		private void function setup_4_e() {
			b = baseSetup()

			// 1 session; 1 bed
			s = newSession(b, 0, 3)

			// 1 participant; unit has 1 open reserved bed
			p = newParticipant('M', b, s, "", "", 0, 1)

			// 1 filled reserved bed
			p2 = newParticipant(gender = 'M', base = b, s = s, u = p.u)
			createEnrollment(p2.person, s.sectionInfo.section, s.sectionInfo.male)

			// 1 other unit w/ 1 open reserved bed
			createFSURecords(s.pm_session, createStake(), 0, 1)
		}

		// 5 *** everyone in a given link is placed, or no one in the link is placed

		//		a - 1 session; 1 bed; 2 linked participants; 2 not placed
		private void function setup_5_a() {
			b = baseSetup()

			// 1 session; 1 bed
			s = newSession(b, 0, 1)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('M', b, s, "", "apple")

		}

		//		b - 1 session; 2 beds; 2 linked participants; 2 placed
		private void function setup_5_b() {
			b = baseSetup()

			// 1 session; 2 beds
			s = newSession(b, 0, 2)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('M', b, s, "", "apple")
		}

		//		c - 1 session; 1 M bed/ 1 F bed; 2 linked participants, M and F; 2 placed
		private void function setup_5_c() {
			b = baseSetup()

			// 1 session; 1 M bed/ 1 F bed
			s = newSession(b, 1, 1)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('F', b, s, "", "apple")
		}

		//		d - 1 session; 2 M bed; 2 linked participants, M and F; 2 not placed
		private void function setup_5_d() {
			b = baseSetup()

			// 1 session; 1 M bed/ 1 F bed
			s = newSession(b, 0, 2)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('F', b, s, "", "apple")
		}

		//		e - 2 sessions; 1 bed each; 2 linked participants; 2 not placed
		private void function setup_5_e() {
			b = baseSetup()

			// 1 session; 1 M bed/ 1 F bed
			s = newSession(b, 0, 1)
			s2 = newSession(b, 0, 1, s.pm_location)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('M', b, s, "", "apple")
		}

		// 6 *** if a link is placed, all the members are placed in the same pm_session (not split up over concurrent sessions)

		//		a - 2 sessions; 1 full bed and 1 open bed each; 2 linked participants = 2 not placed (yes, with 2 "already" placed)
		private void function setup_6_a() {
			b = baseSetup()

			// 1 session; 1 M bed/ 1 F bed
			s = newSession(b, 0, 2)
			s2 = newSession(b, 0, 2, s.pm_location)

			// 2 linked participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('M', b, s, "", "apple")

			// 2 full beds, 1 in each session
			p = newParticipant('M', b, s)
			p2 = newParticipant('M', b, s2)
			createEnrollment(p.person, s.sectionInfo.section, s.sectionInfo.male)
			createEnrollment(p2.person, s2.sectionInfo.section, s2.sectionInfo.male)
		}

		//		b - 2 sessions; 2 open beds each; 2 linked participants = 2 placed same session (need to inspect the db directly after running the scheduler, as with this query)
		// select context_id, product from context where created_by = variables.ticket and choice_for is null
		private void function setup_6_b() {
			b = baseSetup()

			// sessions
			s = newSession(b, 0, 2)
			s2 = newSession(b, 0, 2, s.pm_location)

			// participants
			newParticipant('M', b, s, "", "apple")
			newParticipant('M', b, s, "", "apple")
		}

		// 7 *** we give people their highest priority preference possible (i.e., after randomizing assign as many 1st priorities as we can, then 2, then 3, etc.)

		//		a - 1 session A, 1 session B; 1 open bed each session; 3 participants, each w/ p1 A, p2 B = 1 placed in A, 1 placed in B, 1 not placed
		// test with query like:
		/*
			select person, product, context_type, context.status, pending_status, choice_for, context.created, context.created_by
			from FSY.DBO.context inner join product on product = product_id where short_title like 'Section_%_#variables.ticketName#' order by context.created desc
		*/
		private void function setup_7_a() {
			b = baseSetup()

			// sessions
			s_a = newSession(b, 0, 1)
			s_b = newSession(b, 0, 1)

			// participants
			newParticipant('M', b, [s_a, s_b])
			newParticipant('M', b, [s_a, s_b])
			newParticipant('M', b, [s_a, s_b])
		}

		//		b - 1 session A, 1 session B; 2 open beds A, 1 open bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z placed in B
		// test with query like:
		/*
			select person, product, context_type, context.status, pending_status, choice_for, context.created, context.created_by
			from FSY.DBO.context inner join product on product = product_id where short_title like 'Section_%_#variables.ticketName#' order by context.created desc
		*/
		private void function setup_7_b() {
			b = baseSetup()

			// sessions
			s_a = newSession(b, 0, 2)
			s_b = newSession(b, 0, 1)

			// participants
			x = newParticipant('M', b, s_a)
			y = newParticipant('M', b, s_a)
			z = newParticipant('M', b, [s_b, s_a])
		}

		//		c - 1 session A, 1 session B; 2 open beds A, 1 full bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z not placed (and 1 "already" placed)
		private void function setup_7_c() {
			b = baseSetup()

			// sessions
			s_a = newSession(b, 0, 2)
			s_b = newSession(b, 0, 1)

			// participants
			x = newParticipant('M', b, s_a)
			y = newParticipant('M', b, s_a)
			z = newParticipant('M', b, [s_b, s_a])

			// already placed
			a = newParticipant('M', b, s_b)
			createEnrollment(a.person, s_b.sectionInfo.section, s_b.sectionInfo.male)
		}

		//		d - 2 placetimes A and B; A is full; 1 participant w/ p1 A, p2 B = 1 placed in B
		// verify with query like:
		/*
			-- what got created
			select * from FSY.DBO.product where short_title like 'Section_%_#variables.ticketName#'
			-- make sure it was for the 2nd section, not the first
			select person, product, context_type, context.status, pending_status, choice_for, context.created, context.created_by
			from FSY.DBO.context inner join product on product = product_id where product.master_type = 'Section' and short_title like 'Section_%_#variables.ticketName#' order by context.created desc
		*/
		private void function setup_7_d() {
			b = baseSetup()
			other_start = '2024-06-08'

			// sessions
			s_a = newSession(b, 0, 0) // 0, 0 to simulate already full
			s_b = newSession(b, 0, 1, s_a.pm_location, other_start)

			// participants
			p = newParticipant('M', b, [s_a, s_b], [b.start_date, other_start])
		}

		//		e - 5 sessions; 1 participant; cycle through p1-5 for each session = placed in the right one each time
		// rerun this one 5x, uncommenting each of the last 5 lines in this function in turn
		// test they got into the right section with a query like:
		/*
			-- what got created
			select * from FSY.DBO.product where short_title like 'Section_%_#variables.ticketName#'
			-- make sure it was for the 2nd section, not the first
			select person, product, context_type, context.status, pending_status, choice_for, context.created, context.created_by
			from FSY.DBO.context inner join product on product = product_id where product.master_type = 'Section' and short_title like 'Section_%_#variables.ticketName#' order by context.created desc
		*/
		private void function setup_7_e() {
			b = baseSetup()

			// sessions
			s_a = newSession(b, 0, 1)
			s_b = newSession(b, 0, 1)
			s_c = newSession(b, 0, 1)
			s_d = newSession(b, 0, 1)
			s_e = newSession(b, 0, 1)

			// the "other" sessions, none of which will take the person
			s_w = newSession(b, 0, 0)
			s_x = newSession(b, 0, 0)
			s_y = newSession(b, 0, 0)
			s_z = newSession(b, 0, 0)

			// participants
			//newParticipant('M', b, [s_a, s_w, s_x, s_y, s_z])
			//newParticipant('M', b, [s_w, s_b, s_x, s_y, s_z])
			//newParticipant('M', b, [s_w, s_x, s_c, s_y, s_z])
			//newParticipant('M', b, [s_w, s_x, s_y, s_d, s_z])
			newParticipant('M', b, [s_w, s_x, s_y, s_z, s_e])
		}


	// END actual test case setup functions

	// Main test setup function; pass in whichever test case function name you wish to run
	public void function setup(string testCase = "kitchenSink") {
		application.progress = { start: getTickCount(), tick: getTickCount() }

		teardown()

		invoke("", arguments.testCase)
		//teardown()
	}

	public void function teardown() {
		application.progress.append({ currentStep: "teardown", tick: getTickCount() })

		QueryExecute("
			EXEC sp_set_session_context 'noTrigger', 1;
			delete terms_acceptance where program = (select product_id from product where short_title = '2024FSY_#variables.ticketName#')
			EXEC sp_set_session_context 'noTrigger', 0;
		", {}, { datasource: variables.dsn.local } );
		QueryExecute("update pm_counselor set context = null, updated_by = :created_by where context in (select context_id from context where product in (select product_id from product where short_title like '%_#variables.ticketName#') or person in (select person_id from person where first_name = 'First_#variables.ticketName#'))", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete fsy_session_unit where created_by = :created_by", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete pm_session where created_by = :created_by", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete session_preference where created_by = :created_by", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete pm_location where created_by = :created_by", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete event where event_object = 'CONTEXT' and event_object_id in (select context_id from context where person in (select person_id from person where first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#'))", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete context where product in (select product_id from product where short_title like '%_#variables.ticketName#') or person in (select person_id from person where first_name = 'First_#variables.ticketName#')", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete fsy_unit where created_by = :created_by", { created_by: variables.ticket }, { datasource: variables.dsn.local } );
		QueryExecute("delete person where first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#'", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete option_item where section in (select product_id from product where short_title like 'Section_%_#variables.ticketName#')", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete option_group where section in (select product_id from product where short_title like 'Section_%_#variables.ticketName#')", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete product where short_title like '%Housing_%_#variables.ticketName#'", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete product where short_title like 'Section_%_#variables.ticketName#'", {}, { datasource: variables.dsn.local } );
		QueryExecute("delete product where short_title = '2024FSY_#variables.ticketName#'", {}, { datasource: variables.dsn.local } );
	}

	public void function undoPreregAssignments(required numeric program) {
		// this resets what the scheduler does when it runs by deleting all the contexts it created
		// hard-coded, because all the above setup stuff is 1-off w/ a new program and all-new data every time so it's completely independent
		queryExecute("
			delete context where context_id in
			(
				select context.context_id from FSY.DBO.context
					inner join product on product.product_id = context.product
					left join emergency_info ei on ei.context = context.context_id
					left join context housing on housing.choice_for = context.context_id
					left join emergency_info eio on eio.context = context.context_id
				where product.program = :program
					and context.context_type = 'Enrollment'
					and ei.context is null
					and eio.context is null
			)
		", { program: arguments.program}, { datasource: variables.dsn.local });
	}

	public struct function preregSetupResults() {
		local.program = queryExecute("select value from cntl_value where control = 'current_fsy_program'", {}, { datasource: variables.dsn.local }).value

		return {
			programProductID = local.program,
			program = variables.utils.queryToStruct(queryExecute("select * from product where product_id = :product_id", { product_id: local.program }, { datasource: variables.dsn.local }))
		}
	}

	//////////////////////////////////////////////////////////
	// How is FSY regular reg going?
	//////////////////////////////////////////////////////////
	public array function regularRegStats() {
		local.result = [];

		for (local.i = 0; local.i < 24; local.i += 1) {
			local.hourStats = queryExecute("
				DECLARE @now datetime2 = (SELECT SYSDATETIME());
				DECLARE @endHour datetime2 = (SELECT DATETIMEFROMPARTS(YEAR(@now), MONTH(@now), DAY(@now), DATEPART(HOUR, @now), 0, 0, 0))
				SELECT
					COUNT(*) AS total,
					DATEADD(hour, -:hour - 1, (DATEADD(MINUTE, (60 - DATEPART(MINUTE, SYSDATETIME())) % 60, SYSDATETIME()))) AS [hour]
				FROM context
					INNER JOIN product on product.product_id = context.product AND product.master_type = 'Section' AND product.program = :program
				WHERE context.context_type = 'Enrollment'
					AND context.status = 'Active'
					AND context.enroll_date between
						DATEADD(hour, -:hour - 1, (DATEADD(MINUTE, (60 - DATEPART(MINUTE, SYSDATETIME())) % 60, SYSDATETIME()))) AND
						DATEADD(hour, -:hour, (DATEADD(MINUTE, (60 - DATEPART(MINUTE, SYSDATETIME())) % 60, SYSDATETIME())))

			", { program: variables.realProgram, hour: {value: local.i, cfsqltype: "cf_sql_numeric"} }, { datasource: variables.dsn.prod });

			local.result.prepend({ count: local.hourStats.total, hour: local.hourStats.hour });
		}

		return local.result;
	}

	//////////////////////////////////////////////////////////
	// This is the part where we test hiring scheduler
	//////////////////////////////////////////////////////////

	public any function onMissingMethod(string missingMethodName, struct missingMethodArguments) {
		try {
			local.hiringTest = true // metadata blah blah == "hiringTest"
			if (local.hiringTest)
				application.progress = {}

			invoke("", missingMethodName, missingMethodArguments)
			return { pass: true }
		}
		catch (any e) {
			if (local.hiringTest)
				return { pass: false, message: e.message, type: e.type, error: e, progress: application.progress, testName: arguments.missingMethodName }

			rethrow;
		}
	}

	variables.dates = {
		core: '2025-05-12', // 20 training only (for everyone other than CNs; all other trainings are for CNs only)
		week0: '2025-05-18', // 21 - training only
		week1: '2025-05-25', // 22 - first week of regular sessions
		week2: '2025-06-01', // 23
		week3: '2025-06-08', // 24
		week4: '2025-06-15', // 25 - last week of CN trainings (also week of CAN core)
		week5: '2025-06-22', // 26 - week of CAN CN
		week6: '2025-06-29', // 27
		week7: '2025-07-06', // 28
		week8: '2025-07-13', // 29
		week9: '2025-07-20'  // 30
	}

	// Utils/helper functions
	public void function removeAllCandidates() {
		queryExecute("
			DELETE fsy_hiring_scheduler_audit_log where person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE emergency_info WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		QueryExecute("
			update pm_counselor set context = null, updated_by = :created_by
			where context in (select context_id from context where product in (select product_id from product where short_title like '%_#variables.ticketName#')
				or person in (select person_id from person where first_name = 'First_#variables.ticketName#'))
		", { created_by: variables.ticket }, { datasource: variables.dsn.local } );

		queryExecute("
			DELETE context_property WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE availability_week WHERE hires_availability IN (SELECT hires_availability_id FROM hires_availability WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			))
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE hires_availability WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE hiring_info WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE message_box WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type = 'Hired Staff'
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE training_travel WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type IN ('Hired Staff', 'Enrollment')
				)
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE context WHERE context_id IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE (
					context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
					OR context_type IN ('Hired Staff', 'Enrollment')
				)
					AND (#variables.realProgram# IN (product.program, product.product_id) OR #variables.trainingProgram# IN (product.program, product.product_id))
					AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#'
		", {}, { datasource: variables.dsn.local });
	}

	public void function assertCandidatesAssigned(required numeric total) {
		var assigned = queryExecute("
			SELECT COUNT(context_id) AS total
			FROM context
				INNER JOIN product on product = product_id
			WHERE context_type IN (SELECT value FROM cntl_value WHERE control = 'ADULT_CONTEXT_TYPE.STAFF.HIRES')
				AND product.program = #variables.realProgram#
				AND context.status = 'Active'
				AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
		", {}, { datasource: variables.dsn.local });

		if (assigned.total != arguments.total)
			throw(type="assertCandidatesAssigned", message="Expected: #arguments.total# Actual: #assigned.total#");
	}

	public void function assertSessionsAssigned(
		required numeric person_id,
		required array sessions
	) {
		var assigned = ValueArray(
			getModel("fsyDAO").getAssignedSessionsForPerson(arguments.person_id, getModel("fsyDAO").getFSYYear().year),
			"pm_session_id"
		)

		for (item in sessions) {
			if (!assigned.contains(item))
				Throw(type = "assertSessionsAssigned", message = "Expected: #arguments.sessions.ToList()# Actual: #assigned.ToList()#");
		}

		for(item in assigned) {
			if (!sessions.contains(item))
				Throw(type = "assertSessionsAssigned", message = "Expected: #arguments.sessions.ToList()# Actual: #assigned.ToList()#");
		}
	}

	public void function assertCandidatesAssignedTraining(required numeric week, required numeric training_order_in_week) {
		var assigned = queryExecute("
			SELECT COUNT(context_id) AS total
			FROM context
				INNER JOIN product on product = product_id
				INNER JOIN pm_session ON pm_session.product = product.product_id AND pm_session.session_type IN ('FSY Training', 'FSY Core Training')
			WHERE context_type IN ('Enrollment')
				AND product.program = #variables.trainingProgram#
				AND context.status = 'Active'
				AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
				AND DATEPART(WEEK, product.start_date) = :week
				AND pm_session.training_order_in_week = :training_order_in_week
		", arguments, { datasource: variables.dsn.local });

		if (assigned.total != 1)
			throw(type="assertCandidatesAssignedTraining", message="Expected: week #arguments.week#, training_order_in_week #arguments.training_order_in_week# to be assigned");
	}

	public void function assertCandidatesAssignedSpecificSessions(required string sessions) {
		var assigned = queryExecute("
			SELECT pm_session.pm_session_id
			FROM context
				INNER JOIN pm_session ON context.product = pm_session.product
			WHERE context_type IN ('Counselor')
				AND context.status = 'Active'
				AND context.person IN (SELECT person_id FROM person WHERE first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#')
		", { sessions = { value = arguments.sessions, list = true } }, { datasource: variables.dsn.local });

		local.dbSessions = ValueArray(assigned, "pm_session_id")
		ArraySort(local.dbSessions, "numeric")
		local.dbSessions = ListToArray(ArrayToList(local.dbSessions))
		local.checkSessions = ListToArray(arguments.sessions)
		ArraySort(local.checkSessions, "numeric")

		if (!local.dbSessions.equals(local.checkSessions))
			throw(type="assertCandidatesAssignedSpecificSessions", message="Expected: #SerializeJSON(local.checkSessions)# Actual: #SerializeJSON(local.dbSessions)#");
	}

	public any function runScheduler() {
		local.users = getModel("fsyDAO").getAvailableHires(getModel("fsyDAO").getFSYYear().year);
		local.scheduler = getModel("hiringScheduler");

		local.shouldLog = StructKeyExists(application, "log") && application.log.keyExists("hiringScheduler") && application.log.hiringScheduler;
		if (local.shouldLog && fileExists("#ExpandPath("/o3/scratch")#/hiringSchedulerLog.json"))
			fileDelete("#ExpandPath("/o3/scratch")#/hiringSchedulerLog.json");

		return local.scheduler.processUserData(local.users);
	}

	public void function createAssignment(
		required numeric person_id,
		required numeric pm_session_id,
		string context_type,
		string created_by = "FSY-1511"
	) {
		queryExecute("
			insert into context (person, product, context_type, status, created_by)
			values (:person_id, (select product from pm_session where pm_session_id = :pm_session_id), :context_type, 'Active', :created_by)
		", arguments, { datasource: variables.dsn.local })
	}

	public void function createTraining(
		required numeric person_id,
		required numeric pm_session_id,
		string created_by = "FSY-1511"
	) {
		queryExecute("
			insert into context (person, product, context_type, status, created_by)
			values (:person_id, (select product from pm_session where pm_session_id = :pm_session_id), 'Enrollment', 'Active', :created_by)
		", arguments, { datasource: variables.dsn.local, result = "local.section" })

		arguments.context_id = local.section.generatedKey

		queryExecute("
			declare @section numeric(8) = (select product from pm_session where pm_session_id = :pm_session_id);
			declare @gender varchar (32) = (select case when gender = 'F' then 'Female' else 'Male' end from person where person_id = :person_id);

			insert into context (person, product, choice_for, context_type, status, created_by)
			values (:person_id, (
				select item
				from option_item oi
					inner join product housing on housing.product_id = oi.item and housing.option_type = 'Housing'
				where oi.section = @section
					and @gender = housing.housing_type
			), :context_id, 'Enrollment', 'Active', :created_by)
		", arguments, { datasource: variables.dsn.local, result = "local.section" })
	}

	// public void function linkSessions(
	// 	required numeric base_session,
	// 	required numeric linked_session,
	// 	string created_by = "FSY-1511"
	// ) {
	// 	queryExecute("
	// 		insert into fsy_session_link (base_session, linked_session, created_by)
	// 		values (:base_session, :linked_session, :created_by);

	// 		update pm_session set
	// 	", arguments, { datasource: variables.dsn.local })
	// }

	private void function unlinkAllSessions() {
		queryExecute("delete fsy_session_link", {}, { datasource: variables.dsn.local })
	}

	private void function hiringSetup() {
		removeAllCandidates()
		//unlinkAllSessions() // nope, need to use real link data now that we have more complex linking and travel rules
		setPeakWeeks()
		setSessionStaffNeeds(numToSetTo = 10, type = "cn")
		setSessionStaffNeeds(numToSetTo = 10, type = "ac")
		setSessionStaffNeeds(numToSetTo = 10, type = "wc")
		setSessionStaffNeeds(numToSetTo = 10, type = "cd")
	}

	private void function setSessionStaffNeeds(
		required numeric numToSetTo,
		string sessions = "",
		string type = "cn" // cn | ac | wc | cd
	) {
		local.year = getModel("fsyDAO").getFSYYear().year
		if (arguments.sessions == "") {
			//get all the sessions
			local.pmSessions = QueryExecute(
				"select pm_session_id from pm_session where YEAR(start_date) = :year",
				{ year: local.year }, { datasource: variables.dsn.local }
			);
			local.sessions = ValueList(local.pmSessions.pm_session_id);
		} else {
			//use the passed in sessions
			local.sessions = arguments.sessions;
		}

		QueryExecute("
			update pm_session set
				#arguments.type == "cn" ? "cn_male = :numToSetTo," : ""#
				#arguments.type == "ac" ? "ac_male = :numToSetTo," : ""#
				#arguments.type == "wc" ? "wc_male = :numToSetTo," : ""#
				#arguments.type == "cd" ? "cd_male = :numToSetTo," : ""#
				#arguments.type == "cn" ? "cn_female = :numToSetTo," : ""#
				#arguments.type == "ac" ? "ac_female = :numToSetTo," : ""#
				#arguments.type == "wc" ? "wc_female = :numToSetTo," : ""#
				#arguments.type == "cd" ? "cd_female = :numToSetTo," : ""#
				updated_by = :updated_by where pm_session_id in (:sessions)
			",
			{ numToSetTo = arguments.numToSetTo, updated_by = variables.ticket, sessions = { value = local.sessions, list = true }, type: arguments.type },
			{ datasource: variables.dsn.local }
		);
	}

	private void function setPeakWeeks(
		required string sessions = ""
	) {
		QueryExecute("
			update pm_session set peak_week = 'N', updated_by = :updated_by; -- clean slate

			update pm_session
			set
				peak_week = 'Y',
				updated_by = :updated_by
			where pm_session_id in (:sessions)
			",
			{ updated_by: variables.ticket, sessions: { value: arguments.sessions, list: true, null: arguments.sessions == "" } },
			{ datasource: variables.dsn.local }
		);
	}

	private void function setDesirability(
		required string sessions = "",
		required numeric desirability
	) {
		QueryExecute("
			update pm_session
			set
				desirability = :desirability,
				updated_by = :updated_by
			where pm_session_id in (:sessions)
			",
			{ desirability = arguments.desirability, updated_by = variables.ticket, sessions = { value = arguments.sessions, list = true } },
			{ datasource: variables.dsn.local }
		);
	}

	private struct function setupForScheduler(
		required array availability,
		required numeric numWeeksWillWork,
		required string state = "UT"
	) {
		local.program = getProgram()
		application.progress.append({ program: local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id: local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext: local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", arguments.state)
		createAvailability(local.hireContext, arguments.availability, arguments.numWeeksWillWork)

		return { person_id = local.person_id };
	}

	// Tests

	// 1
	private void function testDryRun() hiringTest {
		// no one to assign
		removeAllCandidates()

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testHappyPath() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week1])
		setSessionStaffNeeds(10)

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testACHappyPath() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Assistant Coordinator", "UT")
		createAvailability(local.hireContext, [variables.dates.core, variables.dates.week9], 1)
		setSessionStaffNeeds(0, "", "ac")
		setSessionStaffNeeds(1, "#variables.sessions.or_monmouth_02#", "ac")

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTrainingAlreadyAssignedCN() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week1])
		createTraining(local.person_id, variables.sessions.cn_0A);
		setSessionStaffNeeds(10)

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTrainingAlreadyAssignedAC() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Assistant Coordinator", "UT")
		createAvailability(local.hireContext, [variables.dates.core, variables.dates.week1])
		createTraining(local.person_id, variables.sessions.core);
		setSessionStaffNeeds(10)

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testAlreadyAssignedOneLinkedSession() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.program = local.program
		local.person_id = createPerson("M")
		application.progress.person_id = local.person_id
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4], 4)
		createAssignment(local.person_id, #variables.sessions.tx_denton_01#, "Counselor")
		//linkSessions(#variables.sessions.tx_denton_01#, #variables.sessions.tx_denton_02#)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.tx_denton_01#,#variables.sessions.tx_denton_02#")

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testCanadaSameProvince() hiringTest {
		// This test covers 2 cases because the first (Test 2) passing implies the other (Test 1) passing as well

		// Test 2
		// - Alberta followed by Alberta
		// - only sessions available are 2 back-to-back Alberta sessions
		// - outcome
		// 	- person is assigned both sessions

		// Test 1
		// - residence: Alberta -> assignment: Alberta
		// - residency is Alberta
		// - only session available is Alberta
		// - outcome
		// 	- person is assigned

		hiringSetup()

		local.program = getProgram()
		application.progress.program = local.program
		local.person_id = createPerson("M")
		application.progress.person_id = local.person_id
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "AB", "CAN")
		createAvailability(local.hireContext, [variables.dates.week5, variables.dates.week6, variables.dates.week7], 2)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ab_calgary_01#,#variables.sessions.ab_calgary_02#")

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testTrainingTravelNull() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2], 1)

		runScheduler()
		assertCandidatesAssigned(1)
		assertCandidatesAssignedTraining(22, 1)
	}

	private void function testTrainingTravelUtah() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2], 1)
		createTrainingTravel(local.hireContext);

		runScheduler()
		assertCandidatesAssigned(1)
		assertCandidatesAssignedTraining(22, 1)
	}

	private void function testTrainingTravelFarFarAway() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2], 1)
		createTrainingTravel(local.hireContext, "CA");

		runScheduler()
		assertCandidatesAssigned(1)
		assertCandidatesAssignedTraining(22, 2)
	}

	// 11
	private void function testTrainingClosestToFirstSession() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2, variables.dates.week3], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.tx_denton_02#")

		runScheduler()
		assertCandidatesAssigned(1)
		assertCandidatesAssignedTraining(23, 2)
	}

	private void function testResidenceUtah() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_02A#")

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testResidenceOregon() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "OR")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week9], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.or_monmouth_02#")

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testResidenceUtahToOregon() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week9], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.or_monmouth_02#")

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTravelBalanceLocalOnly() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4], 3)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#")

		runScheduler()
		assertCandidatesAssigned(3)
	}

	private void function testTravelBalanceTravelOnly() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week9], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.or_monmouth_02#")

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTravelBalanceHappyPath() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0,
			variables.dates.week1,
			variables.dates.week2,
			variables.dates.week3,
			variables.dates.week4,
			variables.dates.week5,
			variables.dates.week6,
			variables.dates.week7,
			variables.dates.week8
		], 8)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_01a#) // Provo 01A - week 1
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_02A#) // Provo 02A - week 2
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_03A#) // Provo 03A - week 3
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_04A#) // Provo 04A - week 4
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_05a#) // Provo 05A - week 5
		setSessionStaffNeeds(1, #variables.sessions.az_thatcher_06#) // AZ Thatcher 06 - week 6
		setSessionStaffNeeds(1, #variables.sessions.mn_st_joseph#) // MN St Joseph - week 7
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_08a#) // Provo 08A - week 8

		runScheduler()
		assertCandidatesAssigned(6)
		assertSessionsAssigned(local.person_id, [
			variables.sessions.ut_provo_01a,
			variables.sessions.ut_provo_03A,
			variables.sessions.ut_provo_04A,
			variables.sessions.ut_provo_05a,
			variables.sessions.az_thatcher_06,
			variables.sessions.ut_provo_08a
		])
	}

	private void function testTravelBalanceSadPath() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0,
			variables.dates.week1,
			variables.dates.week2,
			variables.dates.week3,
			variables.dates.week4,
			variables.dates.week5,
			variables.dates.week6,
			variables.dates.week7
		], 4)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_01a#) // Provo 01A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_02A#) // Provo 02A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_03A#) // Provo 03A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_04A#) // Provo 04A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_05a#) // Provo 05A
		setSessionStaffNeeds(1, #variables.sessions.az_thatcher_06#) // AZ Thatcher 06
		setSessionStaffNeeds(1, #variables.sessions.mn_st_joseph#) // MN St Joseph

		runScheduler()
		assertCandidatesAssigned(4)
		assertSessionsAssigned(local.person_id, [
			variables.sessions.ut_provo_01A,
			variables.sessions.ut_provo_03a,
			variables.sessions.ut_provo_05a,
			variables.sessions.az_thatcher_06
		])
	}

	private void function testTravelUnbalancedButAssigned() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0,
			variables.dates.week2,
			variables.dates.week3,
			variables.dates.week4,
			variables.dates.week5,
			variables.dates.week6
		], 4)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_02A#) // Provo 02A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_03A#) // Provo 03A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_04A#) // Provo 04A
		setSessionStaffNeeds(1, #variables.sessions.ut_provo_05a#) // Provo 05A
		setSessionStaffNeeds(1, #variables.sessions.az_thatcher_06#) // AZ Thatcher 06

		runScheduler()
		assertCandidatesAssigned(4)
		assertSessionsAssigned(local.person_id, [
			variables.sessions.az_thatcher_06,
			variables.sessions.ut_provo_04A,
			variables.sessions.ut_provo_03A,
			variables.sessions.ut_provo_05a
		])
	}

	private void function testBackToBack_Local_Travel() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week8, variables.dates.week9 ], 2)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_08A#")
		setSessionStaffNeeds(1, "#variables.sessions.vt_castleton#") // FSY VT Castleton - week9

		runScheduler()
		assertCandidatesAssigned(2)
	}

	// 21
	private void function testBackToBack_Travel_Travel() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week6, variables.dates.week7 ], 2)
		// travel week 2, travel week 3
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.az_thatcher_06#") // week 6
		setSessionStaffNeeds(1, "#variables.sessions.az_flagstaff_03#") // week 7

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testBackToBack_Local_Travel_Travel() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4 ], 3)
		createAssignment(local.person_id, #variables.sessions.ut_provo_02A#, "Counselor")
		createAssignment(local.person_id, #variables.sessions.va_buena_vista_01#, "Counselor") //FSY VA Buena Vista 01 - 2024-06-09 - week3
		// local week 2, travel week 3, travel week 4
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_02#")

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testBackToBack_Travel_Travel_Local() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4 ], 3)
		createAssignment(local.person_id, #variables.sessions.va_buena_vista_01#, "Counselor") //FSY VA Buena Vista 01 - 2024-06-09 - week3
		createAssignment(local.person_id, #variables.sessions.ut_provo_04A#, "Counselor")
		// travel week 2, travel week 3, local week 4
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.co_colorado_springs_01#")

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testBackToBack_Travel_Local_Travel_After() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 ], 3)
		createAssignment(local.person_id, #variables.sessions.ut_cedar_city_01#, "Counselor") // week 22
		createAssignment(local.person_id, #variables.sessions.ut_st_george_02#, "Counselor") // week 23
		// travel week 1, local week 2, travel week 3
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.az_thatcher_03#") // week 24

		runScheduler()
		assertCandidatesAssigned(3)
	}

	private void function testBackToBack_Travel_Local_Travel_Before() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 ], 3)
		createAssignment(local.person_id, #variables.sessions.ut_st_george_02#, "Counselor")
		createAssignment(local.person_id, #variables.sessions.az_thatcher_03#, "Counselor")
		// travel week 1, local week 2, travel week 3
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_cedar_city_01#")

		runScheduler()
		assertCandidatesAssigned(3)
	}

	private void function testAlreadyAssignedOneAvailOneLinked() hiringTest {
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 1
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.tx_denton_01#,#variables.sessions.tx_denton_02#"
		local.sessionsArray = ListToArray(local.sessions)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		//linkSessions(local.sessionsArray[1], local.sessionsArray[2])

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testResidenceUSAtoCAN() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, 'Counselor', 'UT')
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week9], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, '#variables.sessions.ab_calgary_01#')

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testResidenceCANtoUSA() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(
				local.hireContext,
				'Counselor',
				'ON',
				'CAN'
		)
		createAvailability(local.hireContext, [variables.dates.week1, variables.dates.week9], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, '#variables.sessions.az_tempe_01#')

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testAvailable6ConsecutiveWeeksWork5Break() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson('M')
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(
				local.hireContext,
				[
						variables.dates.week0,
						variables.dates.week1,
						variables.dates.week2,
						variables.dates.week3,
						variables.dates.week4,
						variables.dates.week5,
						variables.dates.week6
				],
				6
		)
		setSessionStaffNeeds(10)

		runScheduler()
		assertCandidatesAssigned(5)
	}

	private void function testAvailable7ConsecutiveWeeksWork5BreakWork1() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson('M')
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(
				local.hireContext,
				[
						variables.dates.week0,
						variables.dates.week1,
						variables.dates.week2,
						variables.dates.week3,
						variables.dates.week4,
						variables.dates.week5,
						variables.dates.week6,
						variables.dates.week7
				],
				6
		)
		setSessionStaffNeeds(10)

		runScheduler()
		assertCandidatesAssigned(6)
	}

	// 31
	private void function testRespectPlaceTime() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(
				local.hireContext,
				[
						variables.dates.week1,
						variables.dates.week2,
						variables.dates.week3,
						variables.dates.week4,
						variables.dates.week5,
						variables.dates.week6
				],
				1
		)
		local.hiresAvailabilityObject = getModel('baseObject')
				.setPrimaryKey('context', local.hireContext)
				.load('Hires_Availability');
		local.hiresAvailabilityObject.setValue('pm_location', 38);
		local.hiresAvailabilityObject.setValue('start_date', '2024-06-09');
		local.hiresAvailabilityObject.write();
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(2, '#variables.sessions.ut_ephraim_03B#')
		setSessionStaffNeeds(1, '#variables.sessions.ut_logan_02#')
		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testCanWorkTravelLinkConsecutiveWeeks() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week1, variables.dates.week2], 2)
		local.sessions = '#variables.sessions.az_prescott_01#,#variables.sessions.az_prescott_02#' // AZ Prescott 01/02
		local.sessionsArray = listToArray(local.sessions)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		//linkSessions(local.sessionsArray[1], local.sessionsArray[2])


		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testCanWork1TravelIn2ConsecutiveWeeksUnlinked() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week3, variables.dates.week4], 2)
		local.sessions = '#variables.sessions.az_thatcher_03#,#variables.sessions.fl_deland_01#' // weeks 24, 25
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)


		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testCanWorkUnlinkedNotTravelConsecutiveWeeks() hiringTest {
		hiringSetup()

		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson('M')
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, 'Counselor')
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week1, variables.dates.week2], 2)
		local.sessions = '#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_02A#' // Provo 01/02
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)


		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testLinkedSessions_1Local_2TravelLinked() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 ], 2)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, variables.sessions.ut_ephraim_01A) // local session
		setSessionStaffNeeds(1, variables.sessions.co_colorado_springs_01) // linked travel session week 2
		setSessionStaffNeeds(1, variables.sessions.co_colorado_springs_02) // linked travel session week 3

		runScheduler()
		assertCandidatesAssigned(2) // we said desired session count is 2, so we maximize their assignment by giving them the 2 linked rather than the 1 local and then nothing else
		assertSessionsAssigned(local.person_id, [ variables.sessions.co_colorado_springs_01, variables.sessions.co_colorado_springs_02 ])
	}

	private void function testLinkedSessions_3Travel2Linked_WillWork4_available3() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })

		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		createAssignment(local.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1

		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 , variables.dates.week4], local.numWeeksWillWork)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, variables.sessions.ut_cedar_city_02) // week2 (honestly not sure what the "available3" part of this test function's name means)
		setSessionStaffNeeds(1, variables.sessions.ca_rohnert_park_01) // week3
		setSessionStaffNeeds(1, variables.sessions.ca_rohnert_park_02) // week4

		runScheduler()
		assertSessionsAssigned(local.person_id, [
			variables.sessions.ut_provo_01a,
			variables.sessions.ut_cedar_city_02,
			variables.sessions.ca_rohnert_park_01,
			variables.sessions.ca_rohnert_park_02
		])
	}

	private void function testLinkedSessions_3Travel2Linked_WillWork4_available2() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })

		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		createAssignment(local.person_id, variables.sessions.ut_provo_01a, "Counselor") // week 1
		createAssignment(local.person_id, variables.sessions.ut_provo_05b, "Counselor") // week 5

		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 , variables.dates.week4, variables.dates.week5], local.numWeeksWillWork)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_logan_01#") // week2
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_01#") // week3
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_02#") // week4

		runScheduler()
		assertSessionsAssigned(local.person_id, [
			variables.sessions.ut_provo_01a,
			variables.sessions.ut_provo_05b,
			variables.sessions.ca_rohnert_park_01,
			variables.sessions.ca_rohnert_park_02
		])
	}

	private void function testLinkedSessions_3Travel2Linked_WillWork4_available1() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })

		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		createAssignment(local.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.person_id, #variables.sessions.ut_provo_05b#, "Counselor") // week 5
		createAssignment(local.person_id, #variables.sessions.ut_orem_02#, "Counselor") // week 6

		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3 , variables.dates.week4, variables.dates.week5, variables.dates.week6], local.numWeeksWillWork)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_logan_01#") // week2
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_01#") // week3
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_02#") // week4

		runScheduler()
		assertSessionsAssigned(local.person_id, [
			variables.sessions.ut_provo_01a,
			variables.sessions.ut_provo_05b,
			variables.sessions.ut_orem_02,
			variables.sessions.ut_logan_01
			])
	}

	private void function testLinkedSessions_3Linked() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week2, variables.dates.week3, variables.dates.week4 ], 3)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.co_colorado_springs_01#")
		setSessionStaffNeeds(1, "#variables.sessions.va_buena_vista_01#") //FSY VA Buena Vista 01 - 2024-06-09 - week3
		setSessionStaffNeeds(1, "#variables.sessions.va_buena_vista_02#") //FSY VA Buena Vista 02 - 2024-06-16 - week4
		//linkSessions(#variables.sessions.va_buena_vista_02#, #variables.sessions.co_colorado_springs_01#)
		//linkSessions(#variables.sessions.va_buena_vista_02#, #variables.sessions.va_buena_vista_01#)

		runScheduler()
		assertCandidatesAssigned(3)
		assertSessionsAssigned(local.person_id, [ #variables.sessions.va_buena_vista_02#, #variables.sessions.co_colorado_springs_01#, #variables.sessions.va_buena_vista_01# ])
	}

	private void function testLinkedSessions_2Linked_OnlyAvailable1Week() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week1 ], 1)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.co_colorado_springs_01#")
		setSessionStaffNeeds(1, "#variables.sessions.va_buena_vista_01#") //FSY VA Buena Vista 01 - 2024-06-09 - week3
		//linkSessions(#variables.sessions.co_colorado_springs_01#, #variables.sessions.va_buena_vista_01#)

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testPeakWeeks() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week0, variables.dates.week2, variables.dates.week3 ], 1)
		setPeakWeeks(#variables.sessions.ut_provo_03A#)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_02A#")
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_03A#") // marked as peak week

		runScheduler()
		assertCandidatesAssigned(1)
		assertSessionsAssigned(local.person_id, [ #variables.sessions.ut_provo_03A# ])
	}

	private void function testCAFirst_only_CA() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week4 ], 1)
		// CA week 4
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_02#")

		runScheduler()
		assertCandidatesAssigned(0)
	}

	// 41
	private void function testCAFirst_1Local_2CA() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week3, variables.dates.week4 ], 2)
		// CA week 3, local week 3, CA week 4
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_01#")
		setSessionStaffNeeds(1, "#variables.sessions.ut_provo_03b#")
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_02#")

		runScheduler()
		assertCandidatesAssigned(2)
		assertSessionsAssigned(local.person_id, [ #variables.sessions.ut_provo_03b#, #variables.sessions.ca_rohnert_park_02# ])
	}

	private void function testCAFirst_1CA_1LocalAlreadyAssigned() hiringTest {
		hiringSetup()

		local.program = getProgram()
		application.progress.append({ program = local.program })
		local.person_id = createPerson("M")
		application.progress.append({ person_id = local.person_id })
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.append({ hireContext = local.hireContext })
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [ variables.dates.week1, variables.dates.week3, variables.dates.week4 ], 2)
		createAssignment(local.person_id, #variables.sessions.ut_provo_04A#, "Counselor")
		// CA week 3, local week 4
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(1, "#variables.sessions.ca_rohnert_park_01#")

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTwoAvailSameWeek() hiringTest {
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 2
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_01b#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTwoAvailNotLinkedNotLocal() hiringTest {
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 2
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.tx_denton_01#,#variables.sessions.tx_denton_02#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)

		runScheduler()
		assertCandidatesAssigned(1)
	}

	private void function testTwoAvailLocal() hiringTest {
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 2
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_02A#"
		setSessionStaffNeeds(10, local.sessions)

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testTwoAvailLinkedNotLocal() hiringTest {
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 2
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.tx_denton_01#,#variables.sessions.tx_denton_02#"
		local.sessionsArray = ListToArray(local.sessions)
		setSessionStaffNeeds(10, local.sessions)
		//linkSessions(local.sessionsArray[1], local.sessionsArray[2])

		runScheduler()
		assertCandidatesAssigned(2)
	}

	private void function testTwoAvailLinkedWAIsWAResident() hiringTest { //in this test, the linked sessions are WA and the counselor is a resident of WA: should be assigned 0
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week8, variables.dates.week9]
		local.numWeeksWillWork = 2
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork, "WA")

		local.sessions = "#variables.sessions.id_caldwell_01#,#variables.sessions.wa_seattle_01#"
		local.sessionsArray = ListToArray(local.sessions)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		//linkSessions(local.sessionsArray[1], local.sessionsArray[2])

		runScheduler()
		assertCandidatesAssigned(0)
	}

	private void function testOneAvailPeakWeek() hiringTest { //with three sessions (one a peak week), gets assigned the peak week
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3]
		local.numWeeksWillWork = 1
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)

		local.sessions = "#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_02A#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setPeakWeeks("#variables.sessions.ut_provo_02A#")

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_02A#")
	}

	private void function testDesirabilityNeutralThreeOptions() hiringTest { //with three sessions (0, -1, 1), gets assigned desirability of 0
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", 0)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_provo_02c#" // all week 2
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", -1)
		setDesirability("#variables.sessions.ut_provo_02b#", 0)
		setDesirability("#variables.sessions.ut_provo_02c#", 1)

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_02b#")
	}

	private void function testDesirabilityPositiveThreeOptions() hiringTest { //with three sessions (0, -1, 1), gets assigned desirability of -1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", 1)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_provo_02c#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", -1)
		setDesirability("#variables.sessions.ut_provo_02b#", 0)
		setDesirability("#variables.sessions.ut_provo_02c#", 1)

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_02A#")
	}

	// 51
	private void function testDesirabilityNegativeThreeOptions() hiringTest { //with three sessions (0, -1, 1), gets assigned desirability of 1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", -1)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_provo_02c#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", -1) // week 2
		setDesirability("#variables.sessions.ut_provo_02b#", 0) // week 2
		setDesirability("#variables.sessions.ut_provo_02c#", 1) // week 2

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_02c#")
	}

	/*
		// we are not going to worry about this one; it is a corner case and half the time, it'll be fixed on the next week assigned them
		private void function testOneAvailDesirabilityNeutralTwoOptions() hiringTest { //with two sessions (-1, 1), gets assigned desirability of ????
			hiringSetup()

			local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2]
			local.numWeeksAvailable = 1
			local.return = setupForScheduler(local.availableWeeks, local.numWeeksAvailable)

			setDesirability("10001304", 0)
			createAssignment(local.return.person_id, 10001304, "Counselor")
			local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02c#"
			setSessionStaffNeeds(0)
			setSessionStaffNeeds(10, local.sessions)
			setDesirability("#variables.sessions.ut_provo_02A#", -1)
			setDesirability("#variables.sessions.ut_provo_02c#", 1)

			runScheduler()
			assertCandidatesAssignedSpecificSessions("10001304,#variables.sessions.ut_provo_02b#")
		}
	*/

	private void function testDesirabilityPositiveTwoOptions() hiringTest { //with two sessions (0, 1), gets assigned desirability of 0
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", 1)

		local.sessions = "#variables.sessions.ut_provo_02b#,#variables.sessions.ut_provo_02c#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02b#", 0)
		setDesirability("#variables.sessions.ut_provo_02c#", 1)

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_02b#")
	}

	private void function testDesirabilityNegativeTwoOptions() hiringTest { //with two sessions (0, -1), gets assigned desirability of 1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", -1)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", -1)
		setDesirability("#variables.sessions.ut_provo_02b#", 0)

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_02b#")
	}

	private void function testCoordinator() hiringTest {
		removeAllCandidates()
		// one person to assign
		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Coordinator", "UT")
		createAvailability(local.hireContext, [variables.dates.core, variables.dates.week1])
		setSessionStaffNeeds(1, "", "cd")

		runScheduler()
		assertCandidatesAssigned(1, "Coordinator")
	}

	private void function testDesirabilityNegativeSubsequentWeeks() hiringTest { //with two sessions (0, -1), gets assigned desirability of 1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4, variables.dates.week5]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", -1)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_orem_01#,#variables.sessions.ut_provo_05a#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", -1) //week 2
		setDesirability("#variables.sessions.ut_provo_02b#", -1) //week 2
		setDesirability("#variables.sessions.ut_orem_01#", 0) //week 5
		setDesirability("#variables.sessions.ut_provo_05a#", 0) //week 5

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_orem_01#")
	}

	private void function testDesirabilityPositiveSubsequentWeeks() hiringTest { //with two sessions (0, -1), gets assigned desirability of 1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4, variables.dates.week5]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", 1)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_orem_01#,#variables.sessions.ut_provo_05a#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", 1) //week 2
		setDesirability("#variables.sessions.ut_provo_02b#", 1) //week 2
		setDesirability("#variables.sessions.ut_orem_01#", 0) //week 5
		setDesirability("#variables.sessions.ut_provo_05a#", 0) //week 5

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_orem_01#")
	}

	private void function testDesirabilityNeutralSubsequentWeeks() hiringTest { //with two sessions (0, -1), gets assigned desirability of 1
		hiringSetup()

		local.availableWeeks = [variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4, variables.dates.week5, variables.dates.week6]
		local.numWeeksWillWork = 4 // 4+ so we don't get assigned peak weeks which trumps desirability
		local.return = setupForScheduler(local.availableWeeks, local.numWeeksWillWork)
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_01a#, "Counselor") // week 1
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_03A#, "Counselor") // week 3
		createAssignment(local.return.person_id, #variables.sessions.ut_provo_04A#, "Counselor") // week 4
		setDesirability("#variables.sessions.ut_provo_01a#", 0)
		setDesirability("#variables.sessions.ut_provo_03A#", 0)
		setDesirability("#variables.sessions.ut_provo_04A#", 0)

		local.sessions = "#variables.sessions.ut_provo_02A#,#variables.sessions.ut_provo_02b#,#variables.sessions.ut_orem_01#,#variables.sessions.ut_provo_05a#,#variables.sessions.ut_provo_06b#,#variables.sessions.ut_provo_06c#"
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, local.sessions)
		setDesirability("#variables.sessions.ut_provo_02A#", 1) //week 2
		setDesirability("#variables.sessions.ut_provo_02b#", 1) //week 2
		setDesirability("#variables.sessions.ut_orem_01#", -1) //week 5
		setDesirability("#variables.sessions.ut_provo_05a#", -1) //week 5
		setDesirability("#variables.sessions.ut_provo_06b#", 0) //week 6
		setDesirability("#variables.sessions.ut_provo_06c#", 0) //week 6

		runScheduler()
		assertCandidatesAssignedSpecificSessions("#variables.sessions.ut_provo_01a#,#variables.sessions.ut_provo_03A#,#variables.sessions.ut_provo_04A#,#variables.sessions.ut_provo_06b#")
	}

	private void function testTwoLinkedAreTravelAdjacent() hiringTest {
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week5, variables.dates.week6, variables.dates.week7, variables.dates.week8], 4)
		//linkSessions(variables.sessions.az_flagstaff_03, variables.sessions.az_flagstaff_04A)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")

		runScheduler()
		assertCandidatesAssigned(2)
		assertCandidatesAssignedSpecificSessions("#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")
	}

	private void function testAssignedOneLinkedOtherIsTravelAdjacent() hiringTest { // Gary said don't assign them the other linked one in this case (they broke the rule already; don't fix their decision by breaking a different rule)
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week5, variables.dates.week6, variables.dates.week7, variables.dates.week8], 4)
		createAssignment(local.person_id, variables.sessions.tx_san_antonio_01, "Counselor")
		//linkSessions(variables.sessions.az_flagstaff_03, variables.sessions.az_flagstaff_04A)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")

		runScheduler()
		assertCandidatesAssigned(1)
		assertCandidatesAssignedSpecificSessions("#variables.sessions.tx_san_antonio_01#")
	}

	private void function testAssignedTwoLinkedOfThreeWithMiddleUnassigned() hiringTest {
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week5, variables.dates.week6, variables.dates.week7, variables.dates.week8], 4)
		createAssignment(local.person_id, variables.sessions.tx_san_antonio_01, "Counselor")
		createAssignment(local.person_id, variables.sessions.az_flagstaff_04A, "Counselor")
		//linkSessions(variables.sessions.az_flagstaff_03, variables.sessions.tx_san_antonio_01)
		//linkSessions(variables.sessions.az_flagstaff_03, variables.sessions.az_flagstaff_04A)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")

		runScheduler()
		assertCandidatesAssigned(3)
		assertCandidatesAssignedSpecificSessions("#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")
	}

	// 61
	private void function testAssignedOneLinkedOneUnlinkedWithMiddleUnassignedLinkedToAnAssigned() hiringTest { // Gary said don't assign them the other linked one in this case (they broke the rule already; don't fix their decision by breaking a different rule)
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.week5, variables.dates.week6, variables.dates.week7, variables.dates.week8], 4)
		createAssignment(local.person_id, variables.sessions.tx_san_antonio_01, "Counselor")
		createAssignment(local.person_id, variables.sessions.az_flagstaff_04A, "Counselor")
		//linkSessions(variables.sessions.az_flagstaff_03, variables.sessions.az_flagstaff_04A)
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_03#,#variables.sessions.az_flagstaff_04A#")

		runScheduler()
		assertCandidatesAssigned(2)
		assertCandidatesAssignedSpecificSessions("#variables.sessions.tx_san_antonio_01#,#variables.sessions.az_flagstaff_04A#")
	}

	private void function testTrainingWeirdoProdIssue() hiringTest {
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0, variables.dates.week1, variables.dates.week2, variables.dates.week3, variables.dates.week4,
			variables.dates.week5, variables.dates.week6, variables.dates.week7, variables.dates.week8
		], 8, 24, "2024-06-16")

		runScheduler()
		assertCandidatesAssigned(7)
	}

	private void function testAlreadyAssignedNoAutoAssignSession() hiringTest {
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0, variables.dates.week2, variables.dates.week3, variables.dates.week4, variables.dates.week5
		], 4)
		createAssignment(local.person_id, variables.sessions.az_tucson_02_es, "Counselor")
		queryExecute("update pm_session set no_auto_assign = 'Y', updated_by = '#variables.ticket#' where pm_session_id = #variables.sessions.az_tucson_02_es#", {}, { datasource: variables.dsn.local });
		setSessionStaffNeeds(0)
		setSessionStaffNeeds(10, "#variables.sessions.ut_provo_02b#,#variables.sessions.ut_provo_04A#")

		runScheduler()
		assertCandidatesAssigned(3)
	}

	private void function testPreferPeakWeeks() hiringTest {
		hiringSetup()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		application.progress.hireContext = local.hireContext
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [
			variables.dates.week0, variables.dates.week2, variables.dates.week3, variables.dates.week4, variables.dates.week5
		], 1)
		setSessionStaffNeeds(10)
		setPeakWeeks(#variables.sessions.ut_provo_05a#)

		runScheduler()
		assertCandidatesAssignedSpecificSessions(#variables.sessions.ut_provo_05a#)
	}

	// Stuff for ds-epic-vite app
	private array function simplifyTagContext(required array tags) {
		local.result = []

		for (local.item in arguments.tags) {
			local.isScratch = len(local.item.template) >= 27 && left(local.item.template, 27) == "/app/o3/scratch/scratchcode"
			local.isFSY = !local.isScratch && len(local.item.template) >= 8 && left(local.item.template, 8) == "/app/o3/"
			local.isColdbox = len(local.item.template) >= 13 && left(local.item.template, 13) == "/app/coldbox/"
			local.isOther = !local.isScratch && !local.isFSY && !local.isColdbox

			local.fn = ""
			if (local.item.keyExists("raw_trace")) {
				local.found = local.item.raw_trace.reFindNoCase("\$func(.*?)\.runFunction\(", 1, true, "all");
				application.aaa = {
					found: local.found,
					raw_trace: local.item.raw_trace
				}
				if (arrayLen(local.found) > 0 && local.found[1].pos[1] > 0) local.fn = local.found[1].match[2]
			}

			local.result.append({
				"line": local.item.line,
				"type": local.item.type,
				"file": local.item.template,
				"function": local.fn
			})
		}

		return local.result
	}

	public struct function execCode(required string code, boolean addCfOutput=false, boolean addCfScript=true) {
		//  all scripts run in the scope of this method, so local variables could conflict.
		local.scratchFile = GetTempFile("#ExpandPath(".")#/scratch", "scratchCode");
		//  creates file with .tmp extension
		FileMove(local.scratchFile, local.scratchFile & ".cfm");
		//  change extension to cfm so secure profile will compile and run code
		if ( arguments.addCfScript && !Find("<cf$cript>", arguments.code) ) {
			/*
					If requested, wrap with CFSCRIPT tag (this is strictly for convenience), add a new line after code in case the last line is a comment
				*/
			arguments.code = "<cfscript>#arguments.code##Chr(13)##Chr(10)#</cfscript>";
		}
		if ( arguments.addCfOutput && !Find("<cfoutput>", arguments.code) ) {
			//  If requested, wrap with CFOUTPUT tag (this is strictly for convenience)
			arguments.code = "<cfoutput>#arguments.code#</cfoutput>";
		}
		cffile( output=ReplaceNoCase(arguments.code, "$cript", "script", "all"), file="#local.scratchFile#.cfm", action="write" );
		/*
				Restore script tags
			*/
		local.scratchReturnStruct = { "view": "" };
		local.scratchStart = GetTickCount();
		try {
			savecontent variable="local.scratchReturnStruct.view" {
				cfoutput() {
					//  Needed to show any HTML code generated
					include "../../../scratch/#GetFileFromPath(local.scratchFile)#.cfm";
					// relative from o3/internal/cfc/remote (localtion of this file)
				}
			}
		}
		catch (any e) {
			local.scratchReturnStruct[ "view" ] = serializeJSON({
				"error": true,
				"message": e.message,
				"type": e.type,
				"path": simplifyTagContext(e.tagContext)
			})
			savecontent variable="local.scratchReturnStruct.cf" {
				cfoutput() {
					writeDump(e);
				}
			}
		}

		if (isJSON(local.scratchReturnStruct.view)) {
			local.scratchReturnStruct[ "type" ] = "json"
			local.scratchReturnStruct[ "view" ] = deserializeJSON(local.scratchReturnStruct.view) // but just return it raw, not serialized since we'll serialize the whole thing
		}
		else {
			local.scratchReturnStruct[ "type" ] = "html"
			if (local.scratchReturnStruct.view == "") local.scratchReturnStruct[ "view" ] = "[Completed. The output was empty, like a ghost town.]"
		}


		local.scratchTime = CreateTimespan(0, 0, 0, (GetTickCount() - local.scratchStart) / 1000);
		cffile( file="#local.scratchFile#.cfm", action="delete" );
		local.scratchReturnStruct[ "completed" ] = "#DateFormat(Now(), "short")# #TimeFormat(Now(), "medium")#";
		local.scratchReturnStruct[ "duration" ] = "#Int(local.scratchTime)#, #TimeFormat(local.scratchTime, "H:nn:ss")#";
		return local.scratchReturnStruct;
	}

}
