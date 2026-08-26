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
// @match       https://diy.day.marketing/*
// @match       https://tgs.day.marketing/*
// @match       https://sebday.dev/*
// @match       https://ads.google.com/*
// @match       https://web.telegram.org/*
// @grant       GM_xmlhttpRequest
// @grant       GM_getValue
// @grant       GM_setValue
// @version     2.4.86
// @author      Seb Day
// @description Hot-reloads themes for multiple sites using darkhttpd.
// ==/UserScript==

(function() {
    'use strict';

    const BASE = 'http://localhost:8008';

    const SITES = {
        'x.com': 'x.css',
        'github.com': 'github.css',
        'soundcloud.com': 'soundcloud.css',
        'home.google.com': 'googlehome.css',
        'www.youtube.com': 'youtube.css',
        'grok.com': 'grok.css',
        'gemini.google.com': 'gemini.css',
        'web.telegram.org': 'telegram.css',
        'diy.day.marketing': 'shoelace-hex.css',
        'tgs.day.marketing': 'shoelace-hex.css',
        'sebday.dev': 'shoelace-hex.css',
    };

    const host = window.location.hostname;
    const siteCss = SITES[host];
    if (!siteCss) return;

    const STYLE_ID = `hot-reload-style-${host}`;
    const CACHE_KEY = `theme-css-v12-${host}`;
    const siteCssUrl = siteCss === 'shoelace-hex.css'
        ? `${BASE}/current/${siteCss}`
        : `${BASE}/shared/css/${siteCss}`;
    const themeUrls = [`${BASE}/current/colors.css`, siteCssUrl];
    let currentCombinedCSS = null;

    function injectCSS(css) {
        let el = document.getElementById(STYLE_ID);
        if (!el) {
            el = document.createElement('style');
            el.id = STYLE_ID;
        }
        el.textContent = css;
        (document.head || document.documentElement).appendChild(el);
    }

    function fetchCSS(url) {
        return new Promise((resolve, reject) => {
            GM_xmlhttpRequest({
                method: 'GET',
                url,
                onload(r) {
                    if (r.status >= 200 && r.status < 300) resolve(r.responseText);
                    else reject(new Error(`${url}: ${r.statusText}`));
                },
                onerror: () => reject(new Error(url)),
            });
        });
    }

    function checkForUpdate() {
        Promise.all(themeUrls.map(fetchCSS))
            .then((parts) => {
                const css = parts.join('\n');
                if (!css || css === currentCombinedCSS) return;
                currentCombinedCSS = css;
                injectCSS(css);
                GM_setValue(CACHE_KEY, css);
                console.log(`Theme updated for ${host}.`);
            })
            .catch(() => {});
    }

    (async function init() {
        const cached = await GM_getValue(CACHE_KEY, '');
        if (cached) {
            currentCombinedCSS = cached;
            injectCSS(cached);
        }
        checkForUpdate();
        setInterval(checkForUpdate, 2000);
    })();
})();
