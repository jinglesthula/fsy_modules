// Set up file path and initialize variables
filePath = ExpandPath(".") & "/scratch/temp/2024_hires.csv";
missingPeople = {};
processedPeople = {};
errors = [];
existingPeople = {};
alreadyHired = {};
context_id = 0;
hires_availability_id = 0;

// Read the CSV file
fileData = fileRead(filePath);
rows = listToArray(fileData, chr(10)); // Split by newline for each row
headers = listToArray(rows[1], ","); // Header row to skip
cols = {}
for (i = 1; i <= headers.len(); i ++) {
  cols[lCase(headers[i])] = i;
}
writedump(cols)
arrayDeleteAt(rows, 1); // Remove header row

// Loop through each row of data
for (i = 1; i <= arrayLen(rows); i++) {
  // safety switch; set to false to stop processing
  if (application.keyExists("fakeHires") && !application.fakeHires) break;

  rowData = listToArray(rows[i], ",");
  person_id = rowData[cols.person_id];

  try {
    if (missingPeople.keyExists(person_id)) {
      continue; // no need to check again, no point in trying to process additional rows for the person
    }

    // Check if the person exists
    if (!processedPeople.keyExists(person_id) && !alreadyHired.keyExists(person_id)) {
      checkPerson = queryExecute("
        SELECT person_id FROM person WHERE person_id = :person_id",
        {person_id: {value: person_id, cfsqltype: "cf_sql_integer"}},
        { datasource = application.dsn.fsy }
      );

      if (checkPerson.recordCount == 0) {
        // If person doesn't exist, add to missingPeople array and skip to next row
        missingPeople[person_id] = true;
        continue;
      }
    }

    // If context_id or hires_availability_id is not set, initialize new context and related records
    if (!structKeyExists(existingPeople, person_id)) {
      checkContext = queryExecute("
        SELECT context_id, ha.hires_availability_id
        FROM context
          INNER JOIN hires_availability ha ON ha.context = context.context_id
        WHERE person = :person_id
          AND product = 80001114
          AND context_type = 'Hired Staff'
        ",
        {person_id: {value: person_id, cfsqltype: "cf_sql_integer"}},
        { datasource = application.dsn.fsy }
      );

      if (checkContext.recordCount == 0) {
        // Give them all the shiny new 1-time records

        processedPeople[person_id] = true;
        // Insert into context table
        queryExecute("
          INSERT INTO context (person, context_type, status, product, created_by)
          VALUES (:person_id, 'Hired Staff', 'Active', 80001114, 'FSY-2883')",
          {person_id: {value: person_id, cfsqltype: "cf_sql_integer"}},
          { result = "contextInsert", datasource = application.dsn.fsy }
        );
        context_id = contextInsert.generatedKey;

        // Insert into hiring_info table
        queryExecute("
          INSERT INTO hiring_info (
            context, application_type, empl_rcd, hired_position, interview_score, state, country, created_by
          )
          VALUES (
            :context_id
            ,:application_type
            ,:empl_rcd
            ,:hired_position
            ,:interview_score
            ,:state
            ,:country
            ,'FSY-2883'
          )",
          {
              context_id: {value: context_id, cfsqltype: "cf_sql_integer"}
              ,application_type: {value: rowData[cols.application_type], cfsqltype: "cf_sql_varchar", null: rowData[cols.application_type] == "" || rowData[cols.application_type] == "NULL"}
              ,empl_rcd: {value: rowData[cols.empl_rcd], cfsqltype: "cf_sql_varchar", null: rowData[cols.empl_rcd] == "" || rowData[cols.empl_rcd] == "NULL"}
              ,hired_position: {value: rowData[cols.hired_position], cfsqltype: "cf_sql_varchar", null: rowData[cols.hired_position] == "" || rowData[cols.hired_position] == "NULL"}
              ,interview_score: {value: rowData[cols.interview_score], cfsqltype: "cf_sql_integer", null: rowData[cols.interview_score] == "" || rowData[cols.interview_score] == "NULL"}
              ,state: {value: rowData[cols.state], cfsqltype: "cf_sql_varchar", null: rowData[cols.state] == "" || rowData[cols.state] == "NULL"}
              ,country: {value: rowData[cols.country], cfsqltype: "cf_sql_varchar", null: rowData[cols.country] == "" || rowData[cols.country] == "NULL"}
          },
          { datasource = application.dsn.fsy }
        );

        // Insert into hires_availability table
        queryExecute("
          INSERT INTO hires_availability (context, number_of_weeks, created_by)
          VALUES (:context_id, :number_of_weeks, 'FSY-2883')",
          {context_id: {value: context_id, cfsqltype: "cf_sql_integer"}, number_of_weeks: { value: rowData[cols.number_of_weeks], cfsqltype: "cf_sql_integer" }},
          { result = "hiresAvailabilityInsert", datasource = application.dsn.fsy }
        );
        hires_availability_id = hiresAvailabilityInsert.generatedKey;

        // Store context_id and hires_availability_id in existingPeople to avoid duplicate inserts for this person
        existingPeople[person_id] = {context_id: context_id, hires_availability_id: hires_availability_id};
      } else {
        alreadyHired[person_id] = true
        existingPeople[person_id] = {context_id: checkContext.context_id, hires_availability_id: checkContext.hires_availability_id};
      }

      // Retrieve stored context_id and hires_availability_id for this person if already processed or hired
      context_id = existingPeople[person_id].context_id;
      hires_availability_id = existingPeople[person_id].hires_availability_id;
    }

    // Insert into availability_week table
    availabilityWeekInsert = queryExecute("
      INSERT INTO availability_week (hires_availability, start_date, type, week_position, created_by)
      SELECT :hires_availability_id, :start_date, :type, :week_position, 'FSY-2883'
      WHERE NOT EXISTS (
        SELECT hires_availability
        FROM availability_week
        WHERE hires_availability = :hires_availability_id
          AND start_date = :start_date
      )
      ",
      {
        hires_availability_id: {value: hires_availability_id, cfsqltype: "cf_sql_integer"}
        ,start_date: {value: rowData[cols.start_date], cfsqltype: "cf_sql_date"}
        ,type: {value: rowData[cols.type], cfsqltype: "cf_sql_varchar"}
        ,week_position: {value: rowData[cols.week_position], cfsqltype: "cf_sql_varchar"}
      },
      { datasource = application.dsn.fsy }
    );
  }
  catch (any e) {
    errors.append({e: e, cols: duplicate(cols), data: rowData })
    continue;
  }
}

// Output missing people array at the end of execution
writedump({ "Missing people: ": missingPeople.keyList() });
writedump({ "Processed people: ": processedPeople.keyList() });
writedump({ "Already processed: ": alreadyHired.keyList() });
writedump({ "Errors: ": errors });
