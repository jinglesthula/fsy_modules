(function () {
    function onDOMReady(callback) {
        if (document.readyState === 'loading') {
            // DOM is still loading, wait for the event
            document.addEventListener('DOMContentLoaded', callback);
        } else {
            // DOM is already loaded, execute the callback immediately
            callback();
        }
    }

    // Usage
    onDOMReady(() => {

    // Replace `$('#links').on('click', 'div[data-placeholder]', function() {...})`
    document.querySelector('section[data-testid="mainline"]').addEventListener('click', (event) => {
      const placeholderDiv = event.target.closest('div[data-placeholder]');
      if (placeholderDiv) {
        const previousSibling = placeholderDiv.previousElementSibling;
        if (previousSibling) {
          previousSibling.style.display = previousSibling.style.display === 'none' ? 'block' : 'none';
        }
      }
    });

    function filterDDG() {
      const results = document.querySelectorAll('section[data-testid="mainline"] article');

      const domainBlacklist = [
        'download.cnet.com',
        'w3schools.com',
        'www.w3schools.com',
        'experts-exchange.com',
        'www.experts-exchange.com',
        'thefreedictionary.com',
        'merriam-webster.com',
        'urbandictionary.com',
        'forbes.com',
      ];
      const domainPreferenceList = [
        'developer.mozilla.org',
        'stackoverflow.com',
        'api.jquery.com',
        'cfdocs.org',
        'en.wikipedia.org',
      ];

      results.forEach((item) => {
        if (item.getAttribute('data-filtered') === 'true') return;

        //const linkDomain = item.querySelector('div > div > a[data-testid="result-extras-url-link"]').getAttribute('href');
          let linkDomain = item.querySelector('div:first-child > div:last-child > p').innerText;

        item.setAttribute('data-filtered', 'true');

        // Hide blacklisted domains
        if (domainBlacklist.includes(linkDomain)) {
          item.style.display = 'none';

          // Create placeholder
          const placeholder = document.createElement('div');
          placeholder.setAttribute('data-placeholder', 'true');
          placeholder.textContent = `Toggle ${linkDomain}`;
          placeholder.style.background = '#f6f6f6';
          placeholder.style.fontSize = '12px';
          placeholder.style.padding = '4px 8px';
          placeholder.style.cursor = 'pointer';
          placeholder.style.marginBottom = '10px';

          // Insert the placeholder after the hidden item
          item.insertAdjacentElement('afterend', placeholder);
        }

        // Highlight preferred domains
        if (domainPreferenceList.includes(linkDomain)) {
          item.style.background = 'rgba(100,200,100,0.1)';
        }
      });
    }

    setInterval(filterDDG, 200);
    });



})();

/*
// ==UserScript==
// @name         Better DuckDuckGo search results
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  try to take over the world!
// @author       You
// @match        http*://duckduckgo.com/*
// @require       //code.jquery.com/jquery-3.3.1.min.js
// @grant        none
// @require      file://C:/code/fsy/ui/cf/o3/modules/ds/tampermonkey_scripts/better_ddg_results.js
// ==/UserScript==
*/
