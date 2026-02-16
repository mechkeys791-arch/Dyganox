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

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    loadDashboard();
    setupModal();
    // Click on profile photo thumb to open preview
    document.body.addEventListener('click', function(e) {
        const el = e.target.closest('.photo-thumb-clickable');
        if (!el) return;
        const url = el.getAttribute('data-url');
        if (!url) return;
        e.preventDefault();
        showPhotoModal(url, el.getAttribute('data-name') || 'Photo');
    });
});

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
        'tracking': 'Request Tracking',
        'analytics': 'Detailed Analytics',
        'users': 'User Management',
        'live-tracking': 'Live Tracking',
        'active-jobs': 'Active Jobs',
        'banners': 'Carousel / Banners'
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
        case 'tracking':
            loadTracking();
            break;
        case 'analytics':
            loadAnalytics();
            break;
        case 'users':
            loadUsers();
            break;
        case 'live-tracking':
            loadLiveTracking();
            break;
        case 'active-jobs':
            loadActiveJobs();
            break;
        case 'banners':
            loadBanners();
            break;
    }
}

// Dashboard
async function loadDashboard() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.analytics));
        const data = await response.json();
        analyticsData = data;
        
        updateDashboardStats(data);
        updateCharts(data);
    } catch (error) {
        console.error('Error loading dashboard:', error);
        showError('Failed to load dashboard data');
    }
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
                backgroundColor: '#706DC7'
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
                    backgroundColor: 'rgba(112, 109, 199, 0.7)'
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

function displayRegistrationRequests(list) {
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
            ? `<button class="btn-action btn-approve" onclick="approveRegistrationRequest(${r.id})">Approve</button>
               <button class="btn-action btn-reject" onclick="rejectRegistrationRequest(${r.id})">Reject</button>`
            : '<span class="status-badge ' + statusClass + '">' + status + '</span>';
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
    if (!confirm('Approve this mechanic? A temporary password will be generated. Send it to the mechanic (e.g. via WhatsApp).')) return;
    try {
        const response = await fetch(
            `${getApiUrl(API_CONFIG.endpoints.registrationRequests)}/${id}/approve`,
            { method: 'PUT' }
        );
        const data = await response.json().catch(() => ({}));
        if (response.ok) {
            const msg = data.tempPassword
                ? `Approved. Send this password to ${data.email || 'mechanic'}: ${data.tempPassword}`
                : 'Mechanic approved successfully';
            showSuccess(msg);
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
        case 'tracking-section':
            loadTracking();
            break;
        case 'analytics-section':
            loadAnalytics();
            break;
        case 'users-section':
            loadUsers();
            break;
        case 'live-tracking-section':
            loadLiveTracking();
            break;
        case 'active-jobs-section':
            loadActiveJobs();
            break;
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
        tbody.innerHTML = '<tr><td colspan="8" class="loading">No users found</td></tr>';
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

async function viewUserBookings(email) {
    try {
        const response = await fetch(`${getApiUrl(API_CONFIG.endpoints.users)}/${encodeURIComponent(email)}/bookings`);
        const bookings = await response.json();
        
        const content = document.getElementById('mechanic-performance-content');
        content.innerHTML = `
            <h3>Bookings for ${email}</h3>
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
                <div class="profile-detail-item"><i class="fas fa-store"></i><div><strong>Shop Name</strong><br>${mechanic.shopName || mechanic.shop_name || 'N/A'}</div></div>
                <div class="profile-detail-item full-width"><i class="fas fa-map-marker-alt"></i><div><strong>Shop Address</strong><br>${mechanic.shopAddress || mechanic.shop_address || 'N/A'}</div></div>
                <div class="profile-detail-item"><i class="fas fa-city"></i><div><strong>City</strong><br>${mechanic.shopCity || mechanic.shop_city || 'N/A'}</div></div>
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
    
    if (leafletProfileMap) {
        leafletProfileMap.remove();
        leafletProfileMap = null;
    }
    
    mapEl.innerHTML = '';
    mapEl.style.minHeight = '350px';
    
    if (typeof L === 'undefined') {
        mapEl.innerHTML = '<p style="padding:20px;color:#64748b;">Map library loading...</p>';
        return;
    }
    
    leafletProfileMap = L.map(mapEl).setView([lat, lng], 16);
    
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(leafletProfileMap);
    
    const marker = L.marker([lat, lng]).addTo(leafletProfileMap);
    marker.bindPopup(`<strong>${title || 'Shop'}</strong><br>📍 ${lat.toFixed(5)}, ${lng.toFixed(5)}`).openPopup();
    
    setTimeout(() => leafletProfileMap?.invalidateSize(), 200);
}

function closeProfileModal() {
    document.getElementById('mechanic-profile-modal').style.display = 'none';
    if (leafletProfileMap) { leafletProfileMap.remove(); leafletProfileMap = null; }
    document.querySelector('.profile-map-fallback')?.remove();
    const mapEl = document.getElementById('profile-map');
    if (mapEl) { mapEl.classList.remove('hidden'); mapEl.innerHTML = ''; }
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
                <div class="carousel-preview-card" style="background-image: url('${b.imageUrl || ''}')">
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
            <div class="banner-card-image" style="background-image: url('${b.imageUrl || ''}')"></div>
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
    document.getElementById('banner-order').value = String(b.sortOrder || 0);
    document.getElementById('banner-active').checked = b.active !== false;
    document.getElementById('banner-modal').style.display = 'block';
}

async function saveBanner() {
    const title = document.getElementById('banner-title').value.trim();
    const subtitle = document.getElementById('banner-subtitle').value.trim();
    const order = parseInt(document.getElementById('banner-order').value, 10) || 0;
    const active = document.getElementById('banner-active').checked;
    const fileInput = document.getElementById('banner-image-input');

    let imageUrl = null;
    if (fileInput.files && fileInput.files[0]) {
        const fd = new FormData();
        fd.append('file', fileInput.files[0]);
        const resp = await fetch(`${API_CONFIG.baseUrl}${API_CONFIG.endpoints.uploadBanner}`, { method: 'POST', body: fd });
        const data = await resp.json();
        if (!resp.ok) {
            showError(data.error || 'Upload failed');
            return;
        }
        imageUrl = data.url;
    }

    if (editingBannerId) {
        const body = { title, subtitle, sortOrder: order, active };
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
        } else showError('Update failed');
    } else {
        if (!imageUrl) {
            showError('Please select an image');
            return;
        }
        const resp = await fetch(getApiUrl(API_CONFIG.endpoints.banners), {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ imageUrl, title, subtitle, sortOrder: order, active })
        });
        if (resp.ok) {
            showSuccess('Banner added');
            closeBannerModal();
            loadBanners();
        } else showError('Create failed');
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

// ========== LIVE TRACKING ==========

let map = null;
let markers = [];

function initMaps() {
    // Initialize map for live tracking
    if (document.getElementById('map')) {
        map = new google.maps.Map(document.getElementById('map'), {
            zoom: 10,
            center: { lat: 28.6139, lng: 77.2090 } // Default to Delhi, update as needed
        });
    }
    
    // Initialize map for active jobs
    if (document.getElementById('jobs-map')) {
        window.jobsMap = new google.maps.Map(document.getElementById('jobs-map'), {
            zoom: 10,
            center: { lat: 28.6139, lng: 77.2090 }
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
