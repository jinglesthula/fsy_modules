<cfscript>

2

variables.injector.clearSingletons()





3

structdelete(session, "aaa")


4

fsys = variables.injector.getInstance("fsyS")
session.progress = {}
writedump(fsys.sendPreRegSchedulerNotifications(session.progress))


5




6

fsys = variables.injector.getInstance("fsyS")
session.progress = {}
writedump(fsys.sendPreRegSchedulerNotifications(session.progress))


7

writedump(session.progress)
//session.progress.continue = false


8

st = variables.injector.getInstance("scheduledTasks")
session.progress = {}
writedump(st.preRegReminder(session.progress))

</cfscript>
