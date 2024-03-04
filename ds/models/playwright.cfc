component threadSafe {

	property name="utils" inject;

	variables.dsn = { prod = "fsyweb_pro", dev = "fsyweb_dev", local = "fsyweb_local" };
	variables.realProgram = 80000082

  public struct function createPerson(
    required numeric churchId,
    string first_name = "",
    string last_name = ""
  ) {
    try {
      arguments.updated_by = "playwright"
      queryExecute("
        insert into person (
          lds_account_id
          , updated_by
          #arguments.first_name != "" ? ", first_name" : ""#
          #arguments.last_name != "" ? ", last_name" : ""#
        ) values (
          :churchId
          , :updated_by
          #arguments.first_name != "" ? ", :first_name" : ""#
          #arguments.last_name != "" ? ", :last_name" : ""#
        )
      ", arguments, { datasource: variables.dsn.local, result: "local.result" });

      return local.result;
    }
    catch (any e) {
      variables.utils.logError(e, true)
      return { type: e.type, message: e.message }
    }
  }
}
