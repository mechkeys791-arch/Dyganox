// API Configuration
const API_CONFIG = {
    // Update this with your backend URL
    baseUrl: 'http://34.228.113.212:8081', // Change to your EC2 IP or localhost:8081 for local

    endpoints: {
        mechanics: '/api/admin/mechanics',
        createMechanic: '/api/admin/mechanics/create',
        uploadNearestMechanicMarkerIcon: '/api/upload/nearest-mechanic-marker-icon',
        uploadUserLocationMarkerIcon: '/api/upload/user-location-marker-icon',
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
        uploadBanner: '/api/upload/banner',
        poster: '/api/admin/poster',
        appVersion: '/api/admin/app-version',
        authVideo: '/api/admin/auth-video',
        uploadAuthVideo: '/api/upload/auth-video',
        homeHeroMedia: '/api/admin/home-hero-media',
        uploadHomeHeroMedia: '/api/upload/home-hero-media',
        appBranding: '/api/admin/app-branding',
        uploadAppLogo: '/api/upload/app-logo',
        uploadSplashMedia: '/api/upload/splash-media',
        uploadWelcomePageMedia: '/api/upload/welcome-page-media',
        uploadCarServiceImage: '/api/upload/car-service-image',
        uploadBikeServiceImage: '/api/upload/bike-service-image',
        uploadQuickServiceIcon: '/api/upload/quick-service-icon'
    }
};

// Helper function to get full URL
function getApiUrl(endpoint) {
    return API_CONFIG.baseUrl + endpoint;
}
