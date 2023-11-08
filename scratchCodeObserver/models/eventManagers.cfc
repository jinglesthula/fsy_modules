<cfcomponent extends="base">
	<cffunction name="getStatus" access="public" output="false" returntype="string">
		<cfargument name="serverName" required="true" />
		<cfargument name="EMName" default="" />
		<cfargument name="groupName" default="" />

		<cfsavecontent variable="local.result">
			<cfoutput>
				<cftry>
					<cfset local.prefix = REReplace(arguments.serverName, "[^[:alnum:]]", "", "all")>

					<cftry>
						<cfset local.args = {} />
						<cfif arguments.EMName NEQ "">
							<cfset local.args.name = arguments.EMName />
						</cfif>
						<cfset local.response = call(arguments.serverName, "eventManager", local.args) />

						<cfcatch>
							Error on #arguments.serverName#: #cfcatch.message#
							<cfdump var="#cfcatch#">
							<cfdump var="#request#" />
							<cfreturn />
							<cfthrow type="earlyReturn" />
						</cfcatch>
					</cftry>

					<!--- Ensure we are getting event manager status from the server configured to run them --->
					<cfif StructKeyExists(local.response, "primaryTaskServer") AND local.response.primaryTaskServer NEQ local.response.host>
						<cfset getStatus(local.response.primaryTaskServer, arguments.EMName, arguments.groupName) />
						<cfthrow type="earlyReturn" />
					</cfif>
					<cfif local.response.error>
						<cfthrow type="serverStatus.#arguments.serverName#" message="#local.response.message#" detail="#local.response.detail#" />
					</cfif>

						<cfif arguments.serverName NEQ local.response.host>
						<div class="badMessage">WARNING: Data returned is for #local.response.host#</div>
					</cfif>

					<cfif NOT StructKeyExists(local.response, "eventManagers") OR StructIsEmpty(local.response.eventManagers)>
						eventManagers not initialized
					<cfelseif arguments.EMName NEQ "">
						<cfinvoke method="EMStatus">
							<cfinvokeargument name="id" value="#local.prefix##arguments.EMName#" />
							<cfinvokeargument name="EM" value="#local.response.eventManagers[arguments.EMName]#" />
							<cfinvokeargument name="groupName" value="#arguments.groupName#" />
						</cfinvoke>
					<cfelseif StructCount(local.response.eventManagers) GT 0>
						<cf_tabPane id="#local.prefix#EventManagers">
						<cfset local.ems = StructKeyArray(local.response.eventManagers) />
						<cfset ArraySort(local.ems, "textnocase") />
						<cfloop Array="#local.ems#" index="local.em">
							<cfset local.text = local.em />
							<cfif StructKeyExists(local.response.eventManagers[local.em], "name")>
								<cfset local.text = local.response.eventManagers[local.em].name />
							</cfif>
							<cf_tab id="#local.prefix##local.em#" tabtext="#local.text#" paneid="#local.prefix#EventManagers">
								<cfinvoke method="EMStatus">
									<cfinvokeargument name="id" value="#local.prefix##local.em#" />
									<cfinvokeargument name="EM" value="#local.response.eventManagers[local.em]#" />
									<cfinvokeargument name="groupName" value="#arguments.groupName#" />
								</cfinvoke>
							</cf_tab>
						</cfloop>
						</cf_tabPane>
					</cfif>

					<cfcatch type="earlyReturn">
						<!--- Do nothing - we just want to stop the cfsavecontent where the throw happened --->
					</cfcatch>
				</cftry>
			</cfoutput>
		</cfsavecontent>

		<cfreturn local.result />
	</cffunction>

	<cffunction name="EMStatus" access="private" output="true">
		<cfargument name="id" type="string" required="true" />
		<cfargument name="EM" type="struct" required="true" />
		<cfargument name="groupName" default="" />

		<cfif structKeyExists(arguments.EM, "error")>
			<h3>#arguments.EM.error#</h3>
			<p>#arguments.EM.detail#</p>
			<cfreturn />
		</cfif>

		<table class="orion" id="#arguments.id#Status">
			<tr>
				<th>Enabled</th>
				<td>#arguments.EM.enabled#</td>
			</tr>
		<cfswitch expression="#arguments.EM.type.listLast('.')#">
			<cfcase value="webServiceEGM,scantoolsEGM">
				<tr>
					<th>Last Error</th>
					<td>
						<cfif isStruct(arguments.EM.status.processingError) AND NOT structIsEmpty(arguments.EM.status.processingError)>
							#arguments.EM.status.processingError.error.message#:
							<cfif StructKeyExists(arguments.EM.status.processingError.error, "detail")>
								#arguments.EM.status.processingError.error.detail#
							<cfelse>
								#arguments.EM.status.processingError.error.Type#
							</cfif>
							<cfif StructKeyExists(arguments.EM.status.processingError, "timestamp")>
								<br />Occurred on #arguments.EM.status.processingError.timestamp#<br />
							</cfif>
						<cfelse>
							None
						</cfif>
					</td>
				</tr>
				<tr>
					<th>Last Run/Completed On</th>
					<td>
					<cfif isStruct(arguments.EM.status.attemptTimestamp) AND StructKeyExists(arguments.EM.status.attemptTimestamp, "all")>
						#arguments.EM.status.attemptTimestamp.all#
					<cfelse>
						#arguments.EM.status.attemptTimestamp#
					</cfif>
					</td>
				</tr>
				<cfif arguments.EM.type.listLast(".") EQ "scantoolsEGM">
				<tr>
					<th>Directory Monitored</th>
					<td>#arguments.EM.scannerdirectory#</td>
				</tr>
				</cfif>
			</table>

				<h3>Progress</h3>
				<cfset local.progress = arguments.EM.progress />
				<table class="orion">
				<cfif StructKeyExists(local.progress, "action")>
					<tr>
						<th>Last Action Performed</th>
						<td>#local.progress.action#</td>
					</tr>
				</cfif>
				<cfif StructKeyExists(local.progress, "timestamp")>
					<tr>
						<th>Last Action Performed On</th>
						<td>#local.progress.timestamp#</td>
					</tr>
				</cfif>
				</table>

				<cfif arguments.groupName NEQ "">
					<script type="text/javascript">
						$('#arguments.id#Status').hide();
					</script>
					<cfif StructKeyExists(arguments.EM.status.failedattempts, arguments.groupName) AND arguments.EM.status.failedattempts[arguments.groupName] GT 0>
						<img src="/common/images/icons/exclamation.png" alt="#arguments.EM.status.failedAttempts[arguments.groupName]# failed attempts" title="#arguments.EM.status.failedAttempts[arguments.groupName]# failed attempts" align="absmiddle" />
						#arguments.EM.status.failedAttempts[arguments.groupName]# failed attempts
					</cfif>

					<cfinvoke method="groupStatus">
						<cfinvokeargument name="EM" value="#arguments.EM#" />
						<cfinvokeargument name="groupName" value="#arguments.groupName#" />
					</cfinvoke>
				<!--- failedattempts will have an entry for every group that is never removed, with no extra entries - this means that active queues will not show unless they have failed at least once --->
				<cfelseif isStruct(arguments.EM.status.failedAttempts) AND StructCount(arguments.EM.status.failedAttempts) GT 0>
					<cfset local.groups = StructKeyArray(arguments.EM.status.failedAttempts) />
					<cfset ArraySort(local.groups, "textnocase") />
					<br />
					<cfloop array="#local.groups#" index="local.group">
						<fieldset class="pm">
							<legend>
								<cfif arguments.EM.status.failedattempts[local.group] GT 0>
									<img src="/common/images/icons/exclamation.png" alt="#arguments.EM.status.failedAttempts[local.group]# failed attempts" title="#arguments.EM.status.failedAttempts[local.group]# failed attempts" align="absmiddle" />
								</cfif>#local.group#
							</legend>

							<cfinvoke method="groupStatus">
								<cfinvokeargument name="EM" value="#arguments.EM#" />
								<cfinvokeargument name="groupName" value="#local.group#" />
							</cfinvoke>
						</fieldset>
					</cfloop>
				</cfif>
			</cfcase>
			<cfcase value="ShippingEM">
				<tr>
					<th>Last Error</th>
					<td>
						<cfif isStruct(arguments.EM.status.processingError) AND StructKeyExists(arguments.EM.status.processingError, "error") AND isStruct(arguments.EM.status.processingError.error)>
							<cfif StructKeyExists(arguments.EM.status.processingError.error, "message")><!--- Normal error --->
								#arguments.EM.status.processingError.error.message#:
								<cfif StructKeyExists(arguments.EM.status.processingError.error, "detail")>
									#arguments.EM.status.processingError.error.detail#
								<cfelse>
									#arguments.EM.status.processingError.error.Type#
								</cfif><br />
							<cfelse>
								<cfloop collection="#arguments.EM.status.processingError.error#" item="local.context">
									#local.context#:
									<cfset local.error = arguments.EM.status.processingError.error[local.context] />
									<cfif local.context NEQ "connection">
										<cfset local.error = local.error[1] /><!--- get the first error in a array of errors for this context_id --->
									</cfif>
									<cfif isStruct(local.error)>
										#local.error.message#: #local.error?.detail# <!--- Detail may not be present --->
									<cfelse>
										#local.error#
									</cfif><br />
								</cfloop>
							</cfif>
							<cfif StructKeyExists(arguments.EM.status.processingError, "timestamp")>
								<br />Occurred on #arguments.EM.status.processingError.timestamp#<br />
							</cfif>
						<cfelse>
							None
						</cfif>
					</td>
				</tr>
				<tr>
					<th>Currently Running</th>
					<td>#arguments.EM.status.busy#</td>
				</tr>
				<tr>
					<th>Last Run/Completed On</th>
					<td>#arguments.EM.status.attemptTimestamp#</td>
				</tr>
				<tr>
					<th>Place Missing Orders</th>
					<td>#arguments.EM.placeMissingOrders#</td>
				</tr>
			</table>

				<h3>Progress</h3>
				<cfset local.progress = arguments.EM.progress />
				<table class="orion">
				<cfif isDefined("local.progress.timestamp")>
					<tr>
						<th>Last Order Checked On</th>
						<td>#local.progress.timestamp#</td>
					</tr>
				</cfif>
				<cfif isDefined("local.progress.counts")>
					<tr>
						<th>Progress</th>
						<td>#local.progress.counts.processed# / #local.progress.counts.total#</td>
					</tr>
					<tr>
						<th>Skipped Orders</th>
						<td>#local.progress.counts.skipped#</td>
					</tr>
					<tr>
						<th>Orders Placed</th>
						<td>#local.progress.counts.added#</td>
					</tr>
					<tr>
						<th>Orders Shipped</th>
						<td>#local.progress.counts.Updated#</td>
					</tr>
				</cfif>
				<cfif isDefined("local.progress.errors")>
					<tr>
						<th>Errors</th>
						<td>#StructCount(local.progress.errors)#</td>
					</tr>
				</cfif>
				</table>
			</cfcase>
			<cfcase value="LMSEM">
				<tr>
					<th>Last Error</th>
					<td>
						<cfif isStruct(arguments.EM.status.processingError) AND NOT StructIsEmpty(arguments.EM.status.processingError)>
							<cfset local.error = arguments.EM.status.processingError />
							<cfif StructKeyExists(local.error, "error")>
								<cfset local.errorTimestamp = local.error.timestamp />
								<cfset local.error = local.error.error />
							</cfif>
							<cfif StructKeyExists(local.error, "Message")>
								#local.error.message#:
								<cfif StructKeyExists(local.error, "detail")>
									#local.error.detail#
								<cfelse>
									#local.error.Type#
								</cfif><br />
							<cfelse><!--- each error is in a struct key for the LMS adapter --->
								<cfloop collection="#local.error#" item="local.adapter" >
									<cfif local.error[local.adapter].hasError>
										[#local.adapter#] #local.error[local.adapter].error.message#:
										<cfif StructKeyExists(local.error[local.adapter].error, "detail")>
											#local.error[local.adapter].error.detail#
										<cfelse>
											#local.error[local.adapter].error.Type#
										</cfif><br />
									</cfif>
								</cfloop>
							</cfif>
							<cfif StructKeyExists(local, "errorTimestamp")>
								<br>Occurred on: #local.errorTimestamp#
							</cfif>
						<cfelse>
							None
						</cfif>
					</td>
				</tr>
				<tr>
					<th>Currently Running</th>
					<td>#arguments.EM.status.busy#</td>
				</tr>
				<tr>
					<th>Last Run/Completed On</th>
					<td>#arguments.EM.status.attemptTimestamp#</td>
				</tr>
				<tr>
					<th>Last Event Processed</th>
					<td>#arguments.EM.skippedEventsState.lastProcessedGradebookEvent#</td>
				</tr>
				<tr>
					<th>Total Failed Events in DB</th>
					<td>#arguments.EM.skippedEventsState.failedCount#</td>
				</tr>
			</table>

				<h3>Progress</h3>
				<cfset local.progress = arguments.EM.progress />
				<table class="orion">
				<cfif structKeyExists(local.progress, "action")>
					<tr>
						<th>Last Action Performed</th>
						<td>#local.progress.action#
							<cfif structKeyExists(local.progress, "step")>
								- #local.progress.step#
							</cfif>
						</td>
					</tr>
				</cfif>
				<cfif isDefined("local.progress.timestamp")>
					<tr>
						<th>Last Action Performed On</th>
						<td>#local.progress.timestamp#</td>
					</tr>
				</cfif>
				<cfif isDefined("local.progress.counts")>
					<tr>
						<th>Progress</th>
						<td>
							#local.progress.counts.processed# / #local.progress.counts.total#
							<cfif StructKeyExists(local.progress, "duplicate")>
								<cfdump var="#local.progress.duplicate#" />
							</cfif>
						</td>
					</tr>
				</cfif>
				<cfif structKeyExists(arguments.EM, "timing")>
					<tr>
						<th>Timing</th>
						<td>
						<cfloop array="#arguments.EM.timing#" index="local.timingInfo">
							The<cfif local.timingInfo.gradebook_system_group NEQ ""> "#local.timingInfo.gradebook_system_group#" domain for the</cfif> #local.timingInfo.gradebook_system# LMS last processed an event that occurred at #dateFormat(local.timingInfo.last_signal, "m/dd/yy")# #timeFormat(local.timingInfo.last_signal, "h:nn:ss tt")# which was <cfif local.timingInfo.days_behind GT 0>#local.timingInfo.days_behind# day(s)</cfif> #timeFormat(local.timingInfo.time_behind, "H:nn:ss")# hours ago.<br />
						</cfloop>
						</td>
					</tr>
				</cfif>
				</table>
			</cfcase>
			<cfdefaultcase>
				<cfdump var="#arguments.EM#" />
			</cfdefaultcase>
		</cfswitch>
	</cffunction>

	<cffunction name="groupStatus" access="private" output="true">
		<cfargument name="EM" type="struct" required="true" />
		<cfargument name="groupName" type="string" required="true" />

		<table class="orion">
			<tr>
				<th>Currently Running</th>
				<td>#StructKeyExists(arguments.EM.status.busy, arguments.groupName)#</td>
			</tr>
			<tr>
				<th>Last Run/Completed On</th>
				<td>
					<cfif NOT StructKeyExists(arguments.EM.status.attemptTimestamp, arguments.groupName)>
						Unknown
					<cfelse>
						#arguments.EM.status.attemptTimestamp[arguments.groupName]#
					</cfif>
				</td>
			</tr>
			<tr>
				<th>Last Error</th>
				<td>
					<cfif StructKeyExists(arguments.EM, "last_queue_errors")>
						<cfset local.last_errors = arguments.EM.last_queue_errors />
					<cfelse>
						<cfset local.last_errors = arguments.EM.last_group_errors />
					</cfif>
					<cfif StructKeyExists(local.last_errors, arguments.groupName)>
						<cfset local.error = local.last_errors[arguments.groupName] />
					<cfelse>
						<cfset local.error = "" />
					</cfif>
					<cfif isStruct(local.error) AND NOT StructIsEmpty(local.error)>
						<cfif StructKeyExists(local.error, "error")>
							<cfset local.errorTimestamp = local.error.timestamp />
							<cfset local.error = local.error.error />
						</cfif>
						<cfif isDefined("local.error.eventInfo")><!--- web service event call details --->
							<cfset local.argArray = [] />
							<cfloop collection="#local.error.eventInfo.createArgs.invokeArguments#" item="local.arg">
								<cfset local.argVal = local.error.eventInfo.createArgs.invokeArguments[local.arg] />
								<cfif isStruct(local.argVal)>
									<cfset local.argVal = "{#StructKeyList(local.argVal, ', ')#}" />
								</cfif>
								<cfset ArrayAppend(local.argArray, "#local.arg#=#local.argVal#") />
							</cfloop>
							#local.error.eventInfo.createArgs.invokeOperation#(#ArrayToList(local.argArray, ", ")#)<br>
							<cfif local.error.eventInfo.createArgs.callbackMethod NEQ "">
								<cfset local.argArray = [] />
								<cfloop collection="#local.error.eventInfo.createArgs.callbackArguments#" item="local.arg">
									<cfset local.argVal = local.error.eventInfo.createArgs.callbackArguments[local.arg] />
									<cfif isStruct(local.argVal)>
										<cfset local.argVal = "{#StructKeyList(local.argVal, ', ')#}" />
									</cfif>
									<cfset ArrayAppend(local.argArray, "#local.arg#=#local.argVal#") />
								</cfloop>
								Callback: #local.error.eventInfo.createArgs.callbackComponent#:#local.error.eventInfo.createArgs.callbackMethod#(#ArrayToList(local.argArray, ", ")#)<br />
							</cfif><br />
						</cfif>
						<cfif StructKeyExists(local.error, "eventError")><!--- web service event error --->
							<cfif isSimpleValue(local.error.eventError) AND local.error.eventError NEQ "">
								#local.error.eventError#<br />
							<cfelseif isStruct(local.error.eventError) AND StructKeyExists(local.error.eventError, "detail")>
								#local.error.eventError.message# #local.error.eventError.detail#<br />
							</cfif>
						</cfif>
						<cfif StructKeyExists(local.error, "detail")>
							#local.error.message# #local.error.detail#<br />
						<cfelseif StructKeyExists(local.error, "exception")>
							<cfif isSimpleValue(local.error.exception) AND local.error.exception NEQ "">
								#local.error.exception#<br />
							<cfelseif isStruct(local.error.exception) AND StructKeyExists(local.error.exception, "detail")>
								#local.error.exception.message# #local.error.exception.detail#<br />
							</cfif>
						</cfif>
						<cfif StructKeyExists(local, "errorTimestamp")>
							<br>Occurred on: #local.errorTimestamp#
						</cfif>
					<cfelse>
						None
					</cfif>
				</td>
			</tr>
		</table>

		<cfif StructKeyExists(arguments.EM.progress, arguments.groupName)>
			<cfset local.progress = arguments.EM.progress[arguments.groupName] />
			<h3>Detail</h3>
			<table class="orion">
				<cfif StructKeyExists(local.progress, "action")>
				<tr>
					<th>Current Action</th>
					<td>#local.progress.action#</td>
				</tr>
				</cfif>
				<cfif StructKeyExists(local.progress, "processed")>
				<tr>
					<th>Event Progress</th>
					<td>#local.progress.processed# / #local.progress.total#</td>
				</tr>
				</cfif>
				<cfif StructKeyExists(local.progress, "step")>
					<cfif isSimpleValue(local.progress.step)>
						<tr>
							<th>Step</th>
							<td>#local.progress.step#</td>
						</tr>
					<cfelseif isStruct(local.progress.step)>
						<cfif StructKeyExists(local.progress.step, "lineNo")>
							<tr>
								<th>DAT File Line</th>
								<td>#local.progress.step.lineNo#</td>
							</tr>
						<cfelseif StructKeyExists(local.progress.step, "Attempt")>
							<tr>
								<th>Processing</th>
								<td>#local.progress.step.Attempt#: #local.progress.step.Action#</td>
							</tr>
						</cfif>
					</cfif>
				</cfif>
				<cfif StructKeyExists(local.progress, "timestamp")>
				<tr>
					<th>Last Event Processed On</th>
					<td>#local.progress.timestamp#</td>
				</tr>
				</cfif>
				<cfif StructKeyExists(local.progress, "status")>
				<tr>
					<th>Status</th>
					<td>#local.progress.status#</td>
				</tr>
				</cfif>
			</table>
		</cfif>
	</cffunction>

	<cffunction name="getSummary" access="public" output="false">
		<cfargument name="serverName" required="true" />

		<cfset local.result = {} />

		<cfset local.prefix = REReplace(arguments.serverName, "[^[:alnum:]]", "", "all")>
		<cfset local.result.prefix = local.prefix />

		<cftry>
			<cfset local.response = call(arguments.serverName, "eventManager") />

			<cfcatch>
				<cfset local.result.error = true />
				<cfset local.result.errorInfo = {
					type: cfcatch.type,
					message: cfcatch.message
				} />
				<cfreturn local.result />
			</cfcatch>
		</cftry>

		<cfif local.response.keyExists("primaryTaskServer") AND local.response.primaryTaskServer NEQ local.response.host>
			<cfset local.result.getSummaryResult = "FIXME: " & getSummary(local.response.primaryTaskServer) />
			<cfreturn local.result />
		</cfif>

		<cfset local.emsData = {} />
		<cfif local.response.keyExists("eventManagers") AND NOT StructIsEmpty(local.response.eventManagers)>
			<cfset local.ems = StructKeyArray(local.response.eventManagers) />
			<cfset ArraySort(local.ems, "textnocase") />

			<cfscript>
				for (local.em in local.ems) {
					local.emData = { response: local.response }

					if (!structKeyExists(local.response.eventManagers[local.em], "name")) {
						local.emData.error = {
							error: local.response.eventManagers[local.em].error,
							detail: local.response.eventManagers[local.em].detail
						}
					}

					local.emsData[local.em] = local.emData
				}
			</cfscript>
		</cfif>

		<cfset local.result.data = {
			serverName: serverName,
			serverAlias: serverName NEQ local.response.host ? "(#LCase(local.response.host)#)" : "",
			status:
				NOT StructKeyExists(local.response, "eventManagers") OR StructIsEmpty(local.response.eventManagers)
					? "eventManagers not initialized"
					: StructCount(local.response.eventManagers) GT 0
						? "Initialized"
						: "We should never be in this state. What even is this?",
			ems: local.emsData
		} />
		<!---
		<cfif NOT StructKeyExists(local.response, "eventManagers") OR StructIsEmpty(local.response.eventManagers)>
			<table class="orion" style="width: auto; float: left;">
				<tr>
					<th style="width: auto;">#serverName#
						<cfif serverName NEQ local.response.host>
							(#LCase(local.response.host)#)
						</cfif>
					</th>
					<th style="width: auto;">Status</th>
				</tr>
				<tr>
					<td colspan="2">
						eventManagers not initialized
					</td>
				</tr>
			</table>
		<cfelseif StructCount(local.response.eventManagers) GT 0>
			<cfset local.ems = StructKeyArray(local.response.eventManagers) />
			<cfset ArraySort(local.ems, "textnocase") />
			<table class="orion" style="width: auto; float: left;" server="#arguments.serverName#">
				<tr>
					<th style="width: auto;">#arguments.serverName#
						<cfif serverName NEQ local.response.host>
							(#LCase(local.response.host)#)
						</cfif>
					</th>
					<th style="width: auto;">Status</th>
				</tr>
				<cfloop Array="#local.ems#" index="local.em">
					<tr name="#local.em#">
					<cfif NOT structKeyExists(local.response.eventManagers[local.em], "name")>
						<td>#local.em#</td>
						<cfset local.status.icon = "exclamation" />
						<cfset local.status.message = "#local.response.eventManagers[local.em].error# - #local.response.eventManagers[local.em].detail#"/>
					<cfelse>
						<td>#local.response.eventManagers[local.em].name#</td>
						<cfset local.status = { icon = "stop", message = "Disabled" } />
						<cfif local.response.eventManagers[local.em].enabled>
							<cfset failedCountExists = structKeyExists(local.response.eventManagers[local.em], "skippedEventsState") AND local.response.eventManagers[local.em].skippedEventsState.failedCount GT 0 />
							<cfset processingErrorExists = isStruct(local.response.eventManagers[local.em].status.processingError) AND NOT structIsEmpty(local.response.eventManagers[local.em].status.processingError) />
							<cfif isBoolean(local.response.eventManagers[local.em].status.busy)
								AND local.response.eventManagers[local.em].status.busy AND isDefined("local.response.eventManagers.#local.em#.progress.timestamp")
								AND DateAdd("n", local.response.eventManagers[local.em].busyNotification.start, local.response.eventManagers[local.em].progress.timestamp) LT Now()>
								<cfset local.status = { icon = "time", message = "Busy for #TimeFormat(now() - local.response.eventManagers[local.em].progress.timestamp, 'H:mm:ss')#" } />
							<cfelseif processingErrorExists OR failedCountExists>
								<cfset local.status = { icon = "exclamation", message = "" } />
								<cfif isStruct(local.response.eventManagers[local.em].status.failedAttempts)
										OR (local.response.eventManagers[local.em].status.failedAttempts EQ 0
										AND NOT failedCountExists)>
									<cfset local.status.icon = "error" />
								</cfif>
								<cfif local.response.eventManagers[local.em].type.listLast(".") EQ "ShippingEM">
									<cfset local.status.message = "#StructCount(local.response.eventManagers[local.em].status.processingError)# errors." />
								<cfelse>
									<cfset local.status.message = "" />
									<cfif failedCountExists>
										<cfset local.status.message &= "Total Failed Events in DB: #local.response.eventManagers[local.em].skippedEventsState.failedCount#" />
										<cfif processingErrorExists>
											<cfset local.status.message &= " | " />
										</cfif>
									</cfif>
									<cfif processingErrorExists>
										<cfset local.error = local.response.eventManagers[local.em].status.processingError />
										<cfif structKeyExists(local.error, "error")>
											<cfset local.errorTimeStamp = local.error.timestamp />
											<cfset local.error = local.error.error />
										</cfif>
										<cfif local.response.eventManagers[local.em].type.listLast(".") EQ "LMSEM">
											<cftry>
												<cfloop collection="#local.error#" item="local.adapter" >
													<cfif local.error[local.adapter].hasError>
														<cfset local.status.message &= "[#local.adapter#] " & local.error[local.adapter].error.message />
														<cfif StructKeyExists(local.error[local.adapter].error, "detail") >
															<cfset local.status.message &= ": #local.error[local.adapter].error.detail#" />
														<cfelse>
															<cfset local.status.message &= ": #local.error[local.adapter].error.Type#" />
														</cfif>
													</cfif>
												</cfloop>
												<cfcatch>
													<cfset local.status.message &= local.error.message />
													<cfif StructKeyExists(local.error, "detail") >
														<cfset local.status.message &= ": #local.error.detail#" />
													<cfelse>
														<cfset local.status.message &= ": #local.error.Type#" />
													</cfif>
												</cfcatch>
											</cftry>
										<cfelse>
											<cfset local.status.message &= local.error.message />
											<cfif StructKeyExists(local.error, "detail") >
												<cfset local.status.message &= ": #local.error.detail#" />
											<cfelse>
												<cfset local.status.message &= ": #local.error.Type#" />
											</cfif>
										</cfif>
									</cfif>
								</cfif>
							<cfelse>
								<cfset local.status = { icon = "accept", message = "No problems" } />
							</cfif>
						</cfif>
					</cfif>
						<td><img src="/common/images/icons/#local.status.icon#.png" title="#HTMLEditFormat(local.status.message)#" alt="#HTMLEditFormat(local.status.message)#" /></td>
					</tr>
					<cfif StructKeyExists(local.response.eventManagers[local.em], "enabled") AND local.response.eventManagers[local.em].enabled AND
							(ListFindNoCase("webServiceEGM,scantoolsEGM", local.response.eventManagers[local.em].type.listLast(".")) GT 0
							OR (StructKeyExists(local.response.eventManagers[local.em], "hasGroups") AND local.response.eventManagers[local.em].hasGroups))>
						<!--- failedattempts will have an entry for every group that is never removed, with no extra entries --->
						<cfset local.groups = Duplicate(local.response.eventManagers[local.em].status.busy) />
						<cfset StructAppend(local.groups, local.response.eventManagers[local.em].status.failedAttempts) />
						<cfif StructCount(local.groups) GT 0>
							<cfset local.groups = StructKeyArray(local.groups) />
							<cfset ArraySort(local.groups, "textnocase") />
							<cfloop array="#local.groups#" index="local.group">
								<cfif StructKeyExists(local.response.eventManagers[local.em], "last_queue_errors")>
									<cfset local.last_errors = local.response.eventManagers[local.em].last_queue_errors />
								<cfelse>
									<cfset local.last_errors = local.response.eventManagers[local.em].last_group_errors />
								</cfif>
								<tr name="#local.em#" group="#local.group#">
									<td style="padding-left: 5px;">
										<img src="/common/images/icons/bullet_black.png" alt="group" align="absmiddle" />
										#local.group#
									</td>
									<td>
										<cfif StructKeyExists(local.response.eventManagers[local.em].status.failedattempts, local.group)
											AND local.response.eventManagers[local.em].status.failedattempts[local.group] GT 0>
											<cfif StructKeyExists(local.last_errors, local.group)>
												<cfset local.error = local.last_errors[local.group] />
											<cfelse>
												<cfset local.error = {} />
											</cfif>
											<cfif isDefined("local.error.exception.detail")>
												<cfset local.status = "#local.error.exception.message# #local.error.exception.detail#" />
											<cfelseif isDefined("local.error.eventError.detail")>
												<cfset local.status = "#local.error.eventError.message# #local.error.eventError.detail#" />
											<cfelse>
												<cfset local.status = "#local.response.eventManagers[local.em].status.failedAttempts[local.group]# failed attempts" />
											</cfif>
											<img src="/common/images/icons/exclamation.png" title="#HTMLEditFormat(local.status)#" alt="#HTMLEditFormat(local.status)#" />
										<cfelse>
											<cfset local.title = "No problems" />
											<cfif StructkeyExists(local.response.eventManagers[local.em].progress, local.group) AND
												StructkeyExists(local.response.eventManagers[local.em].progress[local.group], "processed")>
												<cfset local.progress = local.response.eventManagers[local.em].progress[local.group] />
												<cfset local.title = "Processed #local.progress.processed# of #local.progress.total#" />
											</cfif>
											<img src="/common/images/icons/accept.png" title="#local.title#" alt="#local.title#" />
										</cfif>
									</td>
								</tr>
							</cfloop>
						</cfif>
					</cfif>
				</cfloop>
			</table>
		</cfif>
		--->

		<cfreturn local.result />
	</cffunction>
</cfcomponent>
