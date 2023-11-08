component hint="Manages server communication" {
	variables.sharedSecret = "06YEiQHHl6QHdMr2MJUoaClbE9M5VLpT1dllEzKw"; // generateSecretKey("DESEDE", 128)
	variables.cache = {};

	private string function getCookies(
		required string cookieStore
	) {
		lock name=arguments.cookieStore, type="exclusive", timeout="10" {
			if (!application.keyExists("cookies") || !structKeyExists(application.cookies, arguments.cookieStore)) {
				application.cookies[arguments.cookieStore] = { };
			}
			local.cookies = Duplicate(application.cookies[arguments.cookieStore]);
		}

		local.cookieList = [];
		for (local.mycookie in local.cookies) {
			local.cookieList.append("#local.mycookie#=#local.cookies[local.mycookie]#");
		}

		return ArrayToList(local.cookielist, ';');
	}

	private void function setCookies(
		required any cookies,
		required string cookieStore
	) {
		// cookies can be received in 1 of 2 ways, a string or a struct... make sure we always have a struct
		if (isSimpleValue(arguments.cookies)) {
			local.cookies = { 1 = arguments.cookies };
		} else {
			local.cookies = arguments.cookies;
		}
		lock name=arguments.cookieStore, type="exclusive", timeout=10 {
			for (local.cookie in local.cookies) {
				local.pair = local.cookies[local.cookie].listFirst(";");
				local.name = local.pair.listFirst("=");
				if (local.pair.listLen("=") > 1) {
					local.value = local.pair.listRest("=");
				} else {
					local.value = "";
				}
				application.cookies[arguments.cookieStore][local.name] = local.value;
			}
		}
	}

	/**
	 * General REST call with Orion HMAC credentials
	 **/
	public any function call(
		required string  serverName,
		required string  method,
				 struct  args,
				 string  body,
				 numeric followRedirect = 6
	) {
		request["OrionHMAC"] = { call_Data = arguments, cookies = getCookies(arguments.serverName), _history = local.request.OrionHMAC ?: "none" };
		if (!arguments.keyExists("url")) arguments.url = "https://#arguments.serverName#.byu.edu/o3/remote/serverStatus/#arguments.method#"; // add for getAuthorizationHeader
		if (StructKeyExists(arguments, "args")) { // all requests are get, so add data to URL to ensure HMAC is created correctly
			for (local.name in arguments.args) {
				if (arguments.url DOES NOT CONTAIN local.name) // check to see if a URL was provided that already has the value
					arguments.url &= "/" & local.name.LCase() & "/" & URLEncodedFormat(arguments.args[local.name]);
			}
		}

		local.cache = StructGet("application.serverResponseCache");
		if (!local.cache.keyExists(arguments.url) || local.cache[arguments.url].timeout < Now()) {
			lock name="#arguments.url#" type="exclusive" timeout="30" {
				if (!variables.cache.keyExists(arguments.url) || variables.cache[arguments.url].timeout <= Now()) {
					cfhttp(url=arguments.url, method="GET", result="local.result", timeout=15, getAsBinary="never", throwOnError=false, redirect=false) {
						cfhttpparam(type="header", name="Authorization", value=getAuthorizationHeader(arguments));
						cfhttpparam(type="header", name="Cookie", value=request["OrionHMAC"].cookies); // Prevent the auto creation of a new session for every request
						cfhttpparam(type="header", name="Accept", value="application/json");
						if (StructKeyExists(arguments, "body")) {
							cfhttpparam(type="body", value=arguments.body);
						}
					}
					if (local.result.ResponseHeader.keyExists("Location") && arguments.followRedirect > 0) {
						// this allows us to follow the redirect request and recalculate the HMAC signature based on the new URL
						return call(argumentCollection = arguments,
							url = local.result.ResponseHeader.location,
							followRedirect = arguments.followRedirect-1,
							serverName = arguments.serverName & arguments.followRedirect // generate a new serverName for cookie storage
						);
					}
					request["OrionHMAC"].result = local.result;
					if (local.result.ResponseHeader.keyExists("Set-Cookie")) {
						setCookies(local.result.ResponseHeader["Set-Cookie"], arguments.serverName);
					}

					// Remove surrounding parentheses as they are not really valid JSON, but simplify using results with AJAX
					local.response = REReplace(local.result["FileContent"], "^\(|\)$", "", "all");
					local.cache[arguments.url] = {
						response = IsJSON(local.response) ? DeserializeJSON(local.response) : local.result["FileContent"],
						// time out response cache in 30 seconds if successful
						timeOut = local.result.statusCode.left(1) == "2" ? DateAdd("s", 30, Now()) : Now()
					}
				}
			}
		}

		return local.cache[arguments.url].response;
	}

	/**
	 * @callData {url, data, body}
	 * @timestamp used during validation to ensure the same value is used for comparison
	 **/
	public string function getAuthorizationHeader(
		required struct callData,
				 numeric timestamp = getTickCount()
	) {
		// For a simple request the message is equal to the url we are calling
		local.message = URLDecode(arguments.callData.url.listRest("/")) & arguments.timestamp; // remove any protocol from the URL so we dont have issues with SSL
		if (arguments.callData.keyExists("data")) {
			// for messages with data, append it in alphabetical order
			local.keys = arguments.callData.data.keyArray();
			local.keys.sort("textnocase");
			local.valuePairs = [];
			for (local.name in local.keys) {
				local.valuePairs.append("#local.name.LCase()#=#EncodeForURL(arguments.callData.data[local.name])#");
			}
			local.message &= ArrayToList(local.valuePairs, "&");
		} else if (arguments.callData.keyExists("body"))
			local.message &= arguments.callData.body;

		return hmac(local.message, variables.sharedSecret, "HMACSHA512", "utf-8") & "," & arguments.timestamp;
	}
}
