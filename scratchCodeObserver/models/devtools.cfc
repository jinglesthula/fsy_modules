component {
  variables.injector = application.o3wirebox

  public struct function getEvents() {
    em = variables.injector.getInstance("eventManagers@scratchCodeObserver")
    return em.getSummary("ceregtasks", "ceregtasksEM", "event manager")
  }
}
