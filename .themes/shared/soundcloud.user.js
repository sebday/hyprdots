// ==UserScript==
// @name        SoundCloud Theme Hot-Reloader
// @namespace   Violentmonkey Scripts
// @match       https://soundcloud.com/*
// @grant       GM_addStyle
// @grant       GM_xmlhttpRequest
// @version     1.6
// @author      Seb Day
// @description Hot-reloads themes for SoundCloud from a local server by polling the CSS file.
// ==/UserScript==

(function() {
    'use strict';

    const STYLE_ID = 'soundcloud-hot-reload-style';
    const CSS_URL = 'http://localhost:8008/current/soundcloud.css';
    let currentCSS = null;

    function checkForUpdate() {
        GM_xmlhttpRequest({
            method: 'GET',
            url: CSS_URL,
            onload: function(response) {
                const newCSS = response.responseText;
                if (newCSS && newCSS !== currentCSS) {
                    currentCSS = newCSS;
                    let styleElement = document.getElementById(STYLE_ID);
                    if (!styleElement) {
                        styleElement = document.createElement('style');
                        styleElement.id = STYLE_ID;
                        document.head.appendChild(styleElement);
                    }
                    styleElement.textContent = newCSS;
                    console.log('SoundCloud theme updated.');
                }
            }
        });
    }

    // Initial check
    setTimeout(checkForUpdate, 1000);

    // Check for updates every 2 seconds
    setInterval(checkForUpdate, 2000);

})();
