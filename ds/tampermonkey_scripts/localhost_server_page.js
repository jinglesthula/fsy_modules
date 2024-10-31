(function() {
    'use strict';
    $('head').append(`
    <style>
    body {
        --body-padding: 2rem;
        font-family: 'Lucida Sans', Arial;
        padding: var(--body-padding);
    }

    pre {
        font-family: 'Roboto Mono';
        background: #f6f6f6;
        border: 1px solid #ddd;
        padding: 0.4rem 0.6rem;
        border-radius: 0.2rem;
    }

    fieldset {
        position: absolute;
        top: var(--body-padding);
        right: var(--body-padding);
        border: 1px solid #999;
        border-radius: 0.3rem;
    }

    body > p {
        background: #eee;
        padding: 0.8rem;
        border-radius: 0.75rem;
        float: left;
        clear: left;
    }

    body > p + p {
        margin-top: 0.8rem;
    }

    body > p > a {
        background: #999;
        color: white;
        border-radius: 0.4rem;
        padding: 0.4rem 0.8rem;
        text-decoration: none;
    }

    body > p > a > span {
        margin-right: 0.6rem;
    }

    body > p > a:first-child {
        width: 24rem;
        display: block;
        font-size: 2rem
    }

    body > p > a:not(:first-child) {
        margin-top: 0.6rem;
        display: inline-block;
    }

    body > p > a:not(:first-child) + a {
        margin-left: 0.4rem;

    }

    body > p > a:hover {
        background: #777;
    }

    p:nth-child(1) a:nth-child(1) {
        background: #369;
    }

    p:nth-child(2) a:nth-child(1) {
        background: #900;
    }

    p:nth-child(6) a:nth-child(1) {
        background: #0073ec;
    }


    </style>
    `)
    $('head').append(`<script src="https://kit.fontawesome.com/e4bdeb6cfc.js" crossorigin="anonymous"></script>`) // my personal kit on font awesome using mithlond.stream

    $('p')
        .contents()
        .filter(function() {
            return this.nodeType == 3; //Node.TEXT_NODE
        }).remove();

    // Orion
    $('p:nth-child(1) a:nth-child(1)').prepend('<span class="fas fa-fw fa-star"></span>')

    // Errors
    $('p:nth-child(2) a:nth-child(1)').prepend('<span class="fas fa-fw fa-bug"></span>')

    // CF Admin
    $('p:nth-child(3) a:nth-child(1)').prepend('<span class="fas fa-fw fa-cog"></span>')

    // Devtools
    $('p:nth-child(4) a:nth-child(1)').prepend('<span class="fas fa-fw fa-tools"></span>')

     // Contract tracker
    $('p:nth-child(5) a:nth-child(1)').prepend('<span class="fas fa-fw fa-file-signature"></span>')

     // Portainer
    $('p:nth-child(6) a:nth-child(1)').prepend('<span class="fab fa-fw fa-docker"></span>')
})();

/*
// ==UserScript==
// @name         localhost server page
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  try to take over the world!
// @author       You
// @match        http*://localhost/
// @exclude      http://localhost:3000/
// @require      https://code.jquery.com/jquery-3.2.1.min.js
// @grant        none
// @require      file://C:/code/fsy/ui/cf/o3/modules/ds/tampermonkey_scripts/localhost_server_page.js
// ==/UserScript==
*/
