component extends="coldbox.system.EventHandler"{

    /**
     * Default Action
     */
    function index( event, rc, prc ) {
        prc.message = "Hello From ColdBox";
    }

    function people( event, rc, prc ) {
      if (!arguments.rc.keyExists("key")) arguments.event.renderData(type="JSON", data=[]);

      arguments.event.renderData(type="JSON", data=[
        { 'person_id': 1, 'last_name': 'Lasterson', 'first_name': 'Firsty' },
        { 'person_id': 2, 'last_name': 'Lasterson', 'first_name': 'Firsty' },
        { 'person_id': 3, 'last_name': 'Lasterson', 'first_name': 'Firsty' }
      ]);
    }

}
