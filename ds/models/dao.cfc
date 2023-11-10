component threadSafe {

	property name="utils" inject;

	variables.dsn = { prod = "fsyweb_pro", dev = "fsyweb_dev", local = "fsyweb_local" };

	variables.dsn.scheduler = variables.dsn.local
	variables.realProgram = 80000082

	public query function countStarted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as started from FSY.DBO.context
			where product = @program
				and context_type = 'Enrollment'
		",
			{},
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
		);
	}

	public query function countCompleted() {
		return QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			select count(*) as completed from FSY.DBO.event where event_type = 'preRegReceived'
		",
			{},
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
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
			{ datasource = variables.dsn.scheduler }
		);
	}

	public struct function dataOverTime() {
		local.range = QueryExecute(
			"
			declare @program numeric(8) = (select value from cntl_value where control = 'current_fsy_program')

			SELECT prereg_start, sysdatetime() as now from product where product_id = @program
		",
			{},
			{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
				{ datasource = variables.dsn.scheduler }
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
			"linkMemberStats" = local.linkMemberStats
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
			concat(short_title, '_1333'),
			concat(title, '_1333'),
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

	public void function setControlValueToCreatedProgram(
		numeric product_id
	) {
		if (isDefined("application.progress"))
			application.progress.append({ currentStep: "setControlValue", tick: getTickCount() })

		QueryExecute(
			"
			update cntl_value set value = :product_id, updated_by = 'FSY-1333' where control = 'current_fsy_program'
		",
			{ product_id = arguments.product_id },
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
				and short_title like '%_1333'
			order by created desc
		",
			{},
			{ datasource = variables.dsn.local }
		);

		if (local.result.recordCount == 0) local.next = 1;
		else {
			local.match = ReFind("Section_(\d+)_1333", local.result.title)
			local.next = Mid(local.result.title, local.match.pos[ 1 ], local.match.len[ 1 ])
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
				concat('Section_', :next, '_1333'),
				concat('Section_', :next, '_1333'),
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
				concat('FemaleHousing_', :next, '_1333'),
				concat('FemaleHousing_', :next, '_1333'),
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
				concat('MaleHousing_', :next, '_1333'),
				concat('MaleHousing_', :next, '_1333'),
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
			values ('First_1333', 'Last_1333', :gender, '2008-01-01', :church_id, 'FSY-1333')
		",
			{ gender = arguments.gender, church_id = "#Floor(Rand() * 100000000)##Floor(Rand() * 100000000)#" },
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
			values (:person, :product, 'Enrollment', 'Active', :prereg_link, :ward, :stake, 'FSY-1333')
		",
			{
				person = arguments.person,
				product = arguments.program,
				prereg_link = arguments.prereg_link,
				ward = arguments.ward,
				stake = arguments.stake
			},
			{ datasource = variables.dsn.local, result = "local.result" }
		);

		if (arguments.prereg_link == "")
			QueryExecute(
				"
				update context set prereg_link = :prereg_link, updated_by = 'FSY-1333' where context_id = :context_id
			",
				{ prereg_link = "my#local.result.generatedkey#", context_id = local.result.generatedkey },
				{ datasource = variables.dsn.local }
			);

		return local.result.generatedkey
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
			insert into pm_location (name, created_by) values ('This is the place', 'FSY-1333')
		",
			{},
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

		QueryExecute(
			"
			insert into session_preference (program, prereg_link, pm_location, start_date, priority, created_by)
			values (:program, :prereg_link, :pm_location, :start_date, :priority, 'FSY-1333')
		",
			Duplicate(arguments),
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
			values (:unit_number, :name, 'Ward', :parent, 'FSY-1333')
		",
			{ unit_number = local.next.unit_number, parent = arguments.stake, name = "ward_#local.next.unit_number#_FSY-1333" },
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
			values (:unit_number, :name, 'Stake', 466344, 'FSY-1333')
		",
			{ unit_number = local.next.unit_number, name = "stake_#local.next.unit_number#_FSY-1333" },
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
			values (:title, 'FSY', 'FSY', :product, :pm_location, :start_date, :end_date, :participant_start_date, :participant_end_date, 'FSY-1333')
		",
			{
				title = "session_#arguments.pm_location#_#arguments.start_date#",
				product = arguments.product,
				pm_location = arguments.pm_location,
				start_date = dateFormat(dateAdd("d", -1, arguments.start_date), "yyyy-mm-dd"),
				end_date = dateFormat(dateAdd("d", 6, arguments.start_date), "yyyy-mm-dd"),
				participant_start_date = arguments.start_date,
				participant_end_date = dateFormat(dateAdd("d", 5, arguments.start_date), "yyyy-mm-dd")
			},
			{ datasource = variables.dsn.local, result = "local.result" }
		);

		return local.result.generatedkey
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
			values (:pm_session, :fsy_unit, :female, :male, 'Participant', 'FSY-1333')
		", {
			pm_session = arguments.pm_session,
			fsy_unit = arguments.fsy_unit,
			female = { value=arguments.female, cfsqltype="cf_sql_numeric", null=(arguments.female == 0) },
			male = { value=arguments.male, cfsqltype="cf_sql_numeric", null=(arguments.male == 0) }
		}, { datasource = variables.dsn.local });
	}

	// END individual setup helper functions

	// Begin actual test case setup functions

	// just put all the above functions through their paces
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
		private struct function newParticipant(string gender, struct base, struct s, string start_date = "") {
			if (start_date == "")
				start_date = base.start_date

			person = createPerson(gender)
			u = newUnits()
			program_c = createProgramContext(program, person, u.ward, u.stake)
			createPreRegReceivedEvent(program_c)
			createFSURecords(s.pm_session, u.stake)
			createSessionPreference(base.program, "my#program_c#", s.pm_location, start_date)

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

		// 1 *** assign people in a random order (to make it fair)

		//		... best tested with a few runthroughs and take the average
		//		a - 1 session; 1 bed; 2 participants = ~50% of the time each is placed and the other not
		private void function setup_1_a() {
			b = baseSetup()

			//1 session; 1 bed
			s = newSession(b, 0, 1)

			// 2 participants
			p1 = newParticipant('M', b, s)
			p2 = newParticipant('M', b, s)
		}

		// 2 *** penalize link groups (to make it unfair)

		//		... best tested with a few runthroughs and take the average
		//		a - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 12 unlinked participants = 20 people placed
		private void function setup_2_a() {

		}

		//		b - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 20 unlinked participants = group penalty applies, 20 people placed
		private void function setup_2_b() {

		}

		//		c - 1 session; 20 beds; 2 linked participants A, 6 linked partitipants B, 100 unlinked participants = group penalty more apparent, 20 people placed
		private void function setup_2_c() {

		}

		// 3 *** never sell more than max_enroll beds

		//		a - 1 session; 1 bed; 2 participants = 1 placed; 1 not placed
		private void function setup_3_a() {

		}

		// 4 *** honor unit reservations

		//		a - 1 session; 1 beds; 1 participant; 1 other unit w/ 1 open reserved bed = 1 not placed
		private void function setup_4_a() {

		}

		//		b - 1 session; 2 beds; 2 participants; 1 other unit w/ 1 open reserved bed = 1 placed; 1 not placed
		private void function setup_4_b() {

		}

		//		c - 1 session; 2 beds; 1 participant; P's unit w/ 1 open reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed
		private void function setup_4_c() {

		}

		//		d - 1 session; 2 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 not placed
		private void function setup_4_d() {

		}

		//		e - 1 session; 3 beds; 1* participant; P's unit w/ 1 filled reserved bed; 1 other unit w/ 1 open reserved bed = 1 placed
		private void function setup_4_e() {

		}

		// 5 *** everyone in a given link is placed, or no one in the link is placed

		//		a - 1 session; 1 bed; 2 linked participants; 2 not placed
		private void function setup_5_a() {

		}

		//		b - 1 session; 2 beds; 2 linked participants; 2 placed
		private void function setup_5_b() {

		}

		//		c - 1 session; 1 M bed/ 1 F bed; 2 linked participants, M and F; 2 placed
		private void function setup_5_c() {

		}

		//		d - 1 session; 2 M bed; 2 linked participants, M and F; 2 not placed
		private void function setup_5_d() {

		}

		//		e - 2 sessions; 1 bed each; 2 linked participants; 2 not placed
		private void function setup_5_e() {

		}

		// 6 *** if a link is placed, all the members are placed in the same pm_session (not split up over concurrent sessions)

		//		a - 2 sessions; 1 full bed and 1 open bed each; 2 linked participants = 2 not placed
		private void function setup_6_a() {

		}

		//		b - 2 sessions; 2 open beds each; 2 linked participants = 2 placed same session
		private void function setup_6_b() {

		}

		// 7 *** we give people their highest priority preference possible (i.e., after randomizing assign as many 1st priorities as we can, then 2, then 3, etc.)

		//		a - 1 session A, 1 session B; 1 open bed each session; 3 participants, each w/ p1 A, p2 B = 1 placed in A, 1 placed in B, 1 not placed
		private void function setup_7_a() {

		}

		//		b - 1 session A, 1 session B; 2 open beds A, 1 open bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z placed in B
		private void function setup_7_b() {

		}

		//		c - 1 session A, 1 session B; 2 open beds A, 1 full bed B; 2 participants X and Y, each w/ p1 A; 1 participant Z w/ p1 B, p2 A = X and Y placed in A, Z not placed
		private void function setup_7_c() {

		}

		//		d - 2 placetimes A and B; A is full; 1 participant w/ p1 A, p2 B = 1 placed in B
		private void function setup_7_d() {

		}

		//		e - 5 sessions; 1 participant; cycle through p1-5 for each session = placed in the right one each time
		private void function setup_7_e() {

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

		QueryExecute(
			"
			delete fsy_session_unit where created_by = 'FSY-1333'
		",
			{},
			{ datasource = variables.dsn.local }
		);
		QueryExecute(
			"
			delete pm_session where created_by = 'FSY-1333'
		",
			{},
			{ datasource = variables.dsn.local }
		);
		QueryExecute(
			"
			delete session_preference where created_by = 'FSY-1333'
			delete pm_location where created_by = 'FSY-1333'
			delete event where event_object = 'CONTEXT' and event_object_id in (select context_id from context where person in (select person_id from person where first_name = 'First_1333' and last_name = 'Last_1333'))
			delete context where person in (select person_id from person where first_name = 'First_1333' and last_name = 'Last_1333')
			delete fsy_unit where created_by = 'FSY-1333'
			delete person where first_name = 'First_1333' and last_name = 'Last_1333'
			delete option_item where section in (select product_id from product where short_title like 'Section_%_1333')
			delete option_group where section in (select product_id from product where short_title like 'Section_%_1333')
			delete product where short_title like '%Housing_%_1333'
			delete product where short_title like 'Section_%_1333'
			delete product where short_title = '2024FSY_1333'
		",
			{},
			{ datasource = variables.dsn.local }
		);
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
}
