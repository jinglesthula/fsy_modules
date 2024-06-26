﻿component extends="coldbox.system.EventHandler"{

	// Default Action
	function index(event,rc,prc){
		prc.welcomeMessage = "Welcome to ColdBox!";
		event.setView("main/index");
    }

    function cached( event, rc, prc ) cache="true" cacheTimeout="30" cacheLastAccessTimeout="15" {
		prc.welcomeMessage = "Welcome to ColdBox Cached!";
        event.setView( "main/index" );
    }

	// Do something
	function doSomething(event,rc,prc){
		setNextEvent("main.index");
    }

    function doSomethingElse(event,rc,prc){
        setNextEvent("main.index");
    }

    function doSomethingAgain(event,rc,prc) allowedMethods="POST" {
        setNextEvent("main.index");
    }    

	/************************************** IMPLICIT ACTIONS *********************************************/

	function onAppInit(event,rc,prc){

	}

	function onRequestStart(event,rc,prc){

	}

	function onRequestEnd(event,rc,prc){

	}

	function onSessionStart(event,rc,prc){

	}

	function onSessionEnd(event,rc,prc){
		var sessionScope = event.getValue("sessionReference");
		var applicationScope = event.getValue("applicationReference");
	}

	function onException(event,rc,prc){
		//Grab Exception From private request collection, placed by ColdBox Exception Handling
		var exception = prc.exception;
		//Place exception handler below:

	}

	function onMissingTemplate(event,rc,prc){
		//Grab missingTemplate From request collection, placed by ColdBox
		var missingTemplate = event.getValue("missingTemplate");

	}

}
