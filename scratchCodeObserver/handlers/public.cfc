component extends="coldbox.system.EventHandler"{

    /**
     * Default Action
     */
    function index( event, rc, prc ) {
        prc.message = "Hello From ColdBox";
    }

    /**
     * Action returning complex data, converted to JSON automatically by ColdBox
     * o3/scratchCodeObserver/public/devtoolsData
     */
    function devtoolsData( event, rc, prc ) {
      return getModel("devtools@scratchCodeObserver").getEvents()
    }

}
