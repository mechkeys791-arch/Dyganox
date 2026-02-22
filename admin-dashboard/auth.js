// Dashboard auth - token in sessionStorage (cleared at midnight for non-owner; owner 30 days)
const AUTH_TOKEN_KEY = 'dyganox_dashboard_token';

function getDashboardToken() {
    return sessionStorage.getItem(AUTH_TOKEN_KEY);
}

function setDashboardToken(token) {
    sessionStorage.setItem(AUTH_TOKEN_KEY, token);
}

function removeDashboardToken() {
    sessionStorage.removeItem(AUTH_TOKEN_KEY);
}

function getAuthHeaders() {
    const token = getDashboardToken();
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = 'Bearer ' + token;
    return headers;
}

async function fetchWithAuth(url, options = {}) {
    const token = getDashboardToken();
    options.headers = options.headers || {};
    if (token) options.headers['Authorization'] = 'Bearer ' + token;
    if (!options.headers['Content-Type']) options.headers['Content-Type'] = 'application/json';
    return fetch(url, options);
}

function checkAuthThen(callback) {
    // No login required; start dashboard directly from home.
    if (callback) callback();
}

// Add token to all API requests from this origin
(function() {
    var baseUrl = typeof API_CONFIG !== 'undefined' ? API_CONFIG.baseUrl : '';
    if (!baseUrl) return;
    var origFetch = window.fetch;
    window.fetch = function(url, options) {
        if (typeof url === 'string' && url.indexOf(baseUrl) === 0) {
            options = options || {};
            options.headers = options.headers || {};
            var token = getDashboardToken();
            if (token) options.headers['Authorization'] = 'Bearer ' + token;
        }
        return origFetch.apply(this, arguments);
    };
})();

function logoutDashboard() {
    removeDashboardToken();
    window.location.href = 'index.html';
}
