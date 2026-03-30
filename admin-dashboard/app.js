// Global state
let allMechanics = [];
let allRequests = [];
let analyticsData = {};
let requestsChart = null;
let serviceTypeChart = null;
let mechanicsByCityChart = null;
let onlineOfflineChart = null;
let statusDistChart = null;
let dashboardCityChart = null;
let dashboardOnlineChart = null;
let profileMap = null;
let profileMarker = null;
let leafletProfileMap = null;
let leafletRequestMap = null;
let allMechanicsMap = null;
let mechanicsByCityMapInstance = null;
let allMechanicsMapMarkers = [];
let mechanicsByCityMapMarkers = [];
let chartRange = 'lifetime'; // 1h, 1d, 1M, 2M, 1y, lifetime
let helpMechanicsByEmail = {}; // email -> mechanic for phone in chat

// Escape for HTML attribute
function escapeAttr(s) {
    if (s == null) return '';
    return String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// Photo preview modal (medium, centered)
function showPhotoModal(url, label) {
    if (!url || String(url).trim() === '') return;
    const modal = document.getElementById('photo-preview-modal');
    const img = document.getElementById('photo-preview-img');
    const title = document.getElementById('photo-preview-title');
    if (img) img.src = url;
    if (title) title.textContent = label || 'Profile photo';
    if (modal) modal.style.display = 'block';
}

function closePhotoModal() {
    const modal = document.getElementById('photo-preview-modal');
    const img = document.getElementById('photo-preview-img');
    if (modal) modal.style.display = 'none';
    if (img) img.src = '';
}

// Initialize dashboard (after auth check)
document.addEventListener('DOMContentLoaded', function() {
    if (typeof checkAuthThen !== 'function') {
        document.getElementById('auth-check').style.display = 'none';
        document.getElementById('dashboard-app').style.display = 'flex';
        initDashboard();
        return;
    }
    checkAuthThen(function() {
        document.getElementById('auth-check').style.display = 'none';
        document.getElementById('dashboard-app').style.display = 'flex';
        initDashboard();
    });
});

function initDashboard() {
    initializeNavigation();
    loadDashboard();
    loadRegistrationRequests();
    setupModal();
    document.body.addEventListener('click', function(e) {
        const el = e.target.closest('.photo-thumb-clickable');
        if (!el) return;
        const url = el.getAttribute('data-url');
        if (!url) return;
        e.preventDefault();
        showPhotoModal(url, el.getAttribute('data-name') || 'Photo');
    });
}

// Navigation
function initializeNavigation() {
    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();
            const section = this.getAttribute('data-section');
            switchSection(section);
        });
    });
}

function switchSection(section) {
    // Update active nav item
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    document.querySelector(`[data-section="${section}"]`).classList.add('active');
    
    // Update active content section
    document.querySelectorAll('.content-section').forEach(sec => {
        sec.classList.remove('active');
    });
    document.getElementById(`${section}-section`).classList.add('active');
    
    // Update page title
    const titles = {
        'dashboard': 'Dashboard Overview',
        'mechanics': 'All Mechanics',
        'registration-requests': 'Registration Requests',
        'mechanics-by-city': 'Mechanics by City',
        'pending': 'Pending Approvals',
        'requests': 'Service Requests',
        'book-mechanic-requests': 'Book Mechanic Requests',
        'tracking': 'Request Tracking',
        'analytics': 'Detailed Analytics',
        'users': 'User Management',
        'mechanics-map': 'Mechanics Map',
        'live-tracking': 'Live Tracking',
        'active-jobs': 'Active Jobs',
        'banners': 'Carousel / Banners',
        'user-support': 'User Support',
        'mechanic-help': 'Mechanic Help Chat',
        'vehicle-catalog': 'Vehicle Catalog',
        'marketing-poster': 'Marketing Poster',
        'auth-video': 'Auth Background Video',
        'home-hero': 'Home Hero Graphic',
        'app-branding': 'App Branding',
        'nearest-mechanic': 'See nearest mechanic (map icons)'
    };
    document.getElementById('page-title').textContent = titles[section] || 'Dashboard';
    
    // Load section data
    switch(section) {
        case 'dashboard':
            loadDashboard();
            break;
        case 'mechanics':
            loadMechanics();
            break;
        case 'nearest-mechanic':
            loadNearestMechanicMapBranding();
            break;
        case 'registration-requests':
            loadRegistrationRequests();
            break;
        case 'mechanics-by-city':
            loadMechanicsByCity();
            break;
        case 'pending':
            loadPendingMechanics();
            break;
        case 'requests':
            loadRequests();
            break;
        case 'book-mechanic-requests':
            loadBookMechanicRequests();
            break;
        case 'tracking':
            loadTracking();
            break;
        case 'analytics':
            loadAnalytics();
            break;
        case 'users':
            loadUsers();
            break;
        case 'mechanics-map':
            loadMechanicsMap();
            break;
        case 'live-tracking':
            loadLiveTracking();
            break;
        case 'active-jobs':
            loadActiveJobs();
            break;
        case 'user-support':
            loadUserSupportThreads();
            break;
        case 'mechanic-help':
            loadHelpThreads();
            break;
        case 'banners':
            loadBanners();
            break;
        case 'vehicle-catalog':
            loadVehicleCatalog();
            break;
        case 'marketing-poster':
            loadMarketingPoster();
            break;
        case 'auth-video':
            loadAuthVideo();
            break;
        case 'home-hero':
            loadHomeHeroMedia();
            break;
        case 'app-branding':
            loadAppBranding();
            break;
        case 'car-bike-quick-icons':
            loadCarBikeQuickIcons();
            break;
        case 'app-update':
            loadAppVersion();
            break;
    }
}

// Dashboard
async function loadDashboard() {
    try {
        const range = document.querySelector('.chart-range-filter') ? document.querySelector('.chart-range-filter').value : 'lifetime';
        const url = getApiUrl(API_CONFIG.endpoints.analytics) + (range && range !== 'lifetime' ? '?range=' + encodeURIComponent(range) : '');
        const response = await fetch(url);
        const data = await response.json();
        analyticsData = data;
        
        updateDashboardStats(data);
        updateCharts(data);
        setupChartCardExpand();
        setupChartRangeFilters();
    } catch (error) {
        console.error('Error loading dashboard:', error);
        showError('Failed to load dashboard data');
    }
}

function setupChartCardExpand() {
    document.querySelectorAll('.chart-card[data-chart-id]').forEach(card => {
        card.style.cursor = 'pointer';
        card.onclick = function(e) {
            if (e.target.closest('.chart-range-filter') || e.target.closest('select')) return;
            card.classList.toggle('chart-expanded');
            if (card.classList.contains('chart-expanded')) {
                const canvas = card.querySelector('canvas');
                if (canvas) {
                    setTimeout(() => {
                        const chart = getChartByCanvasId(canvas.id);
                        if (chart && typeof chart.resize === 'function') chart.resize();
                    }, 100);
                }
            }
        };
    });
}

function getChartByCanvasId(id) {
    const map = {
        'requests-chart': requestsChart,
        'service-type-chart': serviceTypeChart,
        'dashboard-city-chart': dashboardCityChart,
        'dashboard-online-chart': dashboardOnlineChart
    };
    return map[id] || null;
}

function setupChartRangeFilters() {
    document.querySelectorAll('.chart-range-filter').forEach(sel => {
        sel.onclick = e => e.stopPropagation();
        sel.onchange = function() {
            chartRange = this.value;
            document.querySelectorAll('.chart-range-filter').forEach(s => { s.value = chartRange; });
            loadDashboard();
        };
    });
}

function updateDashboardStats(data) {
    document.getElementById('stat-total-mechanics').textContent = data.mechanics?.total || 0;
    document.getElementById('stat-approved-mechanics').textContent = data.mechanics?.approved || 0;
    document.getElementById('stat-pending-mechanics').textContent = data.mechanics?.pending || 0;
    document.getElementById('stat-total-requests').textContent = data.requests?.total || 0;
    document.getElementById('stat-completed-requests').textContent = data.requests?.completed || 0;
    
    const revenue = data.revenue?.total || 0;
    document.getElementById('stat-revenue').textContent = `₹${revenue.toLocaleString('en-IN')}`;
    
    const onlineEl = document.getElementById('stat-online');
    const offlineEl = document.getElementById('stat-offline');
    if (onlineEl) onlineEl.textContent = data.mechanics?.online ?? 0;
    if (offlineEl) offlineEl.textContent = data.mechanics?.offline ?? 0;

    const liveUsersEl = document.getElementById('stat-live-users');
    if (liveUsersEl) liveUsersEl.textContent = data.liveUsers ?? 0;

    const usageHoursEl = document.getElementById('stat-usage-hours');
    if (usageHoursEl) usageHoursEl.textContent = (data.totalUsageHours ?? 0).toFixed(1);

    const peakHour = data.peakHour ?? 0;
    const peakTimeEl = document.getElementById('stat-peak-time');
    if (peakTimeEl) peakTimeEl.textContent = String(peakHour).padStart(2, '0') + ':00';
    
    // Update pending badge
    const pendingBadge = document.getElementById('pending-badge');
    if (pendingBadge) {
        pendingBadge.textContent = data.mechanics?.pending || 0;
    }
    // Update registration requests badge and alert (new mechanic signups from app)
    const pendingReg = data.pendingRegistrationRequests ?? 0;
    const regBadge = document.getElementById('registration-requests-badge');
    if (regBadge) regBadge.textContent = pendingReg;
    const alertBanner = document.getElementById('registration-requests-alert');
    if (alertBanner) {
        alertBanner.style.display = pendingReg > 0 ? 'flex' : 'none';
        const countEl = document.getElementById('registration-requests-alert-count');
        if (countEl) countEl.textContent = pendingReg;
    }
}

function updateCharts(data) {
    // Requests by Status Chart
    const requestsCtx = document.getElementById('requests-chart');
    if (requestsChart) {
        requestsChart.destroy();
    }
    
    requestsChart = new Chart(requestsCtx, {
        type: 'doughnut',
        data: {
            labels: ['Pending', 'Accepted', 'Completed', 'Rejected'],
            datasets: [{
                data: [
                    data.requests?.pending || 0,
                    data.requests?.accepted || 0,
                    data.requests?.completed || 0,
                    data.requests?.rejected || 0
                ],
                backgroundColor: [
                    '#F59E0B',
                    '#3B82F6',
                    '#10B981',
                    '#EF4444'
                ]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
    
    // Requests by Service Type Chart
    const serviceTypeCtx = document.getElementById('service-type-chart');
    if (serviceTypeChart) {
        serviceTypeChart.destroy();
    }
    
    const serviceTypes = data.requestsByServiceType || {};
    const labels = Object.keys(serviceTypes);
    const values = Object.values(serviceTypes);
    
    serviceTypeChart = new Chart(serviceTypeCtx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Requests',
                data: values,
                backgroundColor: '#2563EB'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: true
                }
            }
        }
    });

    // Mechanics by City (dashboard)
    const cityData = data.mechanicsByCity || {};
    const cityLabels = Object.keys(cityData).length ? Object.keys(cityData) : ['No data'];
    const cityValues = Object.keys(cityData).length ? Object.values(cityData).map(c => c.total || c) : [0];
    const ctxCity = document.getElementById('dashboard-city-chart');
    if (ctxCity) {
        if (dashboardCityChart) dashboardCityChart.destroy();
        dashboardCityChart = new Chart(ctxCity, {
            type: 'bar',
            data: {
                labels: cityLabels,
                datasets: [{
                    label: 'Mechanics',
                    data: cityValues,
                    backgroundColor: 'rgba(37, 99, 235, 0.7)'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                indexAxis: 'y',
                scales: { x: { beginAtZero: true } }
            }
        });
    }

    // Online vs Offline (dashboard)
    const online = data.mechanics?.online || 0;
    const offline = data.mechanics?.offline || 0;
    const ctxOnline = document.getElementById('dashboard-online-chart');
    if (ctxOnline) {
        if (dashboardOnlineChart) dashboardOnlineChart.destroy();
        dashboardOnlineChart = new Chart(ctxOnline, {
            type: 'doughnut',
            data: {
                labels: ['Online', 'Offline'],
                datasets: [{
                    data: [online, offline],
                    backgroundColor: ['#10B981', '#64748B']
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                plugins: { legend: { position: 'bottom' } }
            }
        });
    }
}

// Mechanics
async function loadMechanics() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.mechanics));
        allMechanics = await response.json();
        displayMechanics(allMechanics);
    } catch (error) {
        console.error('Error loading mechanics:', error);
        showError('Failed to load mechanics');
    }
}

function displayMechanics(mechanics) {
    const tbody = document.getElementById('mechanics-table-body');
    if (mechanics.length === 0) {
        tbody.innerHTML = '<tr><td colspan="14" class="loading">No mechanics found</td></tr>';
        return;
    }
    
    tbody.innerHTML = mechanics.map(mechanic => `
        <tr>
            <td>
                ${mechanic.profilePhotoUrl 
                    ? `<span class="photo-thumb-clickable" data-url="${escapeAttr(mechanic.profilePhotoUrl)}" data-name="${escapeAttr(mechanic.name || 'Mechanic')}" title="Click to enlarge">
                     <img src="${mechanic.profilePhotoUrl}" alt="" class="user-photo-thumb" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
                     <span class="user-photo-placeholder" style="display:none;"><i class="fas fa-user-cog"></i></span></span>`
                    : `<span class="user-photo-placeholder"><i class="fas fa-user-cog"></i></span>`}
            </td>
            <td>${mechanic.id}</td>
            <td><strong>${mechanic.name || 'N/A'}</strong></td>
            <td>${mechanic.email || 'N/A'}</td>
            <td>${mechanic.phone || 'N/A'}</td>
            <td>${mechanic.specialty || 'N/A'}</td>
            <td>${mechanic.shopCity || mechanic.shop_city || 'N/A'}</td>
            <td>${mechanic.experience || 'N/A'}</td>
            <td><span class="status-badge ${(mechanic.status || 'Available').toLowerCase()}">${mechanic.status || 'Available'}</span></td>
            <td><span class="status-badge ${(mechanic.approvalStatus || 'PENDING').toLowerCase()}">${mechanic.approvalStatus || 'PENDING'}</span></td>
            <td>${mechanic.isBlocked ? '<span class="status-badge rejected">Blocked</span>' : '<span class="status-badge approved">Active</span>'}</td>
            <td>${mechanic.isSuspended ? '<span class="status-badge pending">Suspended</span>' : '<span class="status-badge approved">Active</span>'}</td>
            <td>${mechanic.isOnline ? '<span class="status-badge approved">Online</span>' : '<span class="status-badge pending">Offline</span>'}</td>
            <td>
                ${mechanic.approvalStatus !== 'APPROVED' ? `
                    <button class="btn-action btn-approve" onclick="approveMechanic(${mechanic.id})">Approve</button>
                ` : ''}
                ${mechanic.approvalStatus !== 'REJECTED' ? `
                    <button class="btn-action btn-reject" onclick="rejectMechanic(${mechanic.id})">Reject</button>
                ` : ''}
                ${!mechanic.isBlocked ? `
                    <button class="btn-action btn-reject" onclick="blockMechanic(${mechanic.id})" style="background: #DC2626;">Block</button>
                ` : `
                    <button class="btn-action btn-approve" onclick="unblockMechanic(${mechanic.id})">Unblock</button>
                `}
                ${!mechanic.isSuspended ? `
                    <button class="btn-action" onclick="suspendMechanic(${mechanic.id})" style="background: #F59E0B;">Suspend</button>
                ` : `
                    <button class="btn-action btn-approve" onclick="unsuspendMechanic(${mechanic.id})">Unsuspend</button>
                `}
                <button class="btn-action btn-view" onclick="viewMechanicProfile(${mechanic.id})">View Profile</button>
                <button class="btn-action btn-view" onclick="viewMechanicPerformance(${mechanic.id})">Performance</button>
            </td>
        </tr>
    `).join('');
}

// ========== See nearest mechanic: optional map marker icons (pins = approved mechanics in DB) ==========
async function loadNearestMechanicMapBranding() {
    const iconUrlEl = document.getElementById('nearest-mechanic-marker-icon-url');
    const userLocUrlEl = document.getElementById('user-location-marker-icon-url');
    try {
        const branding = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding)).then(r => r.ok ? r.json() : {});
        if (iconUrlEl) iconUrlEl.value = branding.nearestMechanicMarkerIconUrl || '';
        if (userLocUrlEl) userLocUrlEl.value = branding.userLocationMarkerIconUrl || '';
    } catch (e) {}
}

async function uploadUserLocationMarkerIcon() {
    const fileInput = document.getElementById('user-location-icon-file');
    const urlEl = document.getElementById('user-location-marker-icon-url');
    const statusEl = document.getElementById('user-location-icon-status');
    const btn = document.getElementById('user-location-icon-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select a PNG/JPG/WebP file first.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadUserLocationMarkerIcon), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            if (urlEl) urlEl.value = data.url;
            if (statusEl) statusEl.textContent = 'Uploaded. Click Save icon URL to apply.';
        } else {
            if (statusEl) statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function saveUserLocationMarkerIconUrl() {
    const urlEl = document.getElementById('user-location-marker-icon-url');
    const statusEl = document.getElementById('user-location-icon-status');
    const url = urlEl ? urlEl.value.trim() : '';
    try {
        const brandingRes = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding));
        const branding = brandingRes.ok ? await brandingRes.json() : {};
        const body = { ...branding, userLocationMarkerIconUrl: url || null };
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (r.ok) {
            if (statusEl) statusEl.textContent = 'User location icon URL saved.';
        } else {
            if (statusEl) statusEl.textContent = 'Save failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
}

async function uploadNearestMechanicMarkerIcon() {
    const fileInput = document.getElementById('nearest-mechanic-icon-file');
    const urlEl = document.getElementById('nearest-mechanic-marker-icon-url');
    const statusEl = document.getElementById('nearest-mechanic-icon-status');
    const btn = document.getElementById('nearest-mechanic-icon-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select a PNG/JPG/WebP file first.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadNearestMechanicMarkerIcon), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            if (urlEl) urlEl.value = data.url;
            if (statusEl) statusEl.textContent = 'Uploaded. Click Save icon URL to apply.';
        } else {
            if (statusEl) statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function saveNearestMechanicIconUrl() {
    const urlEl = document.getElementById('nearest-mechanic-marker-icon-url');
    const statusEl = document.getElementById('nearest-mechanic-icon-status');
    const url = urlEl ? urlEl.value.trim() : '';
    try {
        const brandingRes = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding));
        const branding = brandingRes.ok ? await brandingRes.json() : {};
        const body = { ...branding, nearestMechanicMarkerIconUrl: url || null };
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (r.ok) {
            if (statusEl) statusEl.textContent = 'Icon URL saved.';
        } else {
            if (statusEl) statusEl.textContent = 'Save failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
}

async function createMechanicFromAdmin() {
    const nameEl = document.getElementById('add-mechanic-name');
    const emailEl = document.getElementById('add-mechanic-email');
    const phoneEl = document.getElementById('add-mechanic-phone');
    const specialtyEl = document.getElementById('add-mechanic-specialty');
    const shopNameEl = document.getElementById('add-mechanic-shop-name');
    const shopCityEl = document.getElementById('add-mechanic-shop-city');
    const latEl = document.getElementById('add-mechanic-lat');
    const lngEl = document.getElementById('add-mechanic-lng');
    const statusEl = document.getElementById('add-mechanic-status');
    const btn = document.getElementById('add-mechanic-btn');
    const name = nameEl ? nameEl.value.trim() : '';
    const email = emailEl ? emailEl.value.trim() : '';
    const phone = phoneEl ? phoneEl.value.trim() : '';
    const lat = latEl ? latEl.value.trim() : '';
    const lng = lngEl ? lngEl.value.trim() : '';
    if (!name || !email) {
        if (statusEl) statusEl.textContent = 'Name and email are required.';
        return;
    }
    if (!lat || !lng || isNaN(parseFloat(lat)) || isNaN(parseFloat(lng))) {
        if (statusEl) statusEl.textContent = 'Valid latitude and longitude are required (shown on See nearest mechanic map and Book Mechanic).';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Adding...';
    try {
        const body = {
            name,
            email,
            phone: phone || null,
            specialty: (specialtyEl && specialtyEl.value.trim()) || 'General Repair',
            shopName: (shopNameEl && shopNameEl.value.trim()) || null,
            shopCity: (shopCityEl && shopCityEl.value.trim()) || null,
            latitude: lat,
            longitude: lng,
            approvalStatus: 'APPROVED',
            status: 'Available',
            nightTimeAvailable: false,
            experience: 'Not specified'
        };
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.createMechanic), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (r.ok) {
            const mechanic = await r.json();
            if (statusEl) statusEl.textContent = 'Added mechanic ID ' + mechanic.id + '. They will appear in the app for users nearby.';
            if (nameEl) nameEl.value = '';
            if (emailEl) emailEl.value = '';
            if (phoneEl) phoneEl.value = '';
            if (specialtyEl) specialtyEl.value = '';
            if (shopNameEl) shopNameEl.value = '';
            if (shopCityEl) shopCityEl.value = '';
            if (latEl) latEl.value = '';
            if (lngEl) lngEl.value = '';
            loadMechanics();
        } else {
            const err = await r.json().catch(() => ({}));
            if (statusEl) statusEl.textContent = err.message || err.error || 'Failed to add mechanic';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function loadMechanicsByCity() {
    try {
        const [analyticsRes, mechanicsRes] = await Promise.all([
            fetch(getApiUrl(API_CONFIG.endpoints.analytics)),
            fetch(getApiUrl(API_CONFIG.endpoints.mechanics))
        ]);
        const data = await analyticsRes.json();
        allMechanics = await mechanicsRes.json();
        
        const cityData = data.mechanicsByCity || {};
        const cityStats = Object.entries(cityData).map(([city, stats]) => ({
            city,
            total: stats.total || 0,
            online: stats.online || 0,
            offline: stats.offline || 0
        })).sort((a, b) => b.total - a.total);
        
        const grid = document.getElementById('city-stats-grid');
        grid.innerHTML = cityStats.map(s => `
            <div class="city-stat-card">
                <div class="city-stat-header">
                    <i class="fas fa-city"></i>
                    <h4>${s.city}</h4>
                </div>
                <div class="city-stat-body">
                    <div class="city-stat-row"><span>Total</span><strong>${s.total}</strong></div>
                    <div class="city-stat-row online"><span>Online</span><strong>${s.online}</strong></div>
                    <div class="city-stat-row offline"><span>Offline</span><strong>${s.offline}</strong></div>
                </div>
            </div>
        `).join('') || '<p class="no-data">No city data available</p>';
        
        const ctx1 = document.getElementById('mechanics-by-city-chart');
        if (ctx1) {
            if (mechanicsByCityChart) mechanicsByCityChart.destroy();
            mechanicsByCityChart = new Chart(ctx1, {
                type: 'bar',
                data: {
                    labels: cityStats.map(s => s.city),
                    datasets: [
                        { label: 'Online', data: cityStats.map(s => s.online), backgroundColor: '#10B981' },
                        { label: 'Offline', data: cityStats.map(s => s.offline), backgroundColor: '#64748B' }
                    ]
                },
                options: {
                    responsive: true,
                    scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true } },
                    plugins: { legend: { position: 'bottom' } }
                }
            });
        }
        
        const onlineTotal = allMechanics.filter(m => m.isOnline).length;
        const offlineTotal = allMechanics.filter(m => !m.isOnline).length;
        const ctx2 = document.getElementById('online-offline-chart');
        if (ctx2) {
            if (onlineOfflineChart) onlineOfflineChart.destroy();
            onlineOfflineChart = new Chart(ctx2, {
                type: 'doughnut',
                data: {
                    labels: ['Online', 'Offline'],
                    datasets: [{ data: [onlineTotal, offlineTotal], backgroundColor: ['#10B981', '#64748B'] }]
                },
                options: { responsive: true, plugins: { legend: { position: 'bottom' } } }
            });
        }
        
        const statusCounts = { Available: 0, Busy: 0, Offline: 0 };
        allMechanics.forEach(m => {
            const s = m.status || 'Available';
            statusCounts[s] = (statusCounts[s] || 0) + 1;
        });
        const ctx3 = document.getElementById('status-distribution-chart');
        if (ctx3) {
            if (statusDistChart) statusDistChart.destroy();
            statusDistChart = new Chart(ctx3, {
                type: 'pie',
                data: {
                    labels: Object.keys(statusCounts),
                    datasets: [{
                        data: Object.values(statusCounts),
                        backgroundColor: ['#10B981', '#F59E0B', '#EF4444']
                    }]
                },
                options: { responsive: true, plugins: { legend: { position: 'bottom' } } }
            });
        }
    } catch (error) {
        console.error('Error loading mechanics by city:', error);
        showError('Failed to load mechanics by city');
    }
}

function filterMechanics() {
    const filter = document.getElementById('mechanic-filter').value;
    let filtered = allMechanics;
    
    if (filter !== 'all') {
        filtered = allMechanics.filter(m => (m.approvalStatus || 'PENDING') === filter);
    }
    
    displayMechanics(filtered);
}

// Registration Requests (new mechanic applications from app)
async function loadRegistrationRequests() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.registrationRequests));
        const list = await response.json();
        const pending = (list || []).filter(r => (r.approvalStatus || '').toUpperCase() === 'PENDING');
        const badge = document.getElementById('registration-requests-badge');
        if (badge) badge.textContent = pending.length;
        displayRegistrationRequests(list || []);
    } catch (error) {
        console.error('Error loading registration requests:', error);
        showError('Failed to load registration requests');
    }
}

let registrationRequestsList = [];

function displayRegistrationRequests(list) {
    registrationRequestsList = list || [];
    const tbody = document.getElementById('registration-requests-table-body');
    if (!tbody) return;
    if (list.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="loading">No registration requests</td></tr>';
        return;
    }
    tbody.innerHTML = list.map(r => {
        const status = (r.approvalStatus || 'PENDING').toUpperCase();
        const statusClass = status === 'APPROVED' ? 'approved' : status === 'REJECTED' ? 'rejected' : 'pending';
        const actions = status === 'PENDING'
            ? `<button class="btn-action btn-view" onclick="viewRegistrationRequestDetail(${r.id})" style="margin-right:6px;"><i class="fas fa-eye"></i> View</button>
               <button class="btn-action btn-approve" onclick="approveRegistrationRequest(${r.id})">Approve</button>
               <button class="btn-action btn-reject" onclick="rejectRegistrationRequest(${r.id})">Reject</button>`
            : `<button class="btn-action btn-view" onclick="viewRegistrationRequestDetail(${r.id})"><i class="fas fa-eye"></i> View</button>
               <span class="status-badge ${statusClass}">${status}</span>`;
        return `
        <tr>
            <td>${r.id}</td>
            <td><strong>${r.name || 'N/A'}</strong></td>
            <td>${r.email || 'N/A'}</td>
            <td>${r.phone || 'N/A'}</td>
            <td>${r.shopName || 'N/A'}</td>
            <td><span class="status-badge ${statusClass}">${status}</span></td>
            <td>${actions}</td>
        </tr>`;
    }).join('');
}

async function approveRegistrationRequest(id) {
    if (!confirm('Approve this mechanic? They will log in with the email and password they used when registering.')) return;
    try {
        const response = await fetch(
            `${getApiUrl(API_CONFIG.endpoints.registrationRequests)}/${id}/approve`,
            { method: 'PUT' }
        );
        if (response.ok) {
            showSuccess('Mechanic approved');
            loadRegistrationRequests();
            loadDashboard();
        } else {
            showError('Failed to approve');
        }
    } catch (error) {
        console.error('Error approving registration:', error);
        showError('Failed to approve');
    }
}

async function rejectRegistrationRequest(id) {
    const reason = prompt('Rejection reason (optional):');
    if (reason === null) return; // cancelled
    try {
        const response = await fetch(
            `${getApiUrl(API_CONFIG.endpoints.registrationRequests)}/${id}/reject`,
            { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ reason: reason || '' }) }
        );
        if (response.ok) {
            showSuccess('Registration rejected');
            loadRegistrationRequests();
            loadDashboard();
        } else {
            showError('Failed to reject');
        }
    } catch (error) {
        console.error('Error rejecting registration:', error);
        showError('Failed to reject');
    }
}

// Pending Mechanics
async function loadPendingMechanics() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.pendingMechanics));
        const pending = await response.json();
        displayPendingMechanics(pending);
    } catch (error) {
        console.error('Error loading pending mechanics:', error);
        showError('Failed to load pending mechanics');
    }
}

function displayPendingMechanics(mechanics) {
    const tbody = document.getElementById('pending-table-body');
    if (mechanics.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="loading">No pending approvals</td></tr>';
        return;
    }
    
    tbody.innerHTML = mechanics.map(mechanic => `
        <tr>
            <td>
                ${mechanic.profilePhotoUrl
                    ? `<span class="photo-thumb-clickable" data-url="${escapeAttr(mechanic.profilePhotoUrl)}" data-name="${escapeAttr(mechanic.name || 'Mechanic')}" title="Click to enlarge">
                     <img src="${mechanic.profilePhotoUrl}" alt="" class="user-photo-thumb" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
                     <span class="user-photo-placeholder" style="display:none;"><i class="fas fa-user-cog"></i></span></span>`
                    : `<span class="user-photo-placeholder"><i class="fas fa-user-cog"></i></span>`}
            </td>
            <td>${mechanic.id}</td>
            <td><strong>${mechanic.name || 'N/A'}</strong></td>
            <td>${mechanic.email || 'N/A'}</td>
            <td>${mechanic.phone || 'N/A'}</td>
            <td>${mechanic.specialty || 'N/A'}</td>
            <td>${mechanic.experience || 'N/A'}</td>
            <td>${mechanic.latitude}, ${mechanic.longitude}</td>
            <td>
                <button class="btn-action btn-approve" onclick="approveMechanic(${mechanic.id})">Approve</button>
                <button class="btn-action btn-reject" onclick="rejectMechanic(${mechanic.id})">Reject</button>
            </td>
        </tr>
    `).join('');
}

// Approve/Reject Mechanics
async function approveMechanic(id) {
    if (!confirm('Are you sure you want to approve this mechanic?')) return;
    
    try {
        const response = await fetch(
            `${getApiUrl(API_CONFIG.endpoints.approveMechanic)}/${id}/approve`,
            { method: 'PUT' }
        );
        
        if (response.ok) {
            showSuccess('Mechanic approved successfully');
            refreshData();
        } else {
            showError('Failed to approve mechanic');
        }
    } catch (error) {
        console.error('Error approving mechanic:', error);
        showError('Failed to approve mechanic');
    }
}

async function rejectMechanic(id) {
    if (!confirm('Are you sure you want to reject this mechanic?')) return;
    
    try {
        const response = await fetch(
            `${getApiUrl(API_CONFIG.endpoints.rejectMechanic)}/${id}/reject`,
            { method: 'PUT' }
        );
        
        if (response.ok) {
            showSuccess('Mechanic rejected');
            refreshData();
        } else {
            showError('Failed to reject mechanic');
        }
    } catch (error) {
        console.error('Error rejecting mechanic:', error);
        showError('Failed to reject mechanic');
    }
}

// Service Requests (mechanic map for showing mechanic photo in requests)
let mechanicMapById = {};

async function loadRequests() {
    try {
        const [requestsRes, mechanicsRes] = await Promise.all([
            fetch(getApiUrl(API_CONFIG.endpoints.requests)),
            fetch(getApiUrl(API_CONFIG.endpoints.mechanics))
        ]);
        allRequests = await requestsRes.json();
        const mechanics = await mechanicsRes.json();
        mechanicMapById = {};
        mechanics.forEach(m => { mechanicMapById[m.id] = m; });
        displayRequests(allRequests);
    } catch (error) {
        console.error('Error loading requests:', error);
        showError('Failed to load service requests');
    }
}

function displayRequests(requests) {
    const tbody = document.getElementById('requests-table-body');
    if (requests.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="loading">No requests found</td></tr>';
        return;
    }
    
    tbody.innerHTML = requests.map(request => {
        const requestTime = request.requestTime ? new Date(request.requestTime).toLocaleString() : 'N/A';
        const responseTime = request.responseTime ? new Date(request.responseTime).toLocaleString() : 'N/A';
        const mechanic = request.mechanicId ? mechanicMapById[request.mechanicId] : null;
        const mechanicPhoto = mechanic && mechanic.profilePhotoUrl
            ? `<span class="photo-thumb-clickable" data-url="${escapeAttr(mechanic.profilePhotoUrl)}" data-name="${escapeAttr(mechanic.name || 'Mechanic')}" title="Click to enlarge"><img src="${mechanic.profilePhotoUrl}" alt="" class="user-photo-thumb" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';"><span class="user-photo-placeholder" style="display:none;"><i class="fas fa-user-cog"></i></span></span>`
            : `<span class="user-photo-placeholder"><i class="fas fa-user-cog"></i></span>`;
        const mechanicName = mechanic ? (mechanic.name || 'N/A') : (request.mechanicId || '—');
        
        return `
            <tr>
                <td>${request.id}</td>
                <td><strong>${request.customerName || 'N/A'}</strong><br><small>${request.customerEmail || ''}</small></td>
                <td>${request.serviceType || 'N/A'}</td>
                <td><div style="display:flex;align-items:center;gap:8px;">${mechanicPhoto}<span>${mechanicName}</span></div></td>
                <td>₹${(request.amount || 0).toLocaleString('en-IN')}</td>
                <td><span class="status-badge ${(request.status || 'PENDING').toLowerCase()}">${request.status || 'PENDING'}</span></td>
                <td>${requestTime}</td>
                <td>${responseTime}</td>
            </tr>
        `;
    }).join('');
}

async function loadBookMechanicRequests() {
    const tbody = document.getElementById('book-mechanic-requests-table-body');
    try {
        const [requestsRes, mechanicsRes] = await Promise.all([
            fetch(getApiUrl(API_CONFIG.endpoints.requests)),
            fetch(getApiUrl(API_CONFIG.endpoints.mechanics))
        ]);
        const requests = await requestsRes.json();
        const mechanics = await mechanicsRes.json();
        const mechanicMapById = {};
        mechanics.forEach(m => { mechanicMapById[m.id] = m; });
        if (requests.length === 0) {
            tbody.innerHTML = '<tr><td colspan="9">No requests</td></tr>';
            return;
        }
        tbody.innerHTML = requests.map(r => {
            const customer = (r.customerName || 'N/A') + (r.customerEmail ? '<br><small>' + escapeAttr(r.customerEmail) + '</small>' : '');
            const problem = r.problemCategory || r.serviceType || '—';
            const vehicle = [r.vehicleMakeName, r.vehicleModelName].filter(Boolean).join(' ') || '—';
            const location = (r.latitude && r.longitude) ? (r.latitude + ', ' + r.longitude) : '—';
            let sentTo = '—';
            if (r.notifiedMechanicIds) {
                try {
                    const ids = JSON.parse(r.notifiedMechanicIds);
                    sentTo = Array.isArray(ids) ? ids.join(', ') : r.notifiedMechanicIds;
                } catch (e) {
                    sentTo = r.notifiedMechanicIds;
                }
            }
            const acceptedBy = r.acceptedMechanicId != null
                ? (mechanicMapById[r.acceptedMechanicId] ? mechanicMapById[r.acceptedMechanicId].name + ' (ID ' + r.acceptedMechanicId + ')' : 'ID ' + r.acceptedMechanicId)
                : '—';
            const status = r.status || '—';
            const time = r.requestTime ? new Date(r.requestTime).toLocaleString() : '—';
            return '<tr><td>' + r.id + '</td><td>' + customer + '</td><td>' + escapeAttr(problem) + '</td><td>' + escapeAttr(vehicle) + '</td><td><small>' + escapeAttr(location) + '</small></td><td><small>' + escapeAttr(sentTo) + '</small></td><td>' + escapeAttr(acceptedBy) + '</td><td><span class="status-badge ' + (status.toLowerCase()) + '">' + escapeAttr(status) + '</span></td><td><small>' + time + '</small></td></tr>';
        }).join('');
    } catch (err) {
        console.error('loadBookMechanicRequests:', err);
        tbody.innerHTML = '<tr><td colspan="9" class="loading">Failed to load</td></tr>';
    }
}

function filterRequests() {
    const filter = document.getElementById('request-filter').value;
    let filtered = allRequests;
    
    if (filter !== 'all') {
        filtered = allRequests.filter(r => (r.status || 'PENDING') === filter);
    }
    
    displayRequests(filtered);
}

// Request Tracking
async function loadTracking() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.tracking));
        const data = await response.json();
        displayTracking(data.mechanicTracking || []);
    } catch (error) {
        console.error('Error loading tracking:', error);
        showError('Failed to load tracking data');
    }
}

function displayTracking(tracking) {
    const tbody = document.getElementById('tracking-table-body');
    if (tracking.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="loading">No tracking data available</td></tr>';
        return;
    }
    
    tbody.innerHTML = tracking.map(item => `
        <tr>
            <td>${item.mechanicId}</td>
            <td><strong>${item.mechanicName || 'Unknown'}</strong></td>
            <td>${item.totalRequests}</td>
            <td><span class="status-badge accepted">${item.accepted}</span></td>
            <td><span class="status-badge completed">${item.completed}</span></td>
            <td><span class="status-badge pending">${item.pending}</span></td>
            <td>${item.avgResponseTimeMinutes || 0} min</td>
            <td>
                <button class="btn-action btn-view" onclick="viewMechanicPerformance(${item.mechanicId})">View Details</button>
            </td>
        </tr>
    `).join('');
}

// Mechanic Performance
async function viewMechanicPerformance(id) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanicPerformance)}/${id}/performance`);
        const performance = await response.json();
        
        const content = document.getElementById('mechanic-performance-content');
        content.innerHTML = `
            <div class="analytics-content">
                <div class="analytics-item">
                    <label>Total Requests:</label>
                    <value>${performance.totalRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Accepted Requests:</label>
                    <value>${performance.acceptedRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Completed Requests:</label>
                    <value>${performance.completedRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Rejected Requests:</label>
                    <value>${performance.rejectedRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Response Rate:</label>
                    <value>${(performance.responseRate || 0).toFixed(2)}%</value>
                </div>
                <div class="analytics-item">
                    <label>Completion Rate:</label>
                    <value>${(performance.completionRate || 0).toFixed(2)}%</value>
                </div>
                <div class="analytics-item">
                    <label>Total Earnings:</label>
                    <value>₹${(performance.totalEarnings || 0).toLocaleString('en-IN')}</value>
                </div>
            </div>
        `;
        
        document.getElementById('mechanic-modal').style.display = 'block';
    } catch (error) {
        console.error('Error loading mechanic performance:', error);
        showError('Failed to load mechanic performance');
    }
}

// Analytics
function loadAnalytics() {
    if (!analyticsData || Object.keys(analyticsData).length === 0) {
        loadDashboard().then(() => displayAnalytics());
    } else {
        displayAnalytics();
    }
}

let usersByCityChart = null;
let usersByStateChart = null;

function displayAnalytics() {
    const data = analyticsData;
    
    // User Analytics (live users, usage hours, peak time)
    const userStatsEl = document.getElementById('user-analytics-stats');
    if (userStatsEl) {
        const peakHour = data.peakHour ?? 0;
        userStatsEl.innerHTML = `
            <div class="analytics-item highlight">
                <label><i class="fas fa-user-clock"></i> Live Users (last 5 min)</label>
                <value>${data.liveUsers ?? 0}</value>
            </div>
            <div class="analytics-item">
                <label><i class="fas fa-clock"></i> Total App Usage (hours)</label>
                <value>${(data.totalUsageHours ?? 0).toFixed(1)}</value>
            </div>
            <div class="analytics-item">
                <label><i class="fas fa-chart-line"></i> Peak Hour</label>
                <value>${String(peakHour).padStart(2, '0')}:00</value>
            </div>
        `;
    }

    // Users by City & State charts
    const cityData = data.usersByCity || {};
    const stateData = data.usersByState || {};
    const cityLabels = Object.keys(cityData).slice(0, 10);
    const cityValues = cityLabels.map(c => cityData[c] || 0);
    const stateLabels = Object.keys(stateData).slice(0, 10);
    const stateValues = stateLabels.map(s => stateData[s] || 0);

    const ctxCity = document.getElementById('users-by-city-chart');
    if (ctxCity) {
        if (usersByCityChart) usersByCityChart.destroy();
        usersByCityChart = new Chart(ctxCity, {
            type: 'bar',
            data: {
                labels: cityLabels.length ? cityLabels : ['No data'],
                datasets: [{ label: 'Users', data: cityValues.length ? cityValues : [0], backgroundColor: 'rgba(112, 109, 199, 0.8)' }]
            },
            options: { responsive: true, scales: { y: { beginAtZero: true } } }
        });
    }
    const ctxState = document.getElementById('users-by-state-chart');
    if (ctxState) {
        if (usersByStateChart) usersByStateChart.destroy();
        usersByStateChart = new Chart(ctxState, {
            type: 'bar',
            data: {
                labels: stateLabels.length ? stateLabels : ['No data'],
                datasets: [{ label: 'Users', data: stateValues.length ? stateValues : [0], backgroundColor: 'rgba(99, 102, 241, 0.8)' }]
            },
            options: { responsive: true, scales: { y: { beginAtZero: true } } }
        });
    }
    
    // Mechanic Stats
    const mechanicStats = document.getElementById('mechanic-stats');
    mechanicStats.innerHTML = `
        <div class="analytics-item">
            <label>Total Mechanics:</label>
            <value>${data.mechanics?.total || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Approved:</label>
            <value>${data.mechanics?.approved || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Pending:</label>
            <value>${data.mechanics?.pending || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Rejected:</label>
            <value>${data.mechanics?.rejected || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Active:</label>
            <value>${data.mechanics?.active || 0}</value>
        </div>
    `;
    
    // Request Stats
    const requestStats = document.getElementById('request-stats');
    requestStats.innerHTML = `
        <div class="analytics-item">
            <label>Total Requests:</label>
            <value>${data.requests?.total || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Pending:</label>
            <value>${data.requests?.pending || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Accepted:</label>
            <value>${data.requests?.accepted || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Completed:</label>
            <value>${data.requests?.completed || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Rejected:</label>
            <value>${data.requests?.rejected || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Recent (7 days):</label>
            <value>${data.requests?.recent7Days || 0}</value>
        </div>
    `;
    
    // Revenue Stats
    const revenueStats = document.getElementById('revenue-stats');
    revenueStats.innerHTML = `
        <div class="analytics-item">
            <label>Total Revenue:</label>
            <value>₹${(data.revenue?.total || 0).toLocaleString('en-IN')}</value>
        </div>
        <div class="analytics-item">
            <label>From Requests:</label>
            <value>₹${(data.revenue?.totalFromRequests || 0).toLocaleString('en-IN')}</value>
        </div>
        <div class="analytics-item">
            <label>From Payments:</label>
            <value>₹${(data.revenue?.totalFromPayments || 0).toLocaleString('en-IN')}</value>
        </div>
    `;
    
    // Payment Stats
    const paymentStats = document.getElementById('payment-stats');
    paymentStats.innerHTML = `
        <div class="analytics-item">
            <label>Total Payments:</label>
            <value>${data.payments?.total || 0}</value>
        </div>
        <div class="analytics-item">
            <label>Successful:</label>
            <value>${data.payments?.successful || 0}</value>
        </div>
    `;
}

// Modal
function setupModal() {
    const modal = document.getElementById('mechanic-modal');
    const profileModal = document.getElementById('mechanic-profile-modal');
    const photoModal = document.getElementById('photo-preview-modal');
    const closeBtns = document.querySelectorAll('#mechanic-modal .close');
    
    closeBtns.forEach(btn => {
        btn.onclick = function() { modal.style.display = 'none'; };
    });
    
    window.onclick = function(event) {
        if (event.target === modal) modal.style.display = 'none';
        if (event.target === profileModal) closeProfileModal();
        if (event.target === photoModal) closePhotoModal();
    };
}

// Refresh Data
function refreshData() {
    const activeSection = document.querySelector('.content-section.active').id;
    switch(activeSection) {
        case 'dashboard-section':
            loadDashboard();
            break;
        case 'mechanics-section':
            loadMechanics();
            break;
        case 'mechanics-by-city-section':
            loadMechanicsByCity();
            break;
        case 'pending-section':
            loadPendingMechanics();
            break;
        case 'requests-section':
            loadRequests();
            break;
        case 'book-mechanic-requests-section':
            loadBookMechanicRequests();
            break;
        case 'tracking-section':
            loadTracking();
            break;
        case 'analytics-section':
            loadAnalytics();
            break;
        case 'users-section':
            loadUsers();
            break;
        case 'mechanics-map-section':
            loadMechanicsMap();
            break;
        case 'live-tracking-section':
            loadLiveTracking();
            break;
        case 'active-jobs-section':
            loadActiveJobs();
            break;
        case 'user-support-section':
            loadUserSupportThreads();
            break;
    }
}

// ========== USER SUPPORT (Customer support from app) ==========
var USER_SUPPORT_API = '/api/admin/user-support'; // exact path (with hyphen)
let userSupportPollTimer = null;
let userSupportOpenEmail = null;
let userSupportTypingTimeout = null;
const USER_SUPPORT_POLL_MS = 2500;

async function loadUserSupportThreads() {
    const el = document.getElementById('user-support-threads-list');
    if (!el) return;
    el.innerHTML = '<div class="loading">Loading...</div>';
    try {
        const res = await fetch(getApiUrl(USER_SUPPORT_API + '/threads'));
        if (!res.ok) {
            const fallback = await fetch(getApiUrl(USER_SUPPORT_API + '/messages'));
            if (!fallback.ok) {
                el.innerHTML = '<p class="muted">Failed to load. Check backend at ' + (typeof API_CONFIG !== 'undefined' ? API_CONFIG.baseUrl : '') + '</p>';
                return;
            }
            const arr = await fallback.json().catch(function() { return []; });
            const threads = Array.isArray(arr) ? arr.map(function(email) { return { email: email, closed: false }; }) : [];
            renderUserSupportThreadList(el, threads);
            return;
        }
        const threads = await res.json().catch(function() { return []; });
        if (!Array.isArray(threads) || threads.length === 0) {
            el.innerHTML = '<p class="muted">No conversations yet.</p>';
            return;
        }
        renderUserSupportThreadList(el, threads);
    } catch (e) {
        el.innerHTML = '<p class="muted">Error loading. Check network and backend.</p>';
    }
}

function renderUserSupportThreadList(el, threads) {
    el.innerHTML = threads.map(t => {
        var email = typeof t === 'string' ? t : (t.email || '');
        var closed = typeof t === 'object' && t.closed;
        var badge = closed ? '<span class="support-thread-badge closed">Solved</span>' : '<span class="support-thread-badge open">Open</span>';
        return '<div class="support-thread-item help-thread-item" data-email="' + escapeAttr(email) + '"><i class="fas fa-user"></i> ' + escapeAttr(email) + badge + '</div>';
    }).join('');
    el.querySelectorAll('.help-thread-item').forEach(item => {
        item.addEventListener('click', function() {
            document.querySelectorAll('.support-thread-item').forEach(x => x.classList.remove('active'));
            this.classList.add('active');
            openUserSupportThread(this.getAttribute('data-email'));
        });
    });
}

function groupMessagesByDate(messages) {
    const groups = {};
    (messages || []).forEach(m => {
        const d = m.createdAt ? new Date(m.createdAt) : new Date();
        const key = d.toDateString();
        if (!groups[key]) groups[key] = [];
        groups[key].push(m);
    });
    return groups;
}

function renderUserSupportMessages(messages) {
    const listEl = document.getElementById('user-support-messages-list');
    if (!listEl) return;
    if (!Array.isArray(messages) || messages.length === 0) {
        listEl.innerHTML = '<p class="muted">No messages yet. Start the conversation below.</p>';
        return;
    }
    const groups = groupMessagesByDate(messages);
    let html = '';
    Object.keys(groups).sort((a,b) => new Date(a) - new Date(b)).forEach(dateKey => {
        html += '<div class="support-msg-date">' + escapeAttr(new Date(dateKey).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })) + '</div>';
        groups[dateKey].forEach(m => {
            const isAdmin = (m.sender || '').toUpperCase() === 'ADMIN';
            const isSystem = (m.messageType || '').indexOf('PHOTO_PERMISSION') >= 0 || (m.messageType || '') === 'ADMIN_JOINED' || (m.messageType || '') === 'CONVERSATION_ENDED';
            const isAdminJoined = (m.messageType || '') === 'ADMIN_JOINED';
            const time = m.createdAt ? new Date(m.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
            const bubbleClass = isSystem || isAdminJoined ? 'system' : (isAdmin ? 'admin' : 'user');
            let body = escapeAttr(m.message || '');
            if (m.imageUrl) {
                var imgSrc = m.imageUrl;
                if (imgSrc.indexOf('http') !== 0 && typeof API_CONFIG !== 'undefined' && API_CONFIG.baseUrl) {
                    imgSrc = API_CONFIG.baseUrl.replace(/\/$/, '') + (imgSrc.indexOf('/') === 0 ? imgSrc : '/' + imgSrc);
                }
                body += '<br><img src="' + escapeAttr(imgSrc) + '" class="support-msg-img" alt="Photo" onerror="this.style.display=\'none\';this.nextElementSibling&&this.nextElementSibling.classList.remove(\'hidden\');" onclick="showPhotoModal(\'' + escapeAttr(imgSrc) + '\', \'Support photo\')"><span class="support-msg-img-fallback hidden">Image unavailable</span>';
            }
            var icon = isSystem || isAdminJoined ? '' : (isAdmin ? '<div class="support-msg-icon support-msg-icon-admin"><i class="fas fa-headset"></i></div>' : '<div class="support-msg-icon support-msg-icon-user"><i class="fas fa-user"></i></div>');
            var align = (isAdmin && !isSystem && !isAdminJoined) ? 'right' : 'left';
            html += '<div class="support-msg-row support-msg-row-' + align + '">' + (align === 'right' ? '' : icon) + '<div class="support-msg-bubble ' + bubbleClass + '">' + body + '<div class="support-msg-time">' + (isAdmin ? 'Support' : 'Customer') + ' · ' + time + '</div></div>' + (align === 'right' ? icon : '') + '</div>';
        });
    });
    listEl.innerHTML = html;
    listEl.scrollTop = listEl.scrollHeight;
    updateUserSupportJoinBar(messages);
    updateUserSupportClosedState(messages);
}

function updateUserSupportClosedState(messages) {
    var replyBox = document.getElementById('user-support-reply-box');
    var closedBar = document.getElementById('user-support-closed-bar');
    var endBtn = document.getElementById('user-support-end-btn');
    if (!replyBox || !closedBar) return;
    var closed = false;
    if (Array.isArray(messages) && messages.length > 0) {
        var last = messages[messages.length - 1];
        closed = (last.messageType || '') === 'CONVERSATION_ENDED';
    }
    if (closed) {
        replyBox.style.display = 'none';
        if (closedBar) closedBar.style.display = 'flex';
        if (endBtn) endBtn.style.display = 'none';
    } else {
        if (replyBox.style.display !== 'block') replyBox.style.display = 'block';
        closedBar.style.display = 'none';
        if (endBtn) endBtn.style.display = 'inline-flex';
    }
}

function updateUserSupportJoinBar(messages) {
    var bar = document.getElementById('user-support-join-bar');
    if (!bar) return;
    if (!Array.isArray(messages) || messages.length === 0) { bar.style.display = 'none'; return; }
    var lastHelp = null, lastJoin = null;
    messages.forEach(function(m) {
        var type = (m.messageType || '');
        var at = m.createdAt ? new Date(m.createdAt).getTime() : 0;
        if (type === 'HELP_REQUESTED') lastHelp = at;
        if (type === 'ADMIN_JOINED') lastJoin = at;
    });
    if (lastHelp != null && (lastJoin == null || lastJoin < lastHelp)) bar.style.display = 'flex';
    else bar.style.display = 'none';
}

async function joinUserSupportChat() {
    var email = document.getElementById('user-support-reply-email').value;
    if (!email) return;
    try {
        var res = await fetch(getApiUrl(USER_SUPPORT_API + '/join'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email }) });
        if (res.ok) {
            showSuccess('You joined. Customer can now chat.');
            document.getElementById('user-support-join-bar').style.display = 'none';
            loadUserSupportMessagesOnly(email);
        } else showError('Failed to join');
    } catch (e) { showError('Failed to join'); }
}

async function endUserSupportConversation() {
    var email = document.getElementById('user-support-reply-email').value;
    if (!email) return;
    if (!confirm('End this conversation? The customer will see a thank-you message and this thread will move to recent solved.')) return;
    try {
        var res = await fetch(getApiUrl(USER_SUPPORT_API + '/end-conversation'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email }) });
        if (res.ok) {
            showSuccess('Conversation ended. Thread saved in recent solved.');
            loadUserSupportMessagesOnly(email);
            loadUserSupportThreads();
        } else showError('Failed to end conversation');
    } catch (e) { showError('Failed to end conversation'); }
}

async function openUserSupportThread(email) {
    if (userSupportPollTimer) { clearInterval(userSupportPollTimer); userSupportPollTimer = null; }
    userSupportOpenEmail = email;
    document.getElementById('user-support-reply-email').value = email;
    document.getElementById('user-support-chat-title').textContent = email;
    document.getElementById('user-support-reply-box').style.display = 'block';
    document.getElementById('user-support-typing').style.display = 'none';
    const listEl = document.getElementById('user-support-messages-list');
    listEl.innerHTML = '<div class="loading">Loading...</div>';
    await loadUserSupportMessagesOnly(email);
    loadUserSupportCustomerDetails(email);
    checkUserSupportPhotoPermission(email);
    updateUserSupportJoinBar([]);
    userSupportPollTimer = setInterval(function() {
        if (userSupportOpenEmail === email) {
            loadUserSupportMessagesOnly(email);
            fetch(getApiUrl(USER_SUPPORT_API + '/typing') + '?email=' + encodeURIComponent(email)).then(r => r.json()).then(d => {
                document.getElementById('user-support-typing').style.display = (d.userTyping ? 'block' : 'none');
            }).catch(() => {});
        }
    }, USER_SUPPORT_POLL_MS);
}

async function loadUserSupportMessagesOnly(email) {
    const listEl = document.getElementById('user-support-messages-list');
    if (userSupportOpenEmail !== email) return;
    try {
        const res = await fetch(getApiUrl(USER_SUPPORT_API + '/messages') + '?email=' + encodeURIComponent(email));
        if (!res.ok || userSupportOpenEmail !== email) return;
        const messages = await res.json();
        if (userSupportOpenEmail === email) renderUserSupportMessages(messages);
    } catch (e) {}
}

async function loadUserSupportCustomerDetails(email) {
    const panel = document.getElementById('user-support-customer-panel');
    if (!panel) return;
    try {
        const [res, vehicleRes] = await Promise.all([
            fetch(getApiUrl(USER_SUPPORT_API + '/customer-details') + '?email=' + encodeURIComponent(email)),
            fetch(getApiUrl('/api/vehicle/my') + '?email=' + encodeURIComponent(email))
        ]);
        if (!res.ok) { panel.innerHTML = '<p class="muted">Could not load details.</p>'; return; }
        const data = await res.json();
        const user = data.user || {};
        const bookings = data.bookings || [];
        let vehiclesHtml = '';
        if (vehicleRes.ok) {
            const vehicles = await vehicleRes.json();
            vehiclesHtml = '<h4 style="margin-top:16px;"><i class="fas fa-car"></i> Vehicles</h4>' +
                (!vehicles || vehicles.length === 0 ? '<p class="muted">No vehicles added.</p>' :
                    '<div class="user-vehicles-detail-list">' + vehicles.map((v, idx) => {
                        const type = (v.type || 'CAR') === 'BIKE' ? 'Bike' : 'Car';
                        const make = v.makeName || '—';
                        const model = v.modelName || '—';
                        const plate = v.plateNumber || '—';
                        const year = v.year || '—';
                        const fuel = v.fuelType || '—';
                        const def = v.isDefault ? ' <span class="support-thread-badge" style="font-size:10px;">Default</span>' : '';
                        return '<div class="user-vehicle-detail-card">' +
                            '<div class="user-vehicle-detail-header">#' + (idx + 1) + ' ' + escapeAttr(((make + ' ' + model).trim() || 'Vehicle').replace(/^—\s*—$/, 'Vehicle')) + def + '</div>' +
                            '<table class="user-vehicle-detail-table"><tbody>' +
                            '<tr><td>Type</td><td>' + escapeAttr(type) + '</td></tr>' +
                            '<tr><td>Make</td><td>' + escapeAttr(make) + '</td></tr>' +
                            '<tr><td>Model</td><td>' + escapeAttr(model) + '</td></tr>' +
                            '<tr><td>Plate number</td><td>' + escapeAttr(plate) + '</td></tr>' +
                            '<tr><td>Year</td><td>' + escapeAttr(year) + '</td></tr>' +
                            '<tr><td>Fuel type</td><td>' + escapeAttr(fuel) + '</td></tr>' +
                            '</tbody></table></div>';
                    }).join('') + '</div>');
        }
        panel.innerHTML = '<h4><i class="fas fa-user"></i> Profile</h4>' +
            '<div class="support-customer-detail"><i class="fas fa-envelope"></i> ' + escapeAttr(user.email || email) + '</div>' +
            '<div class="support-customer-detail"><i class="fas fa-id-badge"></i> ' + escapeAttr(user.name || '—') + '</div>' +
            '<div class="support-customer-detail"><i class="fas fa-phone"></i> ' + escapeAttr(user.phone || '—') + '</div>' +
            '<div class="support-customer-detail"><i class="fas fa-birthday-cake"></i> ' + escapeAttr(user.dateOfBirth || '—') + '</div>' +
            '<div class="support-customer-detail"><i class="fas fa-venus-mars"></i> ' + escapeAttr(user.gender || '—') + '</div>' +
            '<h4 style="margin-top:16px;"><i class="fas fa-tools"></i> Services / Bookings</h4>' +
            (bookings.length === 0 ? '<p class="muted">No bookings yet.</p>' :
                '<div style="font-size:12px;">' + bookings.slice(0, 10).map(b => '<div style="margin-bottom:6px;">' + escapeAttr(b.serviceType || 'Service') + ' · ' + (b.status || '') + ' · ' + (b.requestTime ? new Date(b.requestTime).toLocaleDateString() : '') + '</div>').join('') + (bookings.length > 10 ? '<p class="muted">+' + (bookings.length - 10) + ' more</p>' : '') + '</div>') +
            vehiclesHtml;
    } catch (e) {
        panel.innerHTML = '<p class="muted">Error loading details.</p>';
    }
}

async function checkUserSupportPhotoPermission(email) {
    const bar = document.getElementById('user-support-photo-approve');
    try {
        const permRes = await fetch(getApiUrl(USER_SUPPORT_API + '/photo-permission') + '?email=' + encodeURIComponent(email));
        if (!permRes.ok) { bar.style.display = 'none'; return; }
        const perm = await permRes.json();
        if (perm.allowed) { bar.style.display = 'none'; return; }
        const msgRes = await fetch(getApiUrl(USER_SUPPORT_API + '/messages') + '?email=' + encodeURIComponent(email));
        const msgs = await msgRes.json();
        const hasRequest = (msgs || []).some(m => (m.messageType || '').indexOf('PHOTO_PERMISSION_REQUEST') >= 0);
        bar.style.display = hasRequest ? 'flex' : 'none';
    } catch (e) { bar.style.display = 'none'; }
}

function userSupportTypingDebounce() {
    clearTimeout(userSupportTypingTimeout);
    const email = document.getElementById('user-support-reply-email').value;
    if (!email) return;
    fetch(getApiUrl(USER_SUPPORT_API + '/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email, isTyping: true }) }).catch(() => {});
    userSupportTypingTimeout = setTimeout(function() {
        fetch(getApiUrl(USER_SUPPORT_API + '/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email, isTyping: false }) }).catch(() => {});
    }, 2000);
}

async function approveUserPhotoPermission() {
    const email = document.getElementById('user-support-reply-email').value;
    if (!email) return;
    try {
        const res = await fetch(getApiUrl(USER_SUPPORT_API + '/approve-photo-permission'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email }) });
        if (res.ok) { showSuccess('Photo permission granted.'); document.getElementById('user-support-photo-approve').style.display = 'none'; loadUserSupportMessagesOnly(email); }
    } catch (e) { showError('Failed.'); }
}

async function sendUserSupportReply() {
    const email = document.getElementById('user-support-reply-email').value;
    const message = (document.getElementById('user-support-reply-message').value || '').trim();
    if (!email || !message) { showError('Enter a message.'); return; }
    try {
        const res = await fetch(getApiUrl(USER_SUPPORT_API + '/reply'), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userEmail: email, message: message })
        });
        if (!res.ok) { showError('Failed to send.'); return; }
        document.getElementById('user-support-reply-message').value = '';
        fetch(getApiUrl(USER_SUPPORT_API + '/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ userEmail: email, isTyping: false }) }).catch(() => {});
        loadUserSupportMessagesOnly(email);
    } catch (e) {
        showError('Error sending reply.');
    }
}

// ========== USER MANAGEMENT ==========

async function loadUsers() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.users));
        const users = await response.json();
        displayUsers(users);
    } catch (error) {
        console.error('Error loading users:', error);
        showError('Failed to load users');
    }
}

function displayUsers(users) {
    const tbody = document.getElementById('users-table-body');
    if (users.length === 0) {
        tbody.innerHTML = '<tr><td colspan="9" class="loading">No users found</td></tr>';
        return;
    }
    
    tbody.innerHTML = users.map(user => `
        <tr>
            <td>
                ${user.profilePhotoUrl 
                    ? `<span class="photo-thumb-clickable" data-url="${escapeAttr(user.profilePhotoUrl)}" data-name="${escapeAttr(user.name || 'User')}" title="Click to enlarge">
                     <img src="${user.profilePhotoUrl}" alt="" class="user-photo-thumb" onerror="this.style.display='none';this.nextElementSibling.style.display='flex';">
                     <span class="user-photo-placeholder" style="display:none;"><i class="fas fa-user"></i></span></span>`
                    : `<span class="user-photo-placeholder"><i class="fas fa-user"></i></span>`}
            </td>
            <td>${user.id}</td>
            <td><strong>${user.name || 'N/A'}</strong></td>
            <td>${user.email || 'N/A'}</td>
            <td>${user.phone || 'N/A'}</td>
            <td>${user.dateOfBirth || 'N/A'}</td>
            <td>${user.gender || 'N/A'}</td>
            <td>
                <button class="btn-action btn-view" data-email="${escapeAttr(user.email || '')}" onclick="viewUserVehicles(this.getAttribute('data-email'))" title="View vehicle details"><i class="fas fa-car"></i> View vehicles</button>
            </td>
            <td>
                <button class="btn-action btn-view" onclick="viewUserBookings('${user.email}')">View Bookings</button>
            </td>
        </tr>
    `).join('');
}

async function searchUsers() {
    const query = document.getElementById('user-search').value;
    if (query.length < 2) {
        loadUsers();
        return;
    }
    
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.users)}/search?query=${encodeURIComponent(query)}`);
        const users = await response.json();
        displayUsers(users);
    } catch (error) {
        console.error('Error searching users:', error);
        showError('Failed to search users');
    }
}

function buildUserVehiclesDetailHtml(vehicles) {
    if (!vehicles || vehicles.length === 0) return '<p class="muted">No vehicles added.</p>';
    return '<div class="user-vehicles-detail-list">' + vehicles.map((v, idx) => {
        const type = (v.type || 'CAR') === 'BIKE' ? 'Bike' : 'Car';
        const make = v.makeName || '—';
        const model = v.modelName || '—';
        const plate = v.plateNumber || '—';
        const year = v.year || '—';
        const fuel = v.fuelType || '—';
        const def = v.isDefault ? ' <span class="support-thread-badge" style="font-size:10px;">Default</span>' : '';
        const header = ((make + ' ' + model).trim() || 'Vehicle').replace(/^—\s*—$/, 'Vehicle');
        return '<div class="user-vehicle-detail-card">' +
            '<div class="user-vehicle-detail-header">#' + (idx + 1) + ' ' + escapeAttr(header) + def + '</div>' +
            '<table class="user-vehicle-detail-table"><tbody>' +
            '<tr><td>Type</td><td>' + escapeAttr(type) + '</td></tr>' +
            '<tr><td>Make</td><td>' + escapeAttr(make) + '</td></tr>' +
            '<tr><td>Model</td><td>' + escapeAttr(model) + '</td></tr>' +
            '<tr><td>Plate number</td><td>' + escapeAttr(plate) + '</td></tr>' +
            '<tr><td>Year</td><td>' + escapeAttr(year) + '</td></tr>' +
            '<tr><td>Fuel type</td><td>' + escapeAttr(fuel) + '</td></tr>' +
            '</tbody></table></div>';
    }).join('') + '</div>';
}

async function viewUserVehicles(email) {
    if (!email || !email.trim()) { showError('No user email'); return; }
    const modalContent = document.getElementById('mechanic-performance-content');
    if (!modalContent) return;
    modalContent.innerHTML = '<p class="loading">Loading vehicles...</p>';
    document.getElementById('mechanic-modal').style.display = 'block';
    try {
        const res = await fetch(getApiUrl('/api/vehicle/my') + '?email=' + encodeURIComponent(email.trim()));
        const vehicles = res.ok ? await res.json() : [];
        modalContent.innerHTML = '<h3 style="margin-top:0;"><i class="fas fa-car"></i> Vehicles for ' + escapeAttr(email) + '</h3>' +
            '<div style="max-height: 70vh; overflow-y: auto;">' + buildUserVehiclesDetailHtml(vehicles) + '</div>';
    } catch (e) {
        console.error('Error loading user vehicles:', e);
        modalContent.innerHTML = '<p class="muted">Failed to load vehicles.</p>';
        showError('Failed to load vehicles');
    }
}

async function viewUserBookings(email) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.users)}/${encodeURIComponent(email)}/bookings`);
        const bookings = await response.json();
        
        const content = document.getElementById('mechanic-performance-content');
        content.innerHTML = `
            <h3>Bookings for ${escapeAttr(email)}</h3>
            <div style="max-height: 400px; overflow-y: auto;">
                ${bookings.length === 0 ? '<p>No bookings found</p>' : `
                    <table class="data-table" style="margin-top: 16px;">
                        <thead>
                            <tr>
                                <th>ID</th>
                                <th>Service Type</th>
                                <th>Status</th>
                                <th>Amount</th>
                                <th>Request Time</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${bookings.map(booking => `
                                <tr>
                                    <td>${booking.id}</td>
                                    <td>${booking.serviceType || 'N/A'}</td>
                                    <td><span class="status-badge ${(booking.status || 'PENDING').toLowerCase()}">${booking.status || 'PENDING'}</span></td>
                                    <td>₹${(booking.amount || 0).toLocaleString('en-IN')}</td>
                                    <td>${booking.requestTime ? new Date(booking.requestTime).toLocaleString() : 'N/A'}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                `}
            </div>
        `;
        
        document.getElementById('mechanic-modal').style.display = 'block';
    } catch (error) {
        console.error('Error loading user bookings:', error);
        showError('Failed to load user bookings');
    }
}

// ========== MECHANIC MANAGEMENT ENHANCEMENTS ==========

async function viewMechanicProfile(id) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanicProfile)}/${id}/profile`);
        const profile = await response.json();
        
        const mechanic = profile.mechanic || profile;
        let documents = [];
        try {
            documents = mechanic.documentUrls ? (typeof mechanic.documentUrls === 'string' ? JSON.parse(mechanic.documentUrls) : mechanic.documentUrls) : [];
        } catch (e) { documents = []; }
        
        const lat = parseFloat(mechanic.latitude);
        const lng = parseFloat(mechanic.longitude);
        const hasLocation = !isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0;
        
        const content = document.getElementById('mechanic-profile-details');
        const photoHtml = mechanic.profilePhotoUrl 
            ? `<img src="${mechanic.profilePhotoUrl}" alt="" class="mechanic-profile-photo" onerror="this.style.display='none'">` 
            : '<span class="user-photo-placeholder" style="width:80px;height:80px;"><i class="fas fa-user-cog"></i></span>';
        content.innerHTML = `
            <div class="profile-details-grid">
                <div class="profile-detail-item full-width" style="margin-bottom:16px;display:flex;align-items:center;">
                    <div class="mechanic-profile-photo-wrap">${photoHtml}</div>
                    <div><strong>Profile Photo</strong><br>${mechanic.name || 'N/A'}</div>
                </div>
                <div class="profile-detail-item"><i class="fas fa-user"></i><div><strong>Name</strong><br>${mechanic.name || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-envelope"></i><div><strong>Email</strong><br>${mechanic.email || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-phone"></i><div><strong>Phone</strong><br>${mechanic.phone || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-id-card"></i><div><strong>Aadhar Number</strong><br>${mechanic.aadharNumber || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-store"></i><div><strong>Shop Name</strong><br>${mechanic.shopName || mechanic.shop_name || 'N/A'}</div></div>
                <div class="profile-detail-item full-width"><i class="fas fa-map-marker-alt"></i><div><strong>Shop Address</strong><br>${mechanic.shopAddress || mechanic.shop_address || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-city"></i><div><strong>City</strong><br>${mechanic.shopCity || mechanic.shop_city || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-map"></i><div><strong>State</strong><br>${mechanic.shopState || mechanic.shop_state || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-mail-bulk"></i><div><strong>Pincode</strong><br>${mechanic.shopPincode || mechanic.shop_pincode || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-globe"></i><div><strong>Country</strong><br>${mechanic.shopCountry || mechanic.shop_country || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-wrench"></i><div><strong>Specialty</strong><br>${mechanic.specialty || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-clock"></i><div><strong>Experience</strong><br>${mechanic.experience || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-calendar-alt"></i><div><strong>Working Days</strong><br>${(mechanic.workingDays || mechanic.working_days || 'N/A').toString().replace(/,/g, ', ')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-business-time"></i><div><strong>Hours</strong><br>${(mechanic.openingTime || '')} - ${(mechanic.closingTime || '') || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-moon"></i><div><strong>24/7 Night</strong><br>${mechanic.nightTimeAvailable ? 'Yes' : 'No'}</div></div>
                <div class="profile-detail-item full-width"><i class="fas fa-tasks"></i><div><strong>Services</strong><br>${(mechanic.services || 'N/A').toString().replace(/,/g, ', ')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-tag"></i><div><strong>Status</strong><br><span class="status-badge ${(mechanic.status || 'Available').toLowerCase()}">${mechanic.status || 'Available'}</span></div></div>
                <div class="profile-detail-item"><i class="fas fa-signal"></i><div><strong>Online</strong><br>${mechanic.isOnline ? '<span class="status-badge approved">Online</span>' : '<span class="status-badge pending">Offline</span>'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-clipboard-list"></i><div><strong>Requests</strong><br>${profile.totalRequests || 0} (${profile.completedRequests || 0} completed)</div></div>
                ${documents.length > 0 ? `<div class="profile-detail-item full-width"><i class="fas fa-file-alt"></i><div><strong>Documents</strong><br>${documents.map((d,i) => `<a href="${d}" target="_blank" class="doc-link">Doc ${i+1}</a>`).join(' ')}</div></div>` : ''}
                <div class="profile-detail-item full-width">
                    <button class="btn-action btn-view" onclick="uploadDocuments(${id})">
                        <i class="fas fa-upload"></i> Upload Documents
                    </button>
                </div>
            </div>
        `;
        
        document.getElementById('mechanic-profile-modal').style.display = 'block';
        
        const mapPanel = document.querySelector('.profile-map-panel');
        if (hasLocation) {
            mapPanel.querySelector('#profile-map')?.classList.remove('hidden');
            mapPanel.querySelector('.profile-map-fallback')?.remove();
            setTimeout(() => initProfileMap(lat, lng, mechanic.shopName || mechanic.name || 'Shop'), 100);
        } else {
            const mapEl = document.getElementById('profile-map');
            mapEl?.classList.add('hidden');
            const addr = mechanic.shopAddress || mechanic.shop_address || '';
            const fallback = document.createElement('div');
            fallback.className = 'profile-map-fallback';
            fallback.innerHTML = `
                <p>📍 Location not set</p>
                ${addr ? `<p>${addr}</p><a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(addr)}" target="_blank" class="btn-action btn-view"><i class="fas fa-external-link-alt"></i> Search on Google Maps</a>` : ''}
            `;
            mapPanel?.insertBefore(fallback, mapPanel.querySelector('#profile-map'));
        }
    } catch (error) {
        console.error('Error loading mechanic profile:', error);
        showError('Failed to load mechanic profile');
    }
}

function initProfileMap(lat, lng, title) {
    const mapEl = document.getElementById('profile-map');
    if (!mapEl) return;
    
    if (typeof google === 'undefined' || !google.maps) {
        mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Google Maps loading...</p>';
        return;
    }
    
    mapEl.innerHTML = '';
    mapEl.style.minHeight = '350px';
    
    leafletProfileMap = new google.maps.Map(mapEl, {
        center: { lat: lat, lng: lng },
        zoom: 16,
        mapTypeId: 'roadmap',
        mapTypeControl: false
    });
    
    const marker = new google.maps.Marker({
        position: { lat: lat, lng: lng },
        map: leafletProfileMap,
        title: title || 'Shop'
    });
    
    const infoWindow = new google.maps.InfoWindow({
        content: `<strong>${escapeAttr(title || 'Shop')}</strong><br>📍 ${lat.toFixed(5)}, ${lng.toFixed(5)}`
    });
    marker.addListener('click', () => infoWindow.open(leafletProfileMap, marker));
    infoWindow.open(leafletProfileMap, marker);
    
    setTimeout(() => { if (leafletProfileMap) google.maps.event.trigger(leafletProfileMap, 'resize'); }, 200);
}

function closeProfileModal() {
    document.getElementById('mechanic-profile-modal').style.display = 'none';
    leafletProfileMap = null;
    document.querySelector('.profile-map-fallback')?.remove();
    const mapEl = document.getElementById('profile-map');
    if (mapEl) { mapEl.classList.remove('hidden'); mapEl.innerHTML = ''; }
}

async function viewRegistrationRequestDetail(id) {
    try {
        let r = null;
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.registrationRequests) + '/' + id);
        if (response.ok) {
            r = await response.json();
        } else {
            const fromList = (registrationRequestsList || []).find(req => req.id == id);
            if (fromList) r = fromList;
        }
        if (!r) { showError('Failed to load request'); return; }
        const photoHtml = r.profilePhotoUrl
            ? `<img src="${escapeAttr(r.profilePhotoUrl)}" alt="" class="mechanic-profile-photo" onerror="this.style.display='none'">`
            : '<span class="user-photo-placeholder" style="width:80px;height:80px;"><i class="fas fa-user-cog"></i></span>';
        const details = document.getElementById('registration-request-details');
        details.innerHTML = `
            <div class="profile-details-grid">
                <div class="profile-detail-item full-width" style="margin-bottom:16px;display:flex;align-items:center;">
                    <div class="mechanic-profile-photo-wrap">${photoHtml}</div>
                    <div><strong>Profile Photo</strong><br>${escapeAttr(r.name || 'N/A')}</div>
                </div>
                <div class="profile-detail-item"><i class="fas fa-user"></i><div><strong>Name</strong><br>${escapeAttr(r.name || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-envelope"></i><div><strong>Email</strong><br>${escapeAttr(r.email || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-phone"></i><div><strong>Phone</strong><br>${escapeAttr(r.phone || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-id-card"></i><div><strong>Aadhar Number</strong><br>${escapeAttr(r.aadharNumber || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-clock"></i><div><strong>Experience</strong><br>${escapeAttr(r.experience || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-store"></i><div><strong>Shop Name</strong><br>${escapeAttr(r.shopName || 'N/A')}</div></div>
                <div class="profile-detail-item full-width"><i class="fas fa-map-marker-alt"></i><div><strong>Shop Address</strong><br>${escapeAttr(r.shopAddress || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-city"></i><div><strong>City</strong><br>${escapeAttr(r.shopCity || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-map"></i><div><strong>State</strong><br>${escapeAttr(r.shopState || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-mail-bulk"></i><div><strong>Pincode</strong><br>${escapeAttr(r.shopPincode || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-globe"></i><div><strong>Country</strong><br>${escapeAttr(r.shopCountry || 'N/A')}</div></div>
                <div class="profile-detail-item"><i class="fas fa-wrench"></i><div><strong>Specialty</strong><br>${escapeAttr(r.specialty || 'N/A')}</div></div>
                <div class="profile-detail-item full-width"><i class="fas fa-tasks"></i><div><strong>Services</strong><br>${escapeAttr((r.services || 'N/A').toString().replace(/,/g, ', '))}</div></div>
                <div class="profile-detail-item"><i class="fas fa-calendar-alt"></i><div><strong>Working Days</strong><br>${escapeAttr((r.workingDays || 'N/A').toString().replace(/,/g, ', '))}</div></div>
                <div class="profile-detail-item"><i class="fas fa-business-time"></i><div><strong>Hours</strong><br>${escapeAttr(r.openingTime || '')} - ${escapeAttr(r.closingTime || '') || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-moon"></i><div><strong>24/7 Night</strong><br>${r.nightTimeAvailable ? 'Yes' : 'No'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-tag"></i><div><strong>Status</strong><br><span class="status-badge ${(r.approvalStatus || 'PENDING').toLowerCase()}">${escapeAttr((r.approvalStatus || 'PENDING'))}</span></div></div>
                <div class="profile-detail-item"><i class="fas fa-clock"></i><div><strong>Submitted</strong><br>${r.createdAt ? new Date(r.createdAt).toLocaleString() : 'N/A'}</div></div>
            </div>
        `;
        document.getElementById('registration-request-modal').style.display = 'block';
        const lat = parseFloat(r.latitude);
        const lng = parseFloat(r.longitude);
        const mapEl = document.getElementById('registration-request-map');
        const fallbackEl = document.getElementById('registration-request-map-fallback');
        if (fallbackEl) fallbackEl.style.display = 'none';
        if (mapEl) mapEl.style.display = 'block';
        if (!isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0) {
            setTimeout(() => {
                try {
                    initRegistrationRequestMap(lat, lng, r.shopName || r.name || 'Shop');
                } catch (mapErr) {
                    console.error('Map init error:', mapErr);
                    if (mapEl) mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Map could not load. Details are above.</p>';
                }
            }, 100);
        } else {
            if (mapEl) mapEl.innerHTML = '';
            if (fallbackEl) {
                fallbackEl.style.display = 'block';
                fallbackEl.innerHTML = '<p>📍 Shop location (lat/lng) not provided.</p>' + (r.shopAddress ? `<p>Address: ${escapeAttr(r.shopAddress)}</p><a href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(r.shopAddress)}" target="_blank" class="btn-action btn-view"><i class="fas fa-external-link-alt"></i> Search on Google Maps</a>` : '');
            }
        }
    } catch (error) {
        console.error('Error loading registration request:', error);
        showError('Failed to load request details. Check console.');
    }
}

function initRegistrationRequestMap(lat, lng, title) {
    const mapEl = document.getElementById('registration-request-map');
    if (!mapEl) return;
    try {
        if (typeof google === 'undefined' || !google.maps) {
            mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Google Maps loading...</p>';
            return;
        }
        mapEl.innerHTML = '';
        mapEl.style.minHeight = '320px';
        leafletRequestMap = new google.maps.Map(mapEl, {
            center: { lat: lat, lng: lng },
            zoom: 16,
            mapTypeId: 'roadmap',
            mapTypeControl: false
        });
        const marker = new google.maps.Marker({
            position: { lat: lat, lng: lng },
            map: leafletRequestMap,
            title: title || 'Shop'
        });
        const infoWindow = new google.maps.InfoWindow({
            content: `<strong>${escapeAttr(title || 'Shop')}</strong><br>📍 ${lat.toFixed(5)}, ${lng.toFixed(5)}`
        });
        marker.addListener('click', () => infoWindow.open(leafletRequestMap, marker));
        infoWindow.open(leafletRequestMap, marker);
        setTimeout(() => { if (leafletRequestMap) google.maps.event.trigger(leafletRequestMap, 'resize'); }, 200);
    } catch (e) {
        mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Map unavailable. Details shown above.</p>';
    }
}

function closeRegistrationRequestModal() {
    document.getElementById('registration-request-modal').style.display = 'none';
    leafletRequestMap = null;
    const mapEl = document.getElementById('registration-request-map');
    if (mapEl) { mapEl.innerHTML = ''; mapEl.style.display = 'block'; }
    const fallbackEl = document.getElementById('registration-request-map-fallback');
    if (fallbackEl) { fallbackEl.style.display = 'none'; fallbackEl.innerHTML = ''; }
}

async function blockMechanic(id) {
    if (!confirm('Are you sure you want to block this mechanic?')) return;
    
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanics)}/${id}/block`, { method: 'PUT' });
        if (response.ok) {
            showSuccess('Mechanic blocked');
            refreshData();
        } else {
            showError('Failed to block mechanic');
        }
    } catch (error) {
        console.error('Error blocking mechanic:', error);
        showError('Failed to block mechanic');
    }
}

async function unblockMechanic(id) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanics)}/${id}/unblock`, { method: 'PUT' });
        if (response.ok) {
            showSuccess('Mechanic unblocked');
            refreshData();
        } else {
            showError('Failed to unblock mechanic');
        }
    } catch (error) {
        console.error('Error unblocking mechanic:', error);
        showError('Failed to unblock mechanic');
    }
}

async function suspendMechanic(id) {
    if (!confirm('Are you sure you want to suspend this mechanic?')) return;
    
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanics)}/${id}/suspend`, { method: 'PUT' });
        if (response.ok) {
            showSuccess('Mechanic suspended');
            refreshData();
        } else {
            showError('Failed to suspend mechanic');
        }
    } catch (error) {
        console.error('Error suspending mechanic:', error);
        showError('Failed to suspend mechanic');
    }
}

async function unsuspendMechanic(id) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanics)}/${id}/unsuspend`, { method: 'PUT' });
        if (response.ok) {
            showSuccess('Mechanic unsuspended');
            refreshData();
        } else {
            showError('Failed to unsuspend mechanic');
        }
    } catch (error) {
        console.error('Error unsuspending mechanic:', error);
        showError('Failed to unsuspend mechanic');
    }
}

function uploadDocuments(id) {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.pdf,.jpg,.jpeg,.png,.webp';
    input.multiple = true;
    input.onchange = async () => {
        const files = Array.from(input.files);
        if (!files.length) return;
        for (const file of files) {
            try {
                const fd = new FormData();
                fd.append('file', file);
                const resp = await fetch(`${API_CONFIG.baseUrl}/api/upload/mechanic/${id}/document`, {
                    method: 'POST',
                    body: fd
                });
                const data = await resp.json();
                if (resp.ok) {
                    showSuccess(`Uploaded: ${file.name}`);
                } else {
                    showError(data.error || `Failed: ${file.name}`);
                }
            } catch (e) {
                showError(`Upload failed: ${e.message}`);
            }
        }
        viewMechanicProfile(id);
    };
    input.click();
}

async function updateMechanicDocuments(id, documentUrls) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.mechanics)}/${id}/documents`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ documentUrls })
        });
        
        if (response.ok) {
            showSuccess('Documents updated');
            viewMechanicProfile(id);
        } else {
            showError('Failed to update documents');
        }
    } catch (error) {
        console.error('Error updating documents:', error);
        showError('Failed to update documents');
    }
}

// ========== VEHICLE CATALOG (add car/bike selection images) ==========
let vehicleCatalogSelectedMakeId = null;

async function loadVehicleCatalog() {
    const type = document.getElementById('vehicle-catalog-type')?.value || 'CAR';
    const el = document.getElementById('vehicle-catalog-makes');
    const modelsWrap = document.getElementById('vehicle-catalog-models-wrap');
    const modelsEl = document.getElementById('vehicle-catalog-models');
    const modelsTitle = document.getElementById('vehicle-catalog-models-title');
    if (!el) return;
    el.innerHTML = 'Loading...';
    modelsWrap.style.display = 'none';
    try {
        const url = getApiUrl('/api/vehicle/makes') + '?type=' + encodeURIComponent(type);
        const res = await fetch(url);
        if (!res.ok) {
            const msg = res.status === 404
                ? 'Vehicle catalog API not found (HTTP 404). Deploy the latest backend: run <code>./update-backend-ec2.sh</code> from project root, then try again.'
                : 'Failed to load (HTTP ' + res.status + '). Ensure backend is running at ' + (typeof API_CONFIG !== 'undefined' ? API_CONFIG.baseUrl : '') + '.';
            el.innerHTML = '<p class="muted">' + msg + '</p>';
            return;
        }
        const makes = await res.json();
        const base = (typeof API_CONFIG !== 'undefined' && API_CONFIG.baseUrl) ? API_CONFIG.baseUrl.replace(/\/$/, '') : '';
        el.innerHTML = '<div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap:12px;">' + (makes || []).map(m => {
            const imgSrc = (m.imageUrl && m.imageUrl.indexOf('http') === 0) ? m.imageUrl : (m.imageUrl && base ? base + (m.imageUrl.indexOf('/') === 0 ? m.imageUrl : '/' + m.imageUrl) : '');
            return '<div class="vehicle-catalog-item" data-id="' + m.id + '" data-name="' + escapeAttr(m.name || '') + '">' +
                '<div class="vehicle-catalog-thumb" style="background-image:url(\'' + (imgSrc || '') + '\');' + (!imgSrc ? ' background-color:#eee;' : '') + '">' + (!imgSrc ? '<i class="fas fa-car" style="font-size:28px;color:#999;"></i>' : '') + '</div>' +
                '<div style="font-weight:600;margin-top:6px;">' + escapeAttr(m.name || '') + '</div>' +
                '<div style="margin-top:6px;font-size:12px;">' +
                '<label><input type="file" accept="image/*" style="width:100%;" onchange="uploadVehicleCatalogPhoto(\'make\',' + m.id + ',this)"> Upload</label>' +
                '</div>' +
                '<div style="margin-top:4px;"><input type="text" placeholder="Or paste image URL" style="width:100%;font-size:11px;padding:4px;" id="make-url-' + m.id + '"><button type="button" class="btn-action btn-view" style="margin-top:4px;font-size:11px;" onclick="setVehicleCatalogImageUrl(\'make\',' + m.id + ')">Set URL</button></div>' +
                '<button type="button" class="btn-action btn-reject" style="margin-top:6px;font-size:11px;width:100%;" onclick="event.stopPropagation();deleteMake(' + m.id + ')"><i class="fas fa-trash"></i> Delete</button>' +
                '</div>';
        }).join('') + '</div>';
        el.querySelectorAll('.vehicle-catalog-item').forEach(div => {
            div.onclick = function(e) {
                if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON' || e.target.tagName === 'LABEL') return;
                vehicleCatalogSelectedMakeId = parseInt(div.dataset.id, 10);
                loadVehicleCatalogModels(vehicleCatalogSelectedMakeId, div.dataset.name);
            };
        });
        if (vehicleCatalogSelectedMakeId != null) loadVehicleCatalogModels(vehicleCatalogSelectedMakeId);
    } catch (e) {
        el.innerHTML = '<p class="muted">Failed to load. Check backend.</p>';
    }
}

async function loadVehicleCatalogModels(makeId, makeName) {
    const wrap = document.getElementById('vehicle-catalog-models-wrap');
    const el = document.getElementById('vehicle-catalog-models');
    const title = document.getElementById('vehicle-catalog-models-title');
    if (!wrap || !el) return;
    wrap.style.display = 'block';
    title.textContent = makeName ? ('Models: ' + makeName) : 'Models';
    el.innerHTML = 'Loading models...';
    try {
        const res = await fetch(getApiUrl('/api/vehicle/models') + '?makeId=' + makeId);
        const models = await res.json();
        const base = (typeof API_CONFIG !== 'undefined' && API_CONFIG.baseUrl) ? API_CONFIG.baseUrl.replace(/\/$/, '') : '';
        el.innerHTML = '<div style="display:grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap:10px;">' + (models || []).map(m => {
            const imgSrc = (m.imageUrl && m.imageUrl.indexOf('http') === 0) ? m.imageUrl : (m.imageUrl && base ? base + (m.imageUrl.indexOf('/') === 0 ? m.imageUrl : '/' + m.imageUrl) : '');
            return '<div class="vehicle-catalog-item">' +
                '<div class="vehicle-catalog-thumb" style="background-image:url(\'' + (imgSrc || '') + '\');' + (!imgSrc ? ' background-color:#eee;' : '') + '">' + (!imgSrc ? '<i class="fas fa-image" style="font-size:24px;color:#999;"></i>' : '') + '</div>' +
                '<div style="font-weight:600;margin-top:4px;font-size:13px;">' + escapeAttr(m.name || '') + '</div>' +
                '<label style="font-size:11px;"><input type="file" accept="image/*" style="width:100%;" onchange="uploadVehicleCatalogPhoto(\'model\',' + m.id + ',this)"> Upload</label>' +
                '<input type="text" placeholder="Or image URL" style="width:100%;font-size:11px;padding:4px;margin-top:2px;" id="model-url-' + m.id + '"><button type="button" class="btn-action btn-view" style="margin-top:2px;font-size:11px;" onclick="setVehicleCatalogImageUrl(\'model\',' + m.id + ')">Set URL</button>' +
                '<button type="button" class="btn-action btn-reject" style="margin-top:4px;font-size:11px;width:100%;" onclick="deleteModel(' + m.id + ')"><i class="fas fa-trash"></i> Delete</button>' +
                '</div>';
        }).join('') + '</div>';
    } catch (e) {
        el.innerHTML = '<p class="muted">Failed to load models.</p>';
    }
}

function uploadVehicleCatalogPhoto(type, id, fileInput) {
    const file = fileInput && fileInput.files && fileInput.files[0];
    if (!file) return;
    const fd = new FormData();
    fd.append('file', file);
    fd.append('type', type);
    fd.append('id', id);
    fetch(API_CONFIG.baseUrl + '/api/upload/vehicle-catalog-photo', { method: 'POST', body: fd })
        .then(r => r.json())
        .then(data => {
            if (data.error) { showError(data.error); return; }
            showSuccess('Image uploaded.');
            fileInput.value = '';
            loadVehicleCatalog();
            if (vehicleCatalogSelectedMakeId != null) loadVehicleCatalogModels(vehicleCatalogSelectedMakeId);
        })
        .catch(() => showError('Upload failed'));
}

async function setVehicleCatalogImageUrl(type, id) {
    const input = document.getElementById(type + '-url-' + id);
    const url = (input && input.value || '').trim();
    if (!url) { showError('Enter an image URL'); return; }
    const path = type === 'make' ? ('/api/vehicle/makes/' + id + '/image') : ('/api/vehicle/models/' + id + '/image');
    try {
        const res = await fetch(getApiUrl(path), { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ imageUrl: url }) });
        if (res.ok) { showSuccess('Image URL set.'); input.value = ''; loadVehicleCatalog(); if (vehicleCatalogSelectedMakeId != null) loadVehicleCatalogModels(vehicleCatalogSelectedMakeId); }
        else showError('Failed to set URL');
    } catch (e) { showError('Failed'); }
}

async function deleteMake(id) {
    const card = document.querySelector('.vehicle-catalog-item[data-id="' + id + '"]');
    const name = (card && card.dataset.name) ? card.dataset.name : 'this brand';
    if (!confirm('Delete brand "' + name + '" and all its models? This cannot be undone.')) return;
    try {
        const res = await fetch(getApiUrl('/api/vehicle/makes/' + id), { method: 'DELETE' });
        if (res.ok) { showSuccess('Brand deleted.'); vehicleCatalogSelectedMakeId = null; loadVehicleCatalog(); document.getElementById('vehicle-catalog-models-wrap').style.display = 'none'; }
        else showError('Failed to delete');
    } catch (e) { showError('Failed'); }
}

async function deleteModel(id) {
    if (!confirm('Delete this model? This cannot be undone.')) return;
    try {
        const res = await fetch(getApiUrl('/api/vehicle/models/' + id), { method: 'DELETE' });
        if (res.ok) { showSuccess('Model deleted.'); if (vehicleCatalogSelectedMakeId != null) loadVehicleCatalogModels(vehicleCatalogSelectedMakeId); }
        else showError('Failed to delete');
    } catch (e) { showError('Failed'); }
}

function showAddMakeModal() {
    document.getElementById('add-make-name').value = '';
    document.getElementById('add-make-type').value = document.getElementById('vehicle-catalog-type').value || 'CAR';
    document.getElementById('add-make-file').value = '';
    document.getElementById('add-make-imageUrl').value = '';
    document.getElementById('vehicle-add-make-modal').style.display = 'block';
}

function closeAddMakeModal() {
    document.getElementById('vehicle-add-make-modal').style.display = 'none';
}

async function submitAddMake() {
    const name = (document.getElementById('add-make-name').value || '').trim();
    const type = document.getElementById('add-make-type').value || 'CAR';
    const fileInput = document.getElementById('add-make-file');
    const imageUrl = (document.getElementById('add-make-imageUrl').value || '').trim();
    if (!name) { showError('Enter brand name'); return; }
    try {
        const body = { name: name, type: type };
        if (imageUrl) body.imageUrl = imageUrl;
        const res = await fetch(getApiUrl('/api/vehicle/makes'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        if (!res.ok) { showError('Failed to add brand'); return; }
        const created = await res.json();
        const newId = created.id;
        if (fileInput.files && fileInput.files[0]) {
            const fd = new FormData();
            fd.append('file', fileInput.files[0]);
            fd.append('type', 'make');
            fd.append('id', newId);
            const up = await fetch(API_CONFIG.baseUrl + '/api/upload/vehicle-catalog-photo', { method: 'POST', body: fd });
            if (!up.ok) { var d = await up.json(); showError(d.error || 'Upload failed'); }
        }
        closeAddMakeModal();
        showSuccess('Brand added.');
        loadVehicleCatalog();
    } catch (e) { showError('Failed'); }
}

function showAddModelModal() {
    if (vehicleCatalogSelectedMakeId == null) { showError('Select a brand first'); return; }
    document.getElementById('add-model-name').value = '';
    document.getElementById('add-model-file').value = '';
    document.getElementById('add-model-imageUrl').value = '';
    document.getElementById('vehicle-add-model-modal').style.display = 'block';
}

function closeAddModelModal() {
    document.getElementById('vehicle-add-model-modal').style.display = 'none';
}

async function submitAddModel() {
    const name = (document.getElementById('add-model-name').value || '').trim();
    const fileInput = document.getElementById('add-model-file');
    const imageUrl = (document.getElementById('add-model-imageUrl').value || '').trim();
    if (!name) { showError('Enter model name'); return; }
    if (vehicleCatalogSelectedMakeId == null) { showError('Select a brand first'); return; }
    try {
        const body = { makeId: vehicleCatalogSelectedMakeId, name: name };
        if (imageUrl) body.imageUrl = imageUrl;
        const res = await fetch(getApiUrl('/api/vehicle/models'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        if (!res.ok) { showError('Failed to add model'); return; }
        const created = await res.json();
        const newId = created.id;
        if (fileInput.files && fileInput.files[0]) {
            const fd = new FormData();
            fd.append('file', fileInput.files[0]);
            fd.append('type', 'model');
            fd.append('id', newId);
            await fetch(API_CONFIG.baseUrl + '/api/upload/vehicle-catalog-photo', { method: 'POST', body: fd });
        }
        closeAddModelModal();
        showSuccess('Model added.');
        loadVehicleCatalogModels(vehicleCatalogSelectedMakeId);
    } catch (e) { showError('Failed'); }
}

// ========== CAROUSEL / BANNERS ==========
let editingBannerId = null;

async function loadBanners() {
    const grid = document.getElementById('banners-grid');
    if (!grid) return;
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.banners));
        const banners = await response.json();
        displayBanners(banners);
    } catch (error) {
        console.error('Error loading banners:', error);
        grid.innerHTML = '<div class="loading error">Failed to load banners</div>';
    }
}

function fullImageUrl(url) {
    if (!url) return '';
    if (url.indexOf('http') === 0) return url;
    return API_CONFIG.baseUrl + (url.startsWith('/') ? '' : '/') + url;
}

function displayBanners(banners) {
    const grid = document.getElementById('banners-grid');
    const preview = document.getElementById('carousel-preview');
    if (!grid) return;
    const list = Array.isArray(banners) ? banners.filter(b => b.active) : [];
    const all = Array.isArray(banners) ? banners : [];

    // Mobile app preview – shows how slider looks
    if (preview) {
        if (list.length === 0) {
            preview.innerHTML = '<div class="carousel-preview-empty">No banners yet. Add banners below – they will appear here and in your app.</div>';
        } else {
            preview.innerHTML = list.sort((a,b) => (a.sortOrder||0) - (b.sortOrder||0)).map((b, i) => `
                <div class="carousel-preview-card" style="background-image: url('${fullImageUrl(b.imageUrl)}')">
                    <div class="carousel-preview-overlay"></div>
                    <div class="carousel-preview-text">
                        <div class="carousel-preview-title">${b.title || 'Untitled'}</div>
                        <div class="carousel-preview-subtitle">${b.subtitle || ''}</div>
                    </div>
                    <span class="carousel-preview-badge">#${i + 1}</span>
                </div>
            `).join('');
        }
    }

    if (all.length === 0) {
        grid.innerHTML = '<div class="empty-state"><p>No banners yet. Click "Add Banner" above to upload carousel images. These will replace the default slider images in your app.</p></div>';
        return;
    }
    const sorted = [...all].sort((a,b) => (a.sortOrder||0) - (b.sortOrder||0));
    grid.innerHTML = sorted.map((b, idx) => `
        <div class="banner-card" data-id="${b.id}">
            <span class="banner-card-position">Slider #${idx + 1}</span>
            <span class="banner-card-badge">${(b.targetType || 'ALL') === 'ALL' ? 'All' : (b.targetType === 'CAR' ? 'Car' : 'Bike')}</span>
            <div class="banner-card-image" style="background-image: url('${fullImageUrl(b.imageUrl)}')"></div>
            <div class="banner-card-info">
                <strong>${b.title || 'Untitled'}</strong>
                <span>${b.subtitle || ''}</span>
                <span class="banner-order">Order: ${b.sortOrder}</span>
                <span class="status-badge ${b.active ? 'approved' : 'pending'}">${b.active ? 'Active' : 'Inactive'}</span>
            </div>
            <div class="banner-card-actions">
                <button class="btn-action btn-view" onclick="editBanner(${b.id})" title="Edit this banner"><i class="fas fa-edit"></i> Edit</button>
                <button class="btn-action btn-reject" onclick="deleteBanner(${b.id}, '${(b.title || '').replace(/'/g, "\\'")}')" title="Delete"><i class="fas fa-trash"></i></button>
            </div>
        </div>
    `).join('');
}

function showAddBannerModal() {
    editingBannerId = null;
    document.getElementById('banner-modal-title').textContent = 'Add Banner';
    document.getElementById('banner-image-input').value = '';
    document.getElementById('banner-image-preview').innerHTML = '';
    document.getElementById('banner-title').value = '';
    document.getElementById('banner-subtitle').value = '';
    document.getElementById('banner-target-type').value = 'ALL';
    document.getElementById('banner-order').value = '0';
    document.getElementById('banner-active').checked = true;
    document.getElementById('banner-modal').style.display = 'block';
}

function closeBannerModal() {
    document.getElementById('banner-modal').style.display = 'none';
    editingBannerId = null;
}

async function editBanner(id) {
    const banners = await fetch(getApiUrl(API_CONFIG.endpoints.banners)).then(r => r.json());
    const b = banners.find(x => x.id === id);
    if (!b) return;
    const sorted = [...banners].sort((a,z) => (a.sortOrder||0) - (z.sortOrder||0));
    const pos = sorted.findIndex(x => x.id === id) + 1;
    editingBannerId = id;
    document.getElementById('banner-modal-title').textContent = 'Edit Banner #' + (pos || '?') + ' – ' + (b.title || 'Untitled');
    document.getElementById('banner-image-input').value = '';
    document.getElementById('banner-image-preview').innerHTML = b.imageUrl
        ? `<img src="${b.imageUrl}" alt="Current" style="max-width: 100%; max-height: 150px; border-radius: 8px;">`
        : '';
    document.getElementById('banner-title').value = b.title || '';
    document.getElementById('banner-subtitle').value = b.subtitle || '';
    document.getElementById('banner-target-type').value = b.targetType || 'ALL';
    document.getElementById('banner-order').value = String(b.sortOrder || 0);
    document.getElementById('banner-active').checked = b.active !== false;
    document.getElementById('banner-modal').style.display = 'block';
}

async function saveBanner() {
    const title = document.getElementById('banner-title').value.trim();
    const subtitle = document.getElementById('banner-subtitle').value.trim();
    const targetType = document.getElementById('banner-target-type').value || 'ALL';
    const order = parseInt(document.getElementById('banner-order').value, 10) || 0;
    const active = document.getElementById('banner-active').checked;
    const fileInput = document.getElementById('banner-image-input');

    let imageUrl = null;
    if (fileInput.files && fileInput.files[0]) {
        const fd = new FormData();
        fd.append('file', fileInput.files[0]);
        let resp, data;
        try {
            resp = await fetch(API_CONFIG.baseUrl + '/api/upload/banner', { method: 'POST', body: fd });
            data = await resp.json().catch(() => ({}));
        } catch (e) {
            showError('Network error: ' + (e.message || 'Could not reach server'));
            return;
        }
        if (!resp.ok) {
            showError(data.error || ('Upload failed (HTTP ' + resp.status + ')'));
            return;
        }
        imageUrl = data.url;
    }

    if (editingBannerId) {
        const body = { title, subtitle, targetType, sortOrder: order, active };
        if (imageUrl) body.imageUrl = imageUrl;
        const resp = await fetch(`${getApiUrl(API_CONFIG.endpoints.banners)}/${editingBannerId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (resp.ok) {
            showSuccess('Banner updated');
            closeBannerModal();
            loadBanners();
        } else {
            const err = await resp.json().catch(() => ({}));
            showError(err.error || err.message || 'Update failed');
        }
    } else {
        if (!imageUrl) {
            showError('Please select an image');
            return;
        }
        const resp = await fetch(getApiUrl(API_CONFIG.endpoints.banners), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ imageUrl, title, subtitle, targetType, sortOrder: order, active })
        });
        if (resp.ok) {
            showSuccess('Banner added');
            closeBannerModal();
            loadBanners();
        } else {
            const err = await resp.json().catch(() => ({}));
            showError(err.error || err.message || 'Create failed');
        }
    }
}

async function deleteBanner(id, title) {
    if (!confirm(`Delete banner "${title || 'Untitled'}"?`)) return;
    try {
        const resp = await fetch(`${getApiUrl(API_CONFIG.endpoints.banners)}/${id}`, { method: 'DELETE' });
        if (resp.ok) {
            showSuccess('Banner deleted');
            loadBanners();
        } else showError('Delete failed');
    } catch (e) {
        showError('Delete failed');
    }
}

// ========== MARKETING POSTER ==========
async function loadMarketingPoster() {
    const el = document.getElementById('marketing-poster-content');
    if (!el) return;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.poster) + '/all');
        if (!r.ok) { el.innerHTML = '<p class="muted">Failed to load.</p>'; return; }
        const list = await r.json();
        const base = (typeof API_CONFIG !== 'undefined' && API_CONFIG.baseUrl) ? API_CONFIG.baseUrl.replace(/\/$/, '') : '';
        if (!list || list.length === 0) {
            el.innerHTML = '<p class="muted">No posters yet. Add image, set location (optional), and Save below.</p>';
            cancelPosterEdit();
            return;
        }
        el.innerHTML = '<p><strong>Posters by state/area</strong> – Disable or delete per poster. No poster in an area = users there go straight to homepage.</p><div style="display:flex;flex-wrap:wrap;gap:12px;margin-top:8px;">' + list.map(function(p) {
            const imgSrc = p.imageUrl ? (p.imageUrl.indexOf('http') === 0 ? p.imageUrl : base + (p.imageUrl.startsWith('/') ? '' : '/') + p.imageUrl) : '';
            var loc = [p.targetCity, p.targetState].filter(Boolean).join(', ');
            if (!loc && p.targetLat != null && p.targetLng != null && p.targetRadiusKm != null) loc = p.targetLat.toFixed(2) + ', ' + p.targetLng.toFixed(2) + ' (' + p.targetRadiusKm + ' km)';
            if (!loc) loc = 'All users';
            return '<div class="banner-card" style="max-width:180px;"><div class="banner-card-image" style="height:100px;background-size:cover;background-image:url(\'' + escapeAttr(imgSrc || '') + '\');"></div><div style="padding:8px;font-size:12px;">' + escapeAttr(loc) + ' · ' + (p.active ? 'Active' : '<span style="color:#94a3b8;">Disabled</span>') + '</div><div style="display:flex;gap:4px;"><button type="button" class="btn-action btn-view" style="font-size:11px;" onclick="editPoster(' + p.id + ')">Edit</button><button type="button" class="btn-action btn-reject" style="font-size:11px;" onclick="deletePoster(' + p.id + ')"><i class="fas fa-trash"></i> Delete</button></div></div>';
        }).join('') + '</div>';
        if (!window._editingPosterId) {
            document.getElementById('poster-image-url').value = '';
            document.getElementById('poster-link-url').value = '';
            document.getElementById('poster-target-city').value = '';
            document.getElementById('poster-target-state').value = '';
            var latEl = document.getElementById('poster-target-lat'); if (latEl) latEl.value = '';
            var lngEl = document.getElementById('poster-target-lng'); if (lngEl) lngEl.value = '';
            var radEl = document.getElementById('poster-target-radius'); if (radEl) radEl.value = '';
            document.getElementById('poster-active').checked = true;
            return;
        }
        const sel = list.find(function(p) { return p.id === window._editingPosterId; });
        if (sel) {
            document.getElementById('poster-image-url').value = sel.imageUrl || '';
            document.getElementById('poster-link-url').value = sel.linkUrl || '';
            document.getElementById('poster-target-city').value = sel.targetCity || '';
            document.getElementById('poster-target-state').value = sel.targetState || '';
            var latEl = document.getElementById('poster-target-lat'); if (latEl) latEl.value = sel.targetLat != null ? sel.targetLat : '';
            var lngEl = document.getElementById('poster-target-lng'); if (lngEl) lngEl.value = sel.targetLng != null ? sel.targetLng : '';
            var radEl = document.getElementById('poster-target-radius'); if (radEl) radEl.value = sel.targetRadiusKm != null ? sel.targetRadiusKm : '';
            document.getElementById('poster-active').checked = sel.active !== false;
        }
    } catch (e) {
        el.innerHTML = '<p class="muted">Failed to load.</p>';
        window._editingPosterId = null;
    }
}

function editPoster(id) {
    window._editingPosterId = id;
    const r = fetch(getApiUrl(API_CONFIG.endpoints.poster) + '/all').then(function(res) { return res.json(); });
    r.then(function(list) {
        const p = list.find(function(x) { return x.id === id; });
        if (p) {
            document.getElementById('poster-image-url').value = p.imageUrl || '';
            document.getElementById('poster-link-url').value = p.linkUrl || '';
            document.getElementById('poster-target-city').value = p.targetCity || '';
            document.getElementById('poster-target-state').value = p.targetState || '';
            var latEl = document.getElementById('poster-target-lat'); if (latEl) latEl.value = p.targetLat != null ? p.targetLat : '';
            var lngEl = document.getElementById('poster-target-lng'); if (lngEl) lngEl.value = p.targetLng != null ? p.targetLng : '';
            var radEl = document.getElementById('poster-target-radius'); if (radEl) radEl.value = p.targetRadiusKm != null ? p.targetRadiusKm : '';
            document.getElementById('poster-active').checked = p.active !== false;
            document.getElementById('poster-image-input').value = '';
        }
    });
}

function cancelPosterEdit() {
    window._editingPosterId = null;
    document.getElementById('poster-image-url').value = '';
    document.getElementById('poster-link-url').value = '';
    document.getElementById('poster-target-city').value = '';
    document.getElementById('poster-target-state').value = '';
    var latEl = document.getElementById('poster-target-lat'); if (latEl) latEl.value = '';
    var lngEl = document.getElementById('poster-target-lng'); if (lngEl) lngEl.value = '';
    var radEl = document.getElementById('poster-target-radius'); if (radEl) radEl.value = '';
    document.getElementById('poster-active').checked = true;
    document.getElementById('poster-image-input').value = '';
    loadMarketingPoster();
}

async function deletePoster(id) {
    if (!confirm('Delete this poster? Users in this area will see no poster and go straight to homepage.')) return;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.poster) + '/' + id, { method: 'DELETE' });
        if (r.ok) { showSuccess('Poster deleted'); window._editingPosterId = null; loadMarketingPoster(); } else showError('Delete failed');
    } catch (e) { showError('Failed'); }
}

async function savePoster() {
    const imageUrl = document.getElementById('poster-image-url').value.trim();
    const linkUrl = document.getElementById('poster-link-url').value.trim();
    const active = document.getElementById('poster-active').checked;
    const fileInput = document.getElementById('poster-image-input');
    let finalImageUrl = imageUrl;
    if (fileInput.files && fileInput.files[0]) {
        const fd = new FormData();
        fd.append('file', fileInput.files[0]);
        const r = await fetch(API_CONFIG.baseUrl + '/api/upload/poster', { method: 'POST', body: fd });
        if (!r.ok) {
            let msg = 'Upload failed';
            try { const d = await r.json(); if (d.error) msg = d.error; } catch (_) {}
            showError(msg);
            return;
        }
        const d = await r.json();
        finalImageUrl = d.url || '';
    }
    if (!finalImageUrl) { showError('Add an image (upload or URL)'); return; }
    const targetCity = document.getElementById('poster-target-city').value.trim();
    const targetState = document.getElementById('poster-target-state').value.trim();
    const latEl = document.getElementById('poster-target-lat');
    const lngEl = document.getElementById('poster-target-lng');
    const radEl = document.getElementById('poster-target-radius');
    const targetLat = latEl && latEl.value.trim() ? parseFloat(latEl.value) : null;
    const targetLng = lngEl && lngEl.value.trim() ? parseFloat(lngEl.value) : null;
    const targetRadiusKm = radEl && radEl.value.trim() ? parseFloat(radEl.value) : null;
    const body = { imageUrl: finalImageUrl, linkUrl: linkUrl || null, active, targetCity: targetCity || null, targetState: targetState || null, targetLat: targetLat, targetLng: targetLng, targetRadiusKm: targetRadiusKm };
    try {
        if (window._editingPosterId) {
            const r = await fetch(getApiUrl(API_CONFIG.endpoints.poster) + '/' + window._editingPosterId, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
            if (r.ok) { showSuccess('Poster updated'); document.getElementById('poster-image-input').value = ''; loadMarketingPoster(); } else showError('Update failed');
        } else {
            const r = await fetch(getApiUrl(API_CONFIG.endpoints.poster), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
            if (r.ok) { showSuccess('Poster saved'); document.getElementById('poster-image-input').value = ''; loadMarketingPoster(); } else showError('Save failed');
        }
    } catch (e) { showError('Failed'); }
}

// ========== AUTH BACKGROUND VIDEO ==========
async function loadAuthVideo() {
    const urlEl = document.getElementById('auth-video-url');
    const activeEl = document.getElementById('auth-video-active');
    const previewWrap = document.getElementById('auth-video-preview-wrap');
    const preview = document.getElementById('auth-video-preview');
    const statusEl = document.getElementById('auth-video-save-status');
    if (!urlEl) return;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.authVideo));
        if (r.ok) {
            const d = await r.json();
            urlEl.value = d.videoUrl || '';
            activeEl.checked = d.active !== false;
            if (d.videoUrl) {
                previewWrap.style.display = 'block';
                preview.src = d.videoUrl;
            } else {
                previewWrap.style.display = 'none';
                preview.removeAttribute('src');
            }
            if (statusEl) statusEl.textContent = '';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Failed to load: ' + (e.message || e);
    }
}

async function uploadAuthVideo() {
    const fileInput = document.getElementById('auth-video-file');
    const urlEl = document.getElementById('auth-video-url');
    const statusEl = document.getElementById('auth-video-upload-status');
    const btn = document.getElementById('auth-video-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select an MP4 file first.';
        return;
    }
    const file = fileInput.files[0];
    if (!file.type || !file.type.includes('video') && !file.name.toLowerCase().endsWith('.mp4')) {
        if (statusEl) statusEl.textContent = 'Only MP4 format is supported.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', file);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadAuthVideo), {
            method: 'POST',
            body: formData
        });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            statusEl.textContent = 'Uploaded. Click Save to apply.';
            const previewWrap = document.getElementById('auth-video-preview-wrap');
            const preview = document.getElementById('auth-video-preview');
            if (previewWrap && preview) {
                previewWrap.style.display = 'block';
                preview.src = data.url;
            }
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

// ========== HOME HERO MEDIA ==========
async function loadHomeHeroMedia() {
    const urlEl = document.getElementById('home-hero-url');
    const typeEl = document.getElementById('home-hero-type');
    const activeEl = document.getElementById('home-hero-active');
    const statusEl = document.getElementById('home-hero-save-status');
    if (!urlEl) return;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.homeHeroMedia));
        if (r.ok) {
            const d = await r.json();
            urlEl.value = d.mediaUrl || '';
            if (typeEl) typeEl.value = (d.mediaType || 'lottie') === 'gif' ? 'gif' : 'lottie';
            if (activeEl) activeEl.checked = d.active !== false;
            if (statusEl) statusEl.textContent = '';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Failed to load: ' + (e.message || e);
    }
}

async function uploadHomeHeroMedia() {
    const fileInput = document.getElementById('home-hero-file');
    const urlEl = document.getElementById('home-hero-url');
    const typeEl = document.getElementById('home-hero-type');
    const statusEl = document.getElementById('home-hero-upload-status');
    const btn = document.getElementById('home-hero-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select a .json (Lottie) or .gif file first.';
        return;
    }
    const file = fileInput.files[0];
    const name = (file.name || '').toLowerCase();
    if (!name.endsWith('.json') && !name.endsWith('.gif')) {
        if (statusEl) statusEl.textContent = 'Only Lottie (.json) or GIF (.gif) are supported.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', file);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadHomeHeroMedia), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            if (typeEl) typeEl.value = name.endsWith('.gif') ? 'gif' : 'lottie';
            statusEl.textContent = 'Uploaded. Click Save to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function saveHomeHeroMedia() {
    const urlEl = document.getElementById('home-hero-url');
    const typeEl = document.getElementById('home-hero-type');
    const activeEl = document.getElementById('home-hero-active');
    const statusEl = document.getElementById('home-hero-save-status');
    const mediaUrl = urlEl ? urlEl.value.trim() : '';
    const mediaType = typeEl ? typeEl.value : 'lottie';
    const active = activeEl ? activeEl.checked : true;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.homeHeroMedia), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mediaType, mediaUrl: mediaUrl || null, active })
        });
        if (r.ok) {
            statusEl.textContent = 'Saved. Home red header will show the graphic when active.';
            setTimeout(() => { statusEl.textContent = ''; }, 4000);
        } else {
            const err = await r.json().catch(() => ({}));
            statusEl.textContent = err.error || err.message || 'Save failed';
        }
    } catch (e) {
        statusEl.textContent = 'Failed: ' + (e.message || e);
    }
}

// ========== APP BRANDING ==========
async function loadAppBranding() {
    const logoUrlEl = document.getElementById('app-branding-logo-url');
    const welcomeEl = document.getElementById('app-branding-welcome-title');
    const splashUrlEl = document.getElementById('app-branding-splash-url');
    const splashTypeEl = document.getElementById('app-branding-splash-type');
    const welcomePageUrlEl = document.getElementById('app-branding-welcome-page-url');
    const welcomePageTypeEl = document.getElementById('app-branding-welcome-page-type');
    const statusEl = document.getElementById('app-branding-save-status');
    if (!logoUrlEl) return;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding));
        if (r.ok) {
            const d = await r.json();
            logoUrlEl.value = d.appLogoUrl || '';
            if (welcomeEl) welcomeEl.value = d.welcomeTitle || 'Welcome to ProMech';
            if (splashUrlEl) splashUrlEl.value = d.splashMediaUrl || '';
            if (splashTypeEl) splashTypeEl.value = (d.splashMediaType || 'lottie') === 'video' ? 'video' : (d.splashMediaType === 'gif' ? 'gif' : 'lottie');
            if (welcomePageUrlEl) welcomePageUrlEl.value = d.welcomePageMediaUrl || '';
            if (welcomePageTypeEl) welcomePageTypeEl.value = (d.welcomePageMediaType || 'gif') === 'video' ? 'video' : 'gif';
            const welcomePageGifUrlEl = document.getElementById('app-branding-welcome-page-gif-url');
            if (welcomePageGifUrlEl) welcomePageGifUrlEl.value = d.welcomePageGifUrl || '';
            const problemIconsEl = document.getElementById('app-branding-problem-category-icons-json');
            if (problemIconsEl) problemIconsEl.value = d.problemCategoryIconsJson || '';
            if (statusEl) statusEl.textContent = '';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Failed to load: ' + (e.message || e);
    }
}

async function uploadAppLogo() {
    const fileInput = document.getElementById('app-branding-logo-file');
    const urlEl = document.getElementById('app-branding-logo-url');
    const statusEl = document.getElementById('app-branding-logo-upload-status');
    const btn = document.getElementById('app-branding-logo-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select a PNG/JPG/WebP file first.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadAppLogo), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            statusEl.textContent = 'Uploaded. Click Save to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function uploadSplashMedia() {
    const fileInput = document.getElementById('app-branding-splash-file');
    const urlEl = document.getElementById('app-branding-splash-url');
    const typeEl = document.getElementById('app-branding-splash-type');
    const statusEl = document.getElementById('app-branding-splash-upload-status');
    const btn = document.getElementById('app-branding-splash-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select .json (Lottie), .gif, or .mp4 first.';
        return;
    }
    const name = (fileInput.files[0].name || '').toLowerCase();
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadSplashMedia), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            if (typeEl) typeEl.value = name.endsWith('.mp4') ? 'video' : (name.endsWith('.gif') ? 'gif' : 'lottie');
            statusEl.textContent = 'Uploaded. Click Save to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function uploadWelcomePageMedia() {
    const fileInput = document.getElementById('app-branding-welcome-page-file');
    const urlEl = document.getElementById('app-branding-welcome-page-url');
    const typeEl = document.getElementById('app-branding-welcome-page-type');
    const statusEl = document.getElementById('app-branding-welcome-page-upload-status');
    const btn = document.getElementById('app-branding-welcome-page-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select a .gif or .mp4 file first.';
        return;
    }
    const name = (fileInput.files[0].name || '').toLowerCase();
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadWelcomePageMedia), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            if (typeEl) typeEl.value = name.endsWith('.mp4') ? 'video' : 'gif';
            statusEl.textContent = 'Uploaded. Click Save to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function saveAppBranding() {
    const logoUrlEl = document.getElementById('app-branding-logo-url');
    const welcomeEl = document.getElementById('app-branding-welcome-title');
    const splashUrlEl = document.getElementById('app-branding-splash-url');
    const splashTypeEl = document.getElementById('app-branding-splash-type');
    const welcomePageUrlEl = document.getElementById('app-branding-welcome-page-url');
    const welcomePageTypeEl = document.getElementById('app-branding-welcome-page-type');
    const welcomePageGifUrlEl = document.getElementById('app-branding-welcome-page-gif-url');
    const statusEl = document.getElementById('app-branding-save-status');
    const appLogoUrl = logoUrlEl ? logoUrlEl.value.trim() : '';
    const welcomeTitle = welcomeEl ? welcomeEl.value.trim() : 'Welcome to ProMech';
    const splashMediaUrl = splashUrlEl ? splashUrlEl.value.trim() : '';
    const splashMediaType = splashTypeEl ? splashTypeEl.value : 'lottie';
    const welcomePageMediaUrl = welcomePageUrlEl ? welcomePageUrlEl.value.trim() : '';
    const welcomePageMediaType = welcomePageTypeEl ? welcomePageTypeEl.value : 'gif';
    const welcomePageGifUrl = welcomePageGifUrlEl ? welcomePageGifUrlEl.value.trim() : '';
    const problemIconsEl = document.getElementById('app-branding-problem-category-icons-json');
    const problemCategoryIconsJson = problemIconsEl ? problemIconsEl.value.trim() : '';
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                appLogoUrl: appLogoUrl || null,
                welcomeTitle: welcomeTitle || 'Welcome to ProMech',
                splashMediaUrl: splashMediaUrl || null,
                splashMediaType: splashMediaType || 'lottie',
                welcomePageMediaUrl: welcomePageMediaUrl || null,
                welcomePageMediaType: welcomePageMediaType || 'gif',
                welcomePageGifUrl: welcomePageGifUrl || null,
                problemCategoryIconsJson: problemCategoryIconsJson || null
            })
        });
        if (r.ok) {
            statusEl.textContent = 'Saved. Reloading…';
            await loadAppBranding();
            statusEl.textContent = 'Saved. Restart the app (or reopen the screen) to see the logo.';
            setTimeout(() => { statusEl.textContent = ''; }, 6000);
        } else {
            const err = await r.json().catch(() => ({}));
            statusEl.textContent = err.error || err.message || 'Save failed';
        }
    } catch (e) {
        statusEl.textContent = 'Failed: ' + (e.message || e);
    }
}

// ========== CAR / BIKE & QUICK SERVICE ICONS ==========
async function loadCarBikeQuickIcons() {
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding));
        if (!r.ok) return;
        const d = await r.json();
        const set = (id, val) => { const el = document.getElementById(id); if (el) el.value = val || ''; };
        set('car-service-image-url', d.carServiceImageUrl);
        set('bike-service-image-url', d.bikeServiceImageUrl);
        set('qs-night-service-url', d.quickServiceNightServiceIconUrl);
        set('qs-towing-url', d.quickServiceTowingIconUrl);
        set('qs-fuel-refill-url', d.quickServiceFuelRefillIconUrl);
        set('qs-ev-charging-url', d.quickServiceEvChargingIconUrl);
        set('qs-tyre-care-url', d.quickServiceTyreCareIconUrl);
        set('qs-minor-repair-url', d.quickServiceMinorRepairIconUrl);
        set('qs-battery-jump-url', d.quickServiceBatteryJumpIconUrl);
    } catch (e) {}
}

async function uploadCarServiceImage() {
    const fileInput = document.getElementById('car-service-image-file');
    const urlEl = document.getElementById('car-service-image-url');
    const statusEl = document.getElementById('car-service-image-status');
    const btn = document.getElementById('car-service-image-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select an image first.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadCarServiceImage), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            statusEl.textContent = 'Uploaded. Click Save all URLs to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function uploadBikeServiceImage() {
    const fileInput = document.getElementById('bike-service-image-file');
    const urlEl = document.getElementById('bike-service-image-url');
    const statusEl = document.getElementById('bike-service-image-status');
    const btn = document.getElementById('bike-service-image-upload-btn');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select an image first.';
        return;
    }
    if (btn) btn.disabled = true;
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadBikeServiceImage), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            statusEl.textContent = 'Uploaded. Click Save all URLs to apply.';
        } else {
            statusEl.textContent = data.error || 'Upload failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error: ' + (e.message || e);
    }
    if (btn) btn.disabled = false;
}

async function uploadQuickServiceIcon(name) {
    const suffix = name.replace(/_/g, '-');
    const fileInput = document.getElementById('qs-' + suffix + '-file');
    const urlEl = document.getElementById('qs-' + suffix + '-url');
    const statusEl = document.getElementById('qs-' + suffix + '-status');
    if (!fileInput || !fileInput.files || !fileInput.files[0]) {
        if (statusEl) statusEl.textContent = 'Select file first.';
        return;
    }
    if (statusEl) statusEl.textContent = 'Uploading...';
    try {
        const formData = new FormData();
        formData.append('file', fileInput.files[0]);
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.uploadQuickServiceIcon) + '?name=' + encodeURIComponent(name), { method: 'POST', body: formData });
        const data = await r.json().catch(() => ({}));
        if (r.ok && data.url) {
            urlEl.value = data.url;
            statusEl.textContent = 'Uploaded. Saving...';
            // Auto-save so icons show in app without requiring "Save all URLs"
            await saveCarBikeQuickIcons();
            if (statusEl) statusEl.textContent = 'Uploaded and saved.';
        } else {
            statusEl.textContent = data.error || 'Failed';
        }
    } catch (e) {
        if (statusEl) statusEl.textContent = 'Error';
    }
}

async function saveCarBikeQuickIcons() {
    const statusEl = document.getElementById('car-bike-quick-save-status');
    try {
        const brandingRes = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding));
        const branding = brandingRes.ok ? await brandingRes.json() : {};
        const get = (id) => { const el = document.getElementById(id); return el ? el.value.trim() : ''; };
        const body = { ...branding,
            carServiceImageUrl: get('car-service-image-url') || null,
            bikeServiceImageUrl: get('bike-service-image-url') || null,
            quickServiceNightServiceIconUrl: get('qs-night-service-url') || null,
            quickServiceTowingIconUrl: get('qs-towing-url') || null,
            quickServiceFuelRefillIconUrl: get('qs-fuel-refill-url') || null,
            quickServiceEvChargingIconUrl: get('qs-ev-charging-url') || null,
            quickServiceTyreCareIconUrl: get('qs-tyre-care-url') || null,
            quickServiceMinorRepairIconUrl: get('qs-minor-repair-url') || null,
            quickServiceBatteryJumpIconUrl: get('qs-battery-jump-url') || null
        };
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appBranding), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body)
        });
        if (r.ok) {
            statusEl.textContent = 'Saved.';
            setTimeout(() => { statusEl.textContent = ''; }, 3000);
        } else {
            statusEl.textContent = 'Save failed';
        }
    } catch (e) {
        statusEl.textContent = 'Error: ' + (e.message || e);
    }
}

async function saveAuthVideo() {
    const urlEl = document.getElementById('auth-video-url');
    const activeEl = document.getElementById('auth-video-active');
    const statusEl = document.getElementById('auth-video-save-status');
    const videoUrl = urlEl ? urlEl.value.trim() : '';
    const active = activeEl ? activeEl.checked : true;
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.authVideo), {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ videoUrl: videoUrl || null, active })
        });
        if (r.ok) {
            statusEl.textContent = 'Saved. Reloading…';
            await loadAuthVideo();
            statusEl.textContent = videoUrl ? 'Saved. Restart the app (or reopen login/signup) to see the video.' : 'Saved. Upload a video first, then Save again to show it in the app.';
            setTimeout(() => { statusEl.textContent = ''; }, 6000);
        } else {
            const err = await r.json().catch(() => ({}));
            statusEl.textContent = err.error || err.message || 'Save failed';
        }
    } catch (e) {
        statusEl.textContent = 'Failed: ' + (e.message || e);
    }
}

// ========== APP VERSION ==========
async function loadAppVersion() {
    try {
        const r = await fetch(getApiUrl(API_CONFIG.endpoints.appVersion));
        if (r.ok) {
            const c = await r.json();
            document.getElementById('app-version-latest').value = c.latestVersion || '';
            document.getElementById('app-version-min').value = c.minRequiredVersion || '';
            document.getElementById('app-version-title').value = c.updateTitle || '';
            document.getElementById('app-version-message').value = c.updateMessage || '';
            window._editingAppVersionId = c.id;
        } else {
            window._editingAppVersionId = null;
        }
    } catch (e) { window._editingAppVersionId = null; }
}

async function saveAppVersion() {
    const latestVersion = document.getElementById('app-version-latest').value.trim();
    const minRequiredVersion = document.getElementById('app-version-min').value.trim();
    const updateTitle = document.getElementById('app-version-title').value.trim();
    const updateMessage = document.getElementById('app-version-message').value.trim();
    try {
        if (window._editingAppVersionId) {
            const r = await fetch(getApiUrl(API_CONFIG.endpoints.appVersion) + '/' + window._editingAppVersionId, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ latestVersion, minRequiredVersion, updateTitle, updateMessage })
            });
            if (r.ok) { showSuccess('Saved'); loadAppVersion(); } else { const err = await r.json().catch(() => ({})); showError(err.message || err.error || 'Save failed'); }
        } else {
            const r = await fetch(getApiUrl(API_CONFIG.endpoints.appVersion), {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ latestVersion, minRequiredVersion, updateTitle, updateMessage })
            });
            if (r.ok) { showSuccess('Saved'); loadAppVersion(); } else { const err = await r.json().catch(() => ({})); showError(err.message || err.error || 'Save failed'); }
        }
    } catch (e) { showError('Failed: ' + (e.message || e)); }
}

// ========== LIVE TRACKING ==========

let map = null;
let markers = [];

function initMaps() {
    // Initialize map for live tracking
    if (document.getElementById('map')) {
        map = new google.maps.Map(document.getElementById('map'), {
            zoom: 10,
            center: { lat: 28.6139, lng: 77.2090 },
            mapTypeId: 'roadmap',
            mapTypeControl: false
        });
    }
    
    // Initialize map for active jobs
    if (document.getElementById('jobs-map')) {
        window.jobsMap = new google.maps.Map(document.getElementById('jobs-map'), {
            zoom: 10,
            center: { lat: 28.6139, lng: 77.2090 },
            mapTypeId: 'roadmap',
            mapTypeControl: false
        });
    }
}

async function loadLiveTracking() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.mechanicLocations));
        const locations = await response.json();
        displayLocations(locations);
        updateMap(locations);
    } catch (error) {
        console.error('Error loading live tracking:', error);
        showError('Failed to load live tracking');
    }
}

function displayLocations(locations) {
    const tbody = document.getElementById('locations-table-body');
    if (locations.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="loading">No mechanics found</td></tr>';
        return;
    }
    
    tbody.innerHTML = locations.map(loc => `
        <tr>
            <td>${loc.id}</td>
            <td><strong>${loc.name || 'N/A'}</strong></td>
            <td>${loc.isOnline ? '<span class="status-badge approved">Online</span>' : '<span class="status-badge pending">Offline</span>'}</td>
            <td>${loc.latitude}, ${loc.longitude}</td>
            <td>${loc.lastUpdate ? new Date(loc.lastUpdate).toLocaleString() : 'Never'}</td>
        </tr>
    `).join('');
}

function updateMap(locations) {
    if (!map) return;
    
    // Clear existing markers
    markers.forEach(marker => marker.setMap(null));
    markers = [];
    
    // Add new markers
    locations.forEach(loc => {
        if (loc.latitude && loc.longitude) {
            const marker = new google.maps.Marker({
                position: { lat: parseFloat(loc.latitude), lng: parseFloat(loc.longitude) },
                map: map,
                title: loc.name,
                icon: {
                    url: loc.isOnline ? 'http://maps.google.com/mapfiles/ms/icons/green-dot.png' : 'http://maps.google.com/mapfiles/ms/icons/red-dot.png',
                    scaledSize: new google.maps.Size(32, 32)
                }
            });
            
            const infoWindow = new google.maps.InfoWindow({
                content: `
                    <div>
                        <strong>${loc.name}</strong><br>
                        ${loc.phone || ''}<br>
                        ${loc.specialty || ''}<br>
                        Status: ${loc.status || 'N/A'}<br>
                        ${loc.isOnline ? 'Online' : 'Offline'}
                    </div>
                `
            });
            
            marker.addListener('click', () => infoWindow.open(map, marker));
            markers.push(marker);
        }
    });
    
    // Fit bounds to show all markers
    if (markers.length > 0) {
        const bounds = new google.maps.LatLngBounds();
        markers.forEach(marker => bounds.extend(marker.getPosition()));
        map.fitBounds(bounds);
    }
}

function filterLocations() {
    const filter = document.getElementById('location-filter').value;
    loadLiveTrackingWithFilter(filter);
}

// ========== MECHANICS MAP SECTION ==========
async function loadMechanicsMap() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.mechanics));
        const mechanics = await response.json();
        allMechanics = mechanics;

        const cities = [...new Set(mechanics.map(m => (m.shopCity || m.shop_city || 'Unknown').trim()).filter(Boolean))].sort();
        const citySelect = document.getElementById('mechanics-map-city-filter');
        if (citySelect) {
            const current = citySelect.value;
            citySelect.innerHTML = '<option value="">All Cities</option>' + cities.map(c => `<option value="${escapeAttr(c)}">${escapeAttr(c)}</option>`).join('');
            if (current && cities.includes(current)) citySelect.value = current;
        }

        displayMechanicsMapDetailTable(mechanics);
        initAllMechanicsMap(mechanics);
        filterMechanicsMapByCity();
    } catch (error) {
        console.error('Error loading mechanics map:', error);
        showError('Failed to load mechanics map');
        document.getElementById('mechanics-map-detail-table').innerHTML = '<tr><td colspan="7" class="loading">Error loading data</td></tr>';
    }
}

function displayMechanicsMapDetailTable(mechanics) {
    const tbody = document.getElementById('mechanics-map-detail-table');
    if (!tbody) return;
    if (!mechanics || mechanics.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="loading">No mechanics found</td></tr>';
        return;
    }
    tbody.innerHTML = mechanics.map(m => {
        const city = m.shopCity || m.shop_city || 'N/A';
        const status = m.status || 'Available';
        const online = m.isOnline ? 'Online' : 'Offline';
        const hours = [m.openingTime, m.closingTime].filter(Boolean).length ? ((m.openingTime || '') + ' – ' + (m.closingTime || '')) : 'N/A';
        const days = (m.workingDays || m.working_days || 'N/A').toString().replace(/,/g, ', ');
        const night = m.nightTimeAvailable ? 'Yes' : 'No';
        return `<tr>
            <td><strong>${escapeAttr(m.name || 'N/A')}</strong></td>
            <td>${escapeAttr(city)}</td>
            <td><span class="status-badge ${status.toLowerCase()}">${escapeAttr(status)}</span></td>
            <td>${m.isOnline ? '<span class="status-badge approved">Online</span>' : '<span class="status-badge pending">Offline</span>'}</td>
            <td>${escapeAttr(hours)}</td>
            <td>${escapeAttr(days)}</td>
            <td>${night}</td>
        </tr>`;
    }).join('');
}

function initAllMechanicsMap(mechanics) {
    const mapEl = document.getElementById('all-mechanics-map');
    if (!mapEl || typeof google === 'undefined' || !google.maps) return;
    const withLoc = (mechanics || []).filter(m => {
        const lat = parseFloat(m.latitude);
        const lng = parseFloat(m.longitude);
        return !isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0;
    });
    if (withLoc.length === 0) {
        mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">No mechanic locations available</p>';
        return;
    }
    mapEl.innerHTML = '';
    allMechanicsMapMarkers.forEach(m => m.setMap(null));
    allMechanicsMapMarkers = [];
    allMechanicsMap = new google.maps.Map(mapEl, {
        zoom: 10,
        center: { lat: parseFloat(withLoc[0].latitude), lng: parseFloat(withLoc[0].longitude) },
        mapTypeId: 'roadmap',
        mapTypeControl: false
    });
    const bounds = new google.maps.LatLngBounds();
    withLoc.forEach(m => {
        const lat = parseFloat(m.latitude);
        const lng = parseFloat(m.longitude);
        const marker = new google.maps.Marker({
            position: { lat, lng },
            map: allMechanicsMap,
            title: m.name,
            icon: {
                url: m.isOnline ? 'http://maps.google.com/mapfiles/ms/icons/green-dot.png' : 'http://maps.google.com/mapfiles/ms/icons/red-dot.png',
                scaledSize: new google.maps.Size(28, 28)
            }
        });
        const info = `<strong>${escapeAttr(m.name || 'N/A')}</strong><br>${escapeAttr(m.shopCity || m.shop_city || '')}<br>${m.isOnline ? 'Online' : 'Offline'}<br>Hours: ${escapeAttr((m.openingTime || '') + ' – ' + (m.closingTime || ''))}`;
        const iw = new google.maps.InfoWindow({ content: info });
        marker.addListener('click', () => iw.open(allMechanicsMap, marker));
        allMechanicsMapMarkers.push(marker);
        bounds.extend({ lat, lng });
    });
    if (allMechanicsMapMarkers.length) allMechanicsMap.fitBounds(bounds);
}

function filterMechanicsMapByCity() {
    const citySelect = document.getElementById('mechanics-map-city-filter');
    const city = citySelect ? citySelect.value : '';
    let list = allMechanics || [];
    if (city) list = list.filter(m => (m.shopCity || m.shop_city || '').trim() === city);
    initMechanicsByCityMap(list);
}

function initMechanicsByCityMap(mechanics) {
    const mapEl = document.getElementById('mechanics-by-city-map');
    if (!mapEl || typeof google === 'undefined' || !google.maps) return;
    const withLoc = (mechanics || []).filter(m => {
        const lat = parseFloat(m.latitude);
        const lng = parseFloat(m.longitude);
        return !isNaN(lat) && !isNaN(lng) && lat !== 0 && lng !== 0;
    });
    mechanicsByCityMapMarkers.forEach(m => m.setMap(null));
    mechanicsByCityMapMarkers = [];
    if (withLoc.length === 0) {
        if (!mechanicsByCityMapInstance) {
            mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Select a city or add mechanics with location</p>';
        }
        return;
    }
    if (!mechanicsByCityMapInstance) {
        mapEl.innerHTML = '';
        mechanicsByCityMapInstance = new google.maps.Map(mapEl, {
            zoom: 12,
            center: { lat: parseFloat(withLoc[0].latitude), lng: parseFloat(withLoc[0].longitude) },
            mapTypeId: 'roadmap',
            mapTypeControl: false
        });
    }
    const bounds = new google.maps.LatLngBounds();
    withLoc.forEach(m => {
        const lat = parseFloat(m.latitude);
        const lng = parseFloat(m.longitude);
        const marker = new google.maps.Marker({
            position: { lat, lng },
            map: mechanicsByCityMapInstance,
            title: m.name,
            icon: {
                url: m.isOnline ? 'http://maps.google.com/mapfiles/ms/icons/green-dot.png' : 'http://maps.google.com/mapfiles/ms/icons/red-dot.png',
                scaledSize: new google.maps.Size(28, 28)
            }
        });
        const info = `<strong>${escapeAttr(m.name || 'N/A')}</strong><br>${m.isOnline ? 'Online' : 'Offline'}<br>Hours: ${escapeAttr((m.openingTime || '') + ' – ' + (m.closingTime || ''))}`;
        const iw = new google.maps.InfoWindow({ content: info });
        marker.addListener('click', () => iw.open(mechanicsByCityMapInstance, marker));
        mechanicsByCityMapMarkers.push(marker);
        bounds.extend({ lat, lng });
    });
    if (mechanicsByCityMapMarkers.length) mechanicsByCityMapInstance.fitBounds(bounds);
}

async function loadLiveTrackingWithFilter(filter) {
    try {
        const url = filter === 'all' 
            ? getApiUrl(API_CONFIG.endpoints.mechanicLocations)
            : `${getApiUrl(API_CONFIG.endpoints.mechanicLocations)}?filter=${filter}`;
        const response = await fetch(url);
        const locations = await response.json();
        displayLocations(locations);
        updateMap(locations);
    } catch (error) {
        console.error('Error loading filtered locations:', error);
        showError('Failed to load locations');
    }
}

// ========== ACTIVE JOBS ==========

async function loadActiveJobs() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.activeJobs));
        const jobs = await response.json();
        displayActiveJobs(jobs);
        updateJobsMap(jobs);
    } catch (error) {
        console.error('Error loading active jobs:', error);
        showError('Failed to load active jobs');
    }
}

function displayActiveJobs(jobs) {
    const tbody = document.getElementById('active-jobs-table-body');
    if (jobs.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="loading">No active jobs</td></tr>';
        return;
    }
    
    tbody.innerHTML = jobs.map(job => `
        <tr>
            <td>${job.requestId}</td>
            <td><strong>${job.customerName || 'N/A'}</strong><br><small>${job.customerPhone || ''}</small></td>
            <td>${job.serviceType || 'N/A'}</td>
            <td>${job.mechanicName || 'N/A'}</td>
            <td>₹${(job.amount || 0).toLocaleString('en-IN')}</td>
            <td>${job.requestTime ? new Date(job.requestTime).toLocaleString() : 'N/A'}</td>
        </tr>
    `).join('');
}

function updateJobsMap(jobs) {
    if (!window.jobsMap) return;
    
    // Clear existing markers
    if (window.jobMarkers) {
        window.jobMarkers.forEach(marker => marker.setMap(null));
    }
    window.jobMarkers = [];
    
    jobs.forEach(job => {
        if (job.serviceLatitude && job.serviceLongitude) {
            // Service location marker
            const serviceMarker = new google.maps.Marker({
                position: { lat: parseFloat(job.serviceLatitude), lng: parseFloat(job.serviceLongitude) },
                map: window.jobsMap,
                title: `Service: ${job.serviceType}`,
                icon: {
                    url: 'http://maps.google.com/mapfiles/ms/icons/blue-dot.png',
                    scaledSize: new google.maps.Size(32, 32)
                }
            });
            
            // Mechanic location marker if available
            if (job.mechanicLatitude && job.mechanicLongitude) {
                const mechanicMarker = new google.maps.Marker({
                    position: { lat: parseFloat(job.mechanicLatitude), lng: parseFloat(job.mechanicLongitude) },
                    map: window.jobsMap,
                    title: `Mechanic: ${job.mechanicName}`,
                    icon: {
                        url: 'http://maps.google.com/mapfiles/ms/icons/green-dot.png',
                        scaledSize: new google.maps.Size(32, 32)
                    }
                });
                
                // Draw line between mechanic and service location
                const line = new google.maps.Polyline({
                    path: [
                        { lat: parseFloat(job.mechanicLatitude), lng: parseFloat(job.mechanicLongitude) },
                        { lat: parseFloat(job.serviceLatitude), lng: parseFloat(job.serviceLongitude) }
                    ],
                    map: window.jobsMap,
                    strokeColor: '#FF0000',
                    strokeWeight: 2
                });
                
                window.jobMarkers.push(mechanicMarker);
            }
            
            const infoWindow = new google.maps.InfoWindow({
                content: `
                    <div>
                        <strong>Service Request #${job.requestId}</strong><br>
                        Customer: ${job.customerName}<br>
                        Service: ${job.serviceType}<br>
                        Mechanic: ${job.mechanicName}<br>
                        Amount: ₹${job.amount || 0}
                    </div>
                `
            });
            
            serviceMarker.addListener('click', () => infoWindow.open(window.jobsMap, serviceMarker));
            window.jobMarkers.push(serviceMarker);
        }
    });
    
    // Fit bounds
    if (window.jobMarkers.length > 0) {
        const bounds = new google.maps.LatLngBounds();
        window.jobMarkers.forEach(marker => bounds.extend(marker.getPosition()));
        window.jobsMap.fitBounds(bounds);
    }
}

// Notifications
function showSuccess(message) {
    showNotification(message, 'success');
}

function showError(message) {
    showNotification(message, 'error');
}

function showNotification(message, type) {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `<i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'}"></i> ${message}`;
    toast.style.cssText = 'position:fixed;bottom:24px;right:24px;padding:16px 24px;border-radius:12px;font-weight:500;z-index:9999;display:flex;align-items:center;gap:10px;box-shadow:0 8px 24px rgba(0,0,0,0.15);animation:slideIn 0.3s ease;';
    toast.style.background = type === 'success' ? '#10B981' : '#EF4444';
    toast.style.color = 'white';
    document.body.appendChild(toast);
    setTimeout(() => { toast.style.opacity = '0'; toast.style.transition = 'opacity 0.3s'; setTimeout(() => toast.remove(), 300); }, 3000);
}

// Mechanic Help Chat (no photo; polling + typing + messages by date)
let mechanicHelpPollTimer = null;
let mechanicHelpOpenEmail = null;
let mechanicHelpTypingTimeout = null;
const MECHANIC_HELP_POLL_MS = 2500;

async function loadHelpThreads() {
    const el = document.getElementById('help-threads-list');
    if (!el) return;
    el.innerHTML = '<div class="loading">Loading...</div>';
    try {
        const [messagesRes, mechanicsRes] = await Promise.all([
            fetch(getApiUrl('/api/admin/help/messages')),
            fetch(getApiUrl(API_CONFIG.endpoints.mechanics))
        ]);
        const mechanics = mechanicsRes.ok ? await mechanicsRes.json() : [];
        helpMechanicsByEmail = {};
        (mechanics || []).forEach(m => { if (m.email) helpMechanicsByEmail[m.email.trim().toLowerCase()] = m; });
        if (!messagesRes.ok) { el.innerHTML = '<p class="muted">Failed to load.</p>'; return; }
        const emails = await messagesRes.json();
        if (!Array.isArray(emails) || emails.length === 0) {
            el.innerHTML = '<p class="muted">No conversations yet.</p>';
            return;
        }
        el.innerHTML = emails.map(email => {
            const mechanic = helpMechanicsByEmail[(email || '').trim().toLowerCase()];
            const phone = mechanic && mechanic.phone ? mechanic.phone : '';
            return `<div class="support-thread-item help-thread-item" data-email="${escapeAttr(email)}">
                <i class="fas fa-user-cog"></i> ${escapeAttr(email)}${phone ? `<br><small style="color:var(--text-secondary);"><i class="fas fa-phone"></i> ${escapeAttr(phone)}</small>` : ''}
            </div>`;
        }).join('');
        el.querySelectorAll('.help-thread-item').forEach(item => {
            item.addEventListener('click', function() {
                document.querySelectorAll('#help-threads-list .support-thread-item').forEach(x => x.classList.remove('active'));
                this.classList.add('active');
                openHelpThread(this.getAttribute('data-email'));
            });
        });
    } catch (e) {
        el.innerHTML = '<p class="muted">Error loading.</p>';
    }
}

function renderMechanicHelpMessages(messages) {
    const listEl = document.getElementById('help-messages-list');
    if (!listEl) return;
    if (!Array.isArray(messages) || messages.length === 0) {
        listEl.innerHTML = '<p class="muted">No messages yet. Reply below.</p>';
        return;
    }
    const groups = groupMessagesByDate(messages);
    let html = '';
    Object.keys(groups).sort((a,b) => new Date(a) - new Date(b)).forEach(dateKey => {
        html += '<div class="support-msg-date">' + escapeAttr(new Date(dateKey).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })) + '</div>';
        groups[dateKey].forEach(m => {
            const isAdmin = (m.sender || '').toUpperCase() === 'ADMIN';
            const time = m.createdAt ? new Date(m.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';
            html += '<div style="text-align:' + (isAdmin ? 'right' : 'left') + ';"><div class="support-msg-bubble ' + (isAdmin ? 'admin' : 'user') + '">' + escapeAttr(m.message || '') + '<div class="support-msg-time">' + (isAdmin ? 'Support' : 'Mechanic') + ' · ' + time + '</div></div></div>';
        });
    });
    listEl.innerHTML = html;
    listEl.scrollTop = listEl.scrollHeight;
}

async function openHelpThread(email) {
    if (mechanicHelpPollTimer) { clearInterval(mechanicHelpPollTimer); mechanicHelpPollTimer = null; }
    mechanicHelpOpenEmail = email;
    document.getElementById('help-reply-email').value = email;
    document.getElementById('help-chat-title').textContent = email;
    const phoneEl = document.getElementById('help-chat-phone');
    const mechanic = helpMechanicsByEmail[(email || '').trim().toLowerCase()];
    if (phoneEl) phoneEl.innerHTML = mechanic && mechanic.phone ? '<i class="fas fa-phone"></i> ' + escapeAttr(mechanic.phone) : '';
    document.getElementById('help-reply-box').style.display = 'block';
    document.getElementById('help-typing').style.display = 'none';
    const listEl = document.getElementById('help-messages-list');
    listEl.innerHTML = '<div class="loading">Loading...</div>';
    await loadMechanicHelpMessagesOnly(email);
    mechanicHelpPollTimer = setInterval(function() {
        if (mechanicHelpOpenEmail === email) {
            loadMechanicHelpMessagesOnly(email);
            fetch(getApiUrl('/api/admin/help/typing') + '?email=' + encodeURIComponent(email)).then(r => r.json()).then(d => {
                document.getElementById('help-typing').style.display = (d.mechanicTyping ? 'block' : 'none');
            }).catch(() => {});
        }
    }, MECHANIC_HELP_POLL_MS);
}

async function loadMechanicHelpMessagesOnly(email) {
    const listEl = document.getElementById('help-messages-list');
    if (mechanicHelpOpenEmail !== email) return;
    try {
        const res = await fetch(getApiUrl('/api/admin/help/messages') + '?email=' + encodeURIComponent(email));
        if (!res.ok || mechanicHelpOpenEmail !== email) return;
        const messages = await res.json();
        if (mechanicHelpOpenEmail === email) renderMechanicHelpMessages(messages);
    } catch (e) {}
}

function mechanicHelpTypingDebounce() {
    clearTimeout(mechanicHelpTypingTimeout);
    const email = document.getElementById('help-reply-email').value;
    if (!email) return;
    fetch(getApiUrl('/api/admin/help/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mechanicEmail: email, isTyping: true }) }).catch(() => {});
    mechanicHelpTypingTimeout = setTimeout(function() {
        fetch(getApiUrl('/api/admin/help/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mechanicEmail: email, isTyping: false }) }).catch(() => {});
    }, 2000);
}

async function sendHelpReply() {
    const email = document.getElementById('help-reply-email').value;
    const message = (document.getElementById('help-reply-message').value || '').trim();
    if (!email || !message) { showError('Enter a message.'); return; }
    try {
        const res = await fetch(getApiUrl('/api/admin/help/reply'), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ mechanicEmail: email, message: message })
        });
        if (!res.ok) { showError('Failed to send.'); return; }
        document.getElementById('help-reply-message').value = '';
        fetch(getApiUrl('/api/admin/help/typing'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mechanicEmail: email, isTyping: false }) }).catch(() => {});
        loadMechanicHelpMessagesOnly(email);
    } catch (e) {
        showError('Error sending reply.');
    }
}
