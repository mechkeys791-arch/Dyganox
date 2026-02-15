// Global state
let allMechanics = [];
let allRequests = [];
let analyticsData = {};
let requestsChart = null;
let serviceTypeChart = null;

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    initializeNavigation();
    loadDashboard();
    setupModal();
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
        'pending': 'Pending Approvals',
        'requests': 'Service Requests',
        'tracking': 'Request Tracking',
        'analytics': 'Detailed Analytics',
        'users': 'User Management',
        'live-tracking': 'Live Tracking',
        'active-jobs': 'Active Jobs'
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
        tbody.innerHTML = '<tr><td colspan="12" class="loading">No mechanics found</td></tr>';
        return;
    }
    
    tbody.innerHTML = mechanics.map(mechanic => `
        <tr>
            <td>${mechanic.id}</td>
            <td><strong>${mechanic.name || 'N/A'}</strong></td>
            <td>${mechanic.email || 'N/A'}</td>
            <td>${mechanic.phone || 'N/A'}</td>
            <td>${mechanic.specialty || 'N/A'}</td>
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
        tbody.innerHTML = '<tr><td colspan="8" class="loading">No pending approvals</td></tr>';
        return;
    }
    
    tbody.innerHTML = mechanics.map(mechanic => `
        <tr>
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

// Service Requests
async function loadRequests() {
    try {
        const response = await fetch(getApiUrl(API_CONFIG.endpoints.requests));
        allRequests = await response.json();
        displayRequests(allRequests);
    } catch (error) {
        console.error('Error loading requests:', error);
        showError('Failed to load service requests');
    }
}

function displayRequests(requests) {
    const tbody = document.getElementById('requests-table-body');
    if (requests.length === 0) {
        tbody.innerHTML = '<tr><td colspan="8" class="loading">No requests found</td></tr>';
        return;
    }
    
    tbody.innerHTML = requests.map(request => {
        const requestTime = request.requestTime ? new Date(request.requestTime).toLocaleString() : 'N/A';
        const responseTime = request.responseTime ? new Date(request.responseTime).toLocaleString() : 'N/A';
        
        return `
            <tr>
                <td>${request.id}</td>
                <td><strong>${request.customerName || 'N/A'}</strong><br><small>${request.customerEmail || ''}</small></td>
                <td>${request.serviceType || 'N/A'}</td>
                <td>${request.mechanicId || 'N/A'}</td>
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

function displayAnalytics() {
    const data = analyticsData;
    
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
    const closeBtn = document.querySelector('.close');
    
    closeBtn.onclick = function() {
        modal.style.display = 'none';
    };
    
    window.onclick = function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
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
        tbody.innerHTML = '<tr><td colspan="7" class="loading">No users found</td></tr>';
        return;
    }
    
    tbody.innerHTML = users.map(user => `
        <tr>
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
        
        const content = document.getElementById('mechanic-performance-content');
        const mechanic = profile.mechanic;
        const documents = mechanic.documentUrls ? JSON.parse(mechanic.documentUrls) : [];
        
        content.innerHTML = `
            <div class="analytics-content">
                <div class="analytics-item">
                    <label>Name:</label>
                    <value>${mechanic.name || 'N/A'}</value>
                </div>
                <div class="analytics-item">
                    <label>Email:</label>
                    <value>${mechanic.email || 'N/A'}</value>
                </div>
                <div class="analytics-item">
                    <label>Phone:</label>
                    <value>${mechanic.phone || 'N/A'}</value>
                </div>
                <div class="analytics-item">
                    <label>Specialty:</label>
                    <value>${mechanic.specialty || 'N/A'}</value>
                </div>
                <div class="analytics-item">
                    <label>Experience:</label>
                    <value>${mechanic.experience || 'N/A'}</value>
                </div>
                <div class="analytics-item">
                    <label>Total Requests:</label>
                    <value>${profile.totalRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Completed:</label>
                    <value>${profile.completedRequests || 0}</value>
                </div>
                <div class="analytics-item">
                    <label>Pending:</label>
                    <value>${profile.pendingRequests || 0}</value>
                </div>
                <div style="margin-top: 20px;">
                    <h4>Documents</h4>
                    ${documents.length === 0 ? '<p>No documents uploaded</p>' : `
                        <div style="display: flex; flex-direction: column; gap: 8px;">
                            ${documents.map((doc, idx) => `
                                <a href="${doc}" target="_blank" style="color: var(--primary-color);">
                                    Document ${idx + 1} <i class="fas fa-external-link-alt"></i>
                                </a>
                            `).join('')}
                        </div>
                    `}
                    <button class="btn-action btn-view" onclick="uploadDocuments(${id})" style="margin-top: 12px;">
                        Upload Documents
                    </button>
                </div>
            </div>
        `;
        
        document.getElementById('mechanic-modal').style.display = 'block';
    } catch (error) {
        console.error('Error loading mechanic profile:', error);
        showError('Failed to load mechanic profile');
    }
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
    const urls = prompt('Enter document URLs (comma-separated):');
    if (urls) {
        const urlArray = urls.split(',').map(u => u.trim()).filter(u => u);
        updateMechanicDocuments(id, JSON.stringify(urlArray));
    }
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
    // Simple notification - you can enhance this with a toast library
    alert(message);
}
