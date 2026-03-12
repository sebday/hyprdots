// ==UserScript==
// @name        Theme Hot-Reloader
// @namespace   Violentmonkey Scripts
// @run-at      document-start
// @match       https://x.com/*
// @match       https://github.com/*
// @match       https://soundcloud.com/*
// @match       https://home.google.com/*
// @match       https://www.youtube.com/*
// @match       https://grok.com/*
// @match       https://gemini.google.com/*
// @match       https://*day.marketing/*
// @match       https://sebday.dev/*
// @match       https://ads.google.com/*
// @match       https://web.telegram.org/*
// @grant       GM_addStyle
// @grant       GM_xmlhttpRequest
// @grant       GM_getValue
// @grant       GM_setValue
// @version     2.4.63
// @author      Seb Day
// @description Hot-reloads themes for multiple sites using darkhttpd.
// ==/UserScript==

(function() {
    'use strict';

    const SITES = {
        'x.com': 'x.css',
        'github.com': 'github.css',
        'soundcloud.com': 'soundcloud.css',
        'home.google.com': 'googlehome.css',
        'www.youtube.com': 'youtube.css',
        'grok.com': 'grok.css',
        'gemini.google.com': 'gemini.css',
        'sebday.dev': 'shoelace.css',
        'docs.day.marketing': 'shoelace.css',
        'diy.day.marketing': 'shoelace.css',
        'tgs.day.marketing': 'shoelace.css',
        'web.telegram.org': 'telegram.css',
    };

    const currentHost = window.location.hostname;
    let cssFile = SITES[currentHost];
    if (!cssFile) return;

    const STYLE_ID = `hot-reload-style-${currentHost}`;
    const CACHE_KEY = `theme-css-${currentHost}`;
    const COLORS_URL = 'http://localhost:8008/current/colours.css';
    const SHARED_URL = `http://localhost:8008/shared/${cssFile}`;
    let currentCombinedCSS = null;

    function injectCSS(css) {
        let el = document.getElementById(STYLE_ID);
        if (!el) {
            el = document.createElement('style');
            el.id = STYLE_ID;
            (document.head || document.documentElement).appendChild(el);
        }
        el.textContent = css;
    }

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
                    injectCSS(newCombinedCSS);
                    GM_setValue(CACHE_KEY, newCombinedCSS);
                    console.log(`Theme updated for ${currentHost}.`);
                }
            })
            .catch(() => {});
    }

    (async function init() {
        const cached = await GM_getValue(CACHE_KEY, '');
        if (cached) injectCSS(cached);
        checkForUpdate();
        setInterval(checkForUpdate, 2000);
    })();
})();
