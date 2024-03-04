component threadSafe extends="o3.internal.cfc.model" {
	property name="injector" inject="wirebox";

	variables.dsn = { prod = "fsyweb_pro", dev = "fsyweb_dev", local = "fsyweb_local" };

	variables.dsn.scheduler = variables.dsn.local
	variables.dsn.prereg = variables.dsn.prod
	variables.realProgram = 80000082
	variables.ticket = "FSY-1511"
	variables.ticketName = reReplace(variables.ticket, "-", "_", "all")

	public query function countStarted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as started from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
		",
			{},
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
		);
	}

	public query function countCompleted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as completed from FSY.DBO.event where event_type = 'preRegReceived'
		",
			{},
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
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
			{ datasource = variables.dsn.prereg }
		);
	}

	public struct function dataOverTime() {
		local.range = QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			SELECT prereg_start, sysdatetime() as now from product where product_id = @program
		",
			{},
			{ datasource = variables.dsn.prereg }
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
				{ datasource = variables.dsn.prereg }
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
				{ datasource = variables.dsn.prereg }
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
				{ datasource = variables.dsn.prereg }
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
				{ datasource = variables.dsn.prereg }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
			)
		);

		// FIXME: code these here and put UI up for them
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
				datasource = variables.dsn.local,
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
			{ datasource = variables.dsn.local }
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
			{ datasource = variables.dsn.local }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
		);

		if (arguments.prereg_link == "")
			QueryExecute(
				"
				update context set prereg_link = :prereg_link, updated_by = :created_by where context_id = :context_id
			",
				{ prereg_link = "my#local.result.generatedkey#", context_id = local.result.generatedkey,
				created_by = variables.ticket },
				{ datasource = variables.dsn.local }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			insert into hiring_info (context, application_type, hired_position, interview_score, state, country, created_by)
			values (:context, 'FSY', :hired_position, 9, :state, :country, :created_by)
		",
			{
				context = arguments.context,
				hired_position = arguments.hired_position,
				state = arguments.state,
				country = arguments.country,
				created_by = variables.ticket
			},
			{ datasource = variables.dsn.local, result = "local.result" }
		);

		return local.result
	}

	private void function createAvailability(
		required numeric context,
		required array weeksAvailable,
		numeric number_of_weeks = 1
	) {
		application.progress.append({ currentStep: "createAvailability", tick: getTickCount() })

		QueryExecute(
			"
			insert into hires_availability (context, number_of_weeks, created_by)
			values (:context, :number_of_weeks, :created_by)
		",
			{
				context: arguments.context,
				number_of_weeks: arguments.number_of_weeks,
				created_by = variables.ticket
			},
			{ datasource = variables.dsn.local, result = "local.result" }
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
				{ datasource = variables.dsn.local, result = "local.result" }
			);
		}

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
			{ datasource = variables.dsn.local }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
		}, { datasource = variables.dsn.local });

		local.args = Duplicate(arguments)
		local.args.created_by = variables.ticket
		if (local.joinCheck.recordCount == 0)
		QueryExecute(
			"
			insert into session_preference (program, prereg_link, pm_location, start_date, priority, created_by)
			values (:program, :prereg_link, :pm_location, :start_date, :priority, :created_by)
		",
			local.args,
			{ datasource = variables.dsn.local }
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
			{ datasource = variables.dsn.local }
		);

		QueryExecute(
			"
			insert into fsy_unit (unit_number, name, [type], parent, created_by)
			values (:unit_number, :name, 'Ward', :parent, :created_by)
		",
			{ unit_number = local.next.unit_number, parent = arguments.stake, name = "ward_#local.next.unit_number#_variables.ticket",
				created_by = variables.ticket },
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local }
		);

		QueryExecute(
			// Utah American Fork Area Coordinating Council
			"
			insert into fsy_unit (unit_number, name, [type], parent, created_by)
			values (:unit_number, :name, 'Stake', 466344, :created_by)
		",
			{ unit_number = local.next.unit_number, name = "stake_#local.next.unit_number#_#variables.ticket#",
				created_by = variables.ticket },
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.result" }
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
			{ datasource = variables.dsn.local, result = "local.section" }
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
			{ datasource = variables.dsn.local, result = "local.housing" }
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
		}, { datasource = variables.dsn.local });
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

	private void function teardown() {
		application.progress.append({ currentStep: "teardown", tick: getTickCount() })

		QueryExecute("
			EXEC sp_set_session_context 'noTrigger', 1;
			delete terms_acceptance where program = (select product_id from product where short_title = '2024FSY_#variables.ticketName#')
			EXEC sp_set_session_context 'noTrigger', 0;
		", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete fsy_session_unit where created_by = :created_by", { created_by: variables.ticket }, { datasource = variables.dsn.local } );
		QueryExecute("delete pm_session where created_by = :created_by", { created_by: variables.ticket }, { datasource = variables.dsn.local } );
		QueryExecute("delete session_preference where created_by = :created_by", { created_by: variables.ticket }, { datasource = variables.dsn.local } );
		QueryExecute("delete pm_location where created_by = :created_by", { created_by: variables.ticket }, { datasource = variables.dsn.local } );
		QueryExecute("delete event where event_object = 'CONTEXT' and event_object_id in (select context_id from context where person in (select person_id from person where first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#'))", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete context where product in (select product_id from product where short_title like '%_#variables.ticketName#')", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete fsy_unit where created_by = :created_by", { created_by: variables.ticket }, { datasource = variables.dsn.local } );
		QueryExecute("delete person where first_name = 'First_#variables.ticketName#' and last_name = 'Last_#variables.ticketName#'", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete option_item where section in (select product_id from product where short_title like 'Section_%_#variables.ticketName#')", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete option_group where section in (select product_id from product where short_title like 'Section_%_#variables.ticketName#')", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete product where short_title like '%Housing_%_#variables.ticketName#'", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete product where short_title like 'Section_%_#variables.ticketName#'", {}, { datasource = variables.dsn.local } );
		QueryExecute("delete product where short_title = '2024FSY_#variables.ticketName#'", {}, { datasource = variables.dsn.local } );
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
		", { program: arguments.program}, { datasource = variables.dsn.local });
	}

	public struct function preregSetupResults() {
		local.program = queryExecute("select value from cntl_value where control = 'current_fsy_program'", {}, { datasource = variables.dsn.local }).value

		return {
			programProductID = local.program,
			program = variables.utils.queryToStruct(queryExecute("select * from product where product_id = :product_id", { product_id: local.program }, { datasource = variables.dsn.local }))
		}
	}

	//////////////////////////////////////////////////////////
	// This is the part where we test hiring scheduler
	//////////////////////////////////////////////////////////

	public any function onMissingMethod(string missingMethodName, struct missingMethodArguments) {
		try {
			local.hiringTest = true // metadata blah blah == "hiringTest"
			if (local.hiringTest)
				application.progress = []

			invoke("", missingMethodName, missingMethodArguments)
			return { pass: true }
		}
		catch (any e) {
			if (local.hiringTest)
				return { pass: false, message: e.message, type: e.type, error: e}

			rethrow;
		}
	}

	// Utils
	public void function removeAllCandidates() {
		queryExecute("
			DELETE emergency_info WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE context_property WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE availability_week WHERE hires_availability IN (SELECT hires_availability_id FROM hires_availability WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			))
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE hires_availability WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE hiring_info WHERE context IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			)
		", {}, { datasource: variables.dsn.local });

		queryExecute("
			DELETE context WHERE context_id IN (
				SELECT context_id
				FROM context
					INNER JOIN product on product = product_id
				WHERE context_type IN ('Counselor', 'Hired Staff')
					AND #variables.realProgram# IN (product.program, product.product_id)
					AND context.status = 'Active'
			)
		", {}, { datasource: variables.dsn.local });
	}

	public void function assertCandidatesAssigned(required numeric total) {
		var assigned = queryExecute("
			SELECT COUNT(context_id) AS total
			FROM context
				INNER JOIN product on product = product_id
			WHERE context_type IN ('Counselor')
				AND product.program = #variables.realProgram#
				AND context.status = 'Active'
		", {}, { datasource: variables.dsn.local });

		if (assigned.total != arguments.total)
			throw(type="assertCandidatesAssigned", message="Expected: #arguments.total# Actual: #assigned.total#");
	}

	public any function runScheduler() {
		local.users = getModel("fsyDAO").getAvailableHires(getModel("fsyDAO").getFSYYear().year);
		local.scheduler = getModel("employmentSchedulerS");
		return local.scheduler.processUserData(local.users);
	}

	// Tests
	private void function testDryRun() hiringTest {
		// no one to assign
		removeAllCandidates()

		runScheduler()

		// outcome - no assignments made
		assertCandidatesAssigned(0)
	}

	variables.dates = {
		week0: '2024-05-22',
		provo01A: '2024-05-26'
	}

	private void function testHappyPath() hiringTest {
		// no one to assign
		removeAllCandidates()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.provo01A])

		runScheduler()

		// outcome - no assignments made
		assertCandidatesAssigned(1)
	}

		private void function testAlreadyAssignedOneLinkedSession() hiringTest {
		// no one to assign
		removeAllCandidates()

		local.program = getProgram()
		local.person_id = createPerson("M")
		local.hireContext = createHireContext(local.person_id, local.program)
		createHiringInfo(local.hireContext, "Counselor", "UT")
		createAvailability(local.hireContext, [variables.dates.week0, variables.dates.provo01A])

		runScheduler()

		// outcome - no assignments made
		assertCandidatesAssigned(1)
	}
}
