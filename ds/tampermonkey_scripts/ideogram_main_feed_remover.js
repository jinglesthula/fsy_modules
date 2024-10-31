(function() {
    'use strict';
    setInterval(() => {
        if (window.location.href !== 'https://ideogram.ai/t/explore') return; // because the script is already running if you switch from the explore feed to your own profile with client-side nav

        [5, 6, 7].forEach(index => {
            //const elements = document.querySelectorAll(`body > div#root > header + div.MuiBox-root > div.MuiBox-root > div.MuiBox-root:has(> div.MuiBox-root:nth-child(${index})) > div.MuiBox-root:nth-child(${index})`);
            let elements = document.querySelectorAll(`body > div#root > div.MuiBox-root:last-child > div.MuiBox-root:last-child > div.MuiBox-root > div.MuiBox-root > div.MuiBox-root:last-child > div.MuiBox-root:last-child`)

            // Loop through the NodeList and remove each element from the DOM
            elements.forEach(element => {
                console.log({element})
                element.remove();
            });
        })

    }, 200)
})();

/*
// ==UserScript==
// @name         Ideogram Main Feed Remover
// @namespace    http://tampermonkey.net/
// @version      2024-10-31
// @description  try to take over the world!
// @author       You
// @match        https://ideogram.ai/*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=ideogram.ai
// @grant        none
// @require      file://C:/code/fsy/ui/cf/o3/modules/ds/tampermonkey_scripts/ideogram_main_feed_remover.js
// ==/UserScript==
*/
