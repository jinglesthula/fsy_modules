<cfscript>
programID = 80001114 // For the Strength of Youth (2025FSY)
sectionID = 80001133 // FSY UT Provo 01A
housingID = 80001135 // FSY UT Provo 01A - Male Housing
userInfo = 'fsy_2435'
preregLink = 'abc123'
prefsExist = false

people = queryExecute("
	select top 10 person_id from person
		left join pers_job pj on pj.person = person_id
		left join context c on c.person = person_id
	where c.context_id is null
		and pj.person is null
		and person.LDS_ACCOUNT_ID is not null
		and person.byu_id is null
		and person.birthdate between dateadd(year, -17, sysdatetime())
			and dateadd(year, -15, sysdatetime())
		and person.gender = 'M'
", {}, { datasource: application.dsn.fsy });

for (person in people) {
	phone = queryExecute("
		SELECT *
		FROM phone
		WHERE person = :person_id and phone_type = 'Permanent'
	", { person_id: person.person_id }, { datasource: application.dsn.fsy });
	address = queryExecute("
		SELECT *
		FROM address
		WHERE person = :person_id and address_type = 'Permanent'
	", { person_id: person.person_id }, { datasource: application.dsn.fsy });
	email = queryExecute("
		SELECT *
		FROM email
		WHERE person = :person_id and email_type = 'Permanent'
	", { person_id: person.person_id }, { datasource: application.dsn.fsy });

	// phone
	if (phone.recordCount == 0)
		queryExecute("
			insert into phone (person, phone, phone_type, updated_by) values (:person_id, '8015551243', 'Permanent', '#userInfo#')
		", { person_id: person.person_id }, { datasource: application.dsn.fsy });
	// address
	if (address.recordCount == 0)
		queryExecute("
			insert into address (person, address_1, city, state, zip, country, address_type, updated_by) values (:person_id, '123 Street', 'Anytown', 'UT', 84070, 'USA', 'Permanent', '#userInfo#')
		", { person_id: person.person_id }, { datasource: application.dsn.fsy });
	// email (create or update)
	if (email.recordCount == 0)
		queryExecute("
			insert into email (person, email, email_type, updated_by) values (:person_id, 'jonathan.anderson@byu.edu', 'Permanent', '#userInfo#')
		", { person_id: person.person_id }, { datasource: application.dsn.fsy });
	else
		queryExecute("
			update email set email = 'jonathan.anderson@byu.edu', updated_by = '#userInfo#' where person = :person_id and email_type = 'Permanent'
		", { person_id: person.person_id }, { datasource: application.dsn.fsy });

	// program context
	queryExecute("
		insert into context (person, product, context_type, status, enroll_date, prereg_link, updated_by) values (:person_id, :programID, 'Enrollment', 'Active', SYSDATETIME(), '#preregLink#', '#userInfo#')
	", { person_id: person.person_id, programID: programID }, { datasource: application.dsn.fsy, result = "programContext" });

	// assigned session w/ housing
	queryExecute("
		insert into context (person, product, context_type, status, pending_status, pending_start, updated_by) values (:person_id, :sectionID, 'Enrollment', 'Reserved', 'Active', SYSDATETIME(), '#userInfo#')
	", { person_id: person.person_id, sectionID: sectionID }, { datasource: application.dsn.fsy, result = "sectionContext" });
	queryExecute("
		insert into context (person, product, context_type, status, pending_status, pending_start, pending_quantity, choice_for, updated_by) values (:person_id, :housingID, 'Enrollment', 'Reserved', 'Active', SYSDATETIME(), 1, :section, '#userInfo#')
	", { person_id: person.person_id, section: sectionContext.generatedKey, housingID: housingID }, { datasource: application.dsn.fsy });

	// context_property
	queryExecute("
		insert into context_property (context, property_type, value, updated_by) values (:contextId, 'Pre-reg Assigned', 'Y', '#userInfo#')
	", { contextId: sectionContext.generatedKey }, { datasource: application.dsn.fsy });

	// preRegReceived event (for fsy_prereg_logical_status being 'Complete')
	queryExecute("
		insert into event (event_object, event_object_id, event_type) values ('CONTEXT', :programContext, 'preRegReceived')
	", { programContext = programContext.generatedKey }, { datasource: application.dsn.fsy });

	// preference(s) (for fsy_prereg_logical_status being 'Complete')
	if (!prefsExist) {
		queryExecute("
			insert into session_preference (program, prereg_link, pm_location, start_date, priority, created_by)
			values (:programID, '#preregLink#', 2, '2025-01-01', 1, '#userInfo#')
		", { programID: programID, programContext = programContext.generatedKey }, { datasource: application.dsn.fsy });
		prefsExist = true
	}
}
</cfscript>
