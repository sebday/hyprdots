// ==UserScript==
// @name        Theme Hot-Reloader
// @namespace   Violentmonkey Scripts
// @match       https://x.com/*
// @match       https://github.com/*
// @match       https://soundcloud.com/*
// @match       https://home.google.com/*
// @match       https://www.youtube.com/*
// @grant       GM_addStyle
// @grant       GM_xmlhttpRequest
// @version     2.2
// @author      Seb Day
// @description Hot-reloads themes for multiple sites from a local server by polling CSS files.
// ==/UserScript==

(function() {
    'use strict';

    const SITES = {
        'x.com': 'x.css',
        'github.com': 'github.css',
        'soundcloud.com': 'soundcloud.css',
        'home.google.com': 'googlehome.css',
        'www.youtube.com': 'youtube.css'
    };

    const currentHost = window.location.hostname;
    const cssFile = SITES[currentHost];

    if (!cssFile) return;

    const STYLE_ID = `hot-reload-style-${currentHost}`;
    const COLORS_URL = 'http://localhost:8008/current/colours.css';
    const SHARED_URL = `http://localhost:8008/shared/${cssFile}`;
    let currentCombinedCSS = null;

    function fetchCSS(url) {
        return new Promise((resolve, reject) => {
            GM_xmlhttpRequest({
                method: 'GET',
                url: url,
                onload: function(response) {
                    if (response.status >= 200 && response.status < 300) {
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
                    console.log(`Theme updated for ${currentHost}.`);
                }
            })
            .catch(error => {
                // Fail silently if the server isn't running or a file is missing
            });
    }

    // Initial check
    setTimeout(checkForUpdate, 1000);

    // Check for updates every 2 seconds
    setInterval(checkForUpdate, 2000);

})();
