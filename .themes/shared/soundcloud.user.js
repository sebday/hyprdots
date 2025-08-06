// ==UserScript==
// @name        SoundCloud Theme Hot-Reloader
// @namespace   Violentmonkey Scripts
// @match       https://soundcloud.com/*
// @grant       GM_addStyle
// @grant       GM_xmlhttpRequest
// @version     1.7
// @author      Seb Day
// @description Hot-reloads themes for SoundCloud from a local server by polling the CSS file.
// ==/UserScript==

(function() {
    'use strict';

    const STYLE_ID = 'soundcloud-hot-reload-style';
    const COLORS_URL = 'http://localhost:8008/current/colours.css';
    const SHARED_URL = 'http://localhost:8008/shared/soundcloud.shared.css';
    let currentCombinedCSS = null;

    function fetchCSS(url) {
        return new Promise((resolve, reject) => {
            GM_xmlhttpRequest({
                method: 'GET',
                url: url,
                onload: function(response) {
                    if (response.status === 200) {
                        resolve(response.responseText);
                    } else {
                        reject(new Error(`Failed to fetch ${url}: ${response.statusText}`));
                    }
                },
                onerror: function(response) {
                    reject(new Error(`Error fetching ${url}: ${response.statusText}`));
                }
            });
        });
    }

    function checkForUpdate() {
        Promise.all([fetchCSS(COLORS_URL), fetchCSS(SHARED_URL)])
            .then(([colorsCSS, sharedCSS]) => {
                const newCombinedCSS = colorsCSS + '\n' + sharedCSS;
                if (newCombinedCSS && newCombinedCSS !== currentCombinedCSS) {
                    currentCombinedCSS = newCombinedCSS;
                    let styleElement = document.getElementById(STYLE_ID);
                    if (!styleElement) {
                        styleElement = document.createElement('style');
                        styleElement.id = STYLE_ID;
                        document.head.appendChild(styleElement);
                    }
                    styleElement.textContent = newCombinedCSS;
                    console.log('SoundCloud theme updated.');
                }
            })
            .catch(error => {
                // Silently fail if the server is not running or a file is missing
            });
    }

    // Initial check
    setTimeout(checkForUpdate, 1000);

    // Check for updates every 2 seconds
    setInterval(checkForUpdate, 2000);

})();
