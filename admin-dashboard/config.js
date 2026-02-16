// API Configuration
const API_CONFIG = {
    // Update this with your backend URL
    baseUrl: 'http://34.228.113.212:8081', // Change to your EC2 IP or localhost:8081 for local
    
    endpoints: {
        mechanics: '/api/admin/mechanics',
        pendingMechanics: '/api/admin/mechanics/pending',
        approveMechanic: '/api/admin/mechanics',
        rejectMechanic: '/api/admin/mechanics',
        requests: '/api/admin/requests',
        analytics: '/api/admin/analytics',
        tracking: '/api/admin/requests/tracking',
        mechanicPerformance: '/api/admin/mechanics',
        mechanicProfile: '/api/admin/mechanics',
        users: '/api/admin/users',
        mechanicLocations: '/api/admin/mechanics/locations',
        activeJobs: '/api/admin/jobs/active',
        registrationRequests: '/api/mechanic/registration-requests',
        banners: '/api/admin/banners',
        uploadBanner: '/api/upload/banner'
    }
};

// Helper function to get full URL
function getApiUrl(endpoint) {
    return API_CONFIG.baseUrl + endpoint;
}
