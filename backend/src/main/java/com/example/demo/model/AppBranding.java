package com.example.demo.model;

import jakarta.persistence.*;

/**
 * App branding: logo (transparent PNG), optional splash animation, welcome title (e.g. "Welcome to ProMech").
 * Used on splash, user type selection, login, signup, mechanic screens.
 */
@Entity
@Table(name = "app_branding")
public class AppBranding {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Transparent app logo URL (PNG). Shown in header/splash instead of car icon. */
    @Column(name = "app_logo_url", length = 1000)
    private String appLogoUrl;

    /** Optional splash animation: Lottie (.json), GIF, or video (.mp4). */
    @Column(name = "splash_media_url", length = 1000)
    private String splashMediaUrl;

    /** lottie | gif | video */
    @Column(name = "splash_media_type", length = 20)
    private String splashMediaType;

    /** e.g. "Welcome to ProMech" */
    @Column(name = "welcome_title", length = 200)
    private String welcomeTitle;

    /** Optional GIF or video URL for the "I'm a User / I'm a Mechanic" welcome screen. */
    @Column(name = "welcome_page_media_url", length = 1000)
    private String welcomePageMediaUrl;

    /** gif | video */
    @Column(name = "welcome_page_media_type", length = 20)
    private String welcomePageMediaType;

    /** Optional GIF that auto-plays after the welcome page video ends. */
    @Column(name = "welcome_page_gif_url", length = 1000)
    private String welcomePageGifUrl;

    /** Custom loading animation (e.g. car going) – Lottie or GIF. Shown when page or image is loading. */
    @Column(name = "loading_media_url", length = 1000)
    private String loadingMediaUrl;

    /** lottie | gif */
    @Column(name = "loading_media_type", length = 20)
    private String loadingMediaType;

    /** Custom marker icon URL for "See nearest mechanic" map pins (admin upload). */
    @Column(name = "nearest_mechanic_marker_icon_url", length = 1000)
    private String nearestMechanicMarkerIconUrl;

    /** Custom marker icon URL for user's location on "See nearest mechanic" map (admin upload). */
    @Column(name = "user_location_marker_icon_url", length = 1000)
    private String userLocationMarkerIconUrl;

    /** Header/hero image URL for Car Services page (admin upload). */
    @Column(name = "car_service_image_url", length = 1000)
    private String carServiceImageUrl;

    /** Header/hero image URL for Bike Services page (admin upload). */
    @Column(name = "bike_service_image_url", length = 1000)
    private String bikeServiceImageUrl;

    /** Quick service icon URLs (admin upload). Key = service name e.g. Night Service, Towing. */
    @Column(name = "quick_service_night_service_icon_url", length = 1000)
    private String quickServiceNightServiceIconUrl;
    @Column(name = "quick_service_towing_icon_url", length = 1000)
    private String quickServiceTowingIconUrl;
    @Column(name = "quick_service_fuel_refill_icon_url", length = 1000)
    private String quickServiceFuelRefillIconUrl;
    @Column(name = "quick_service_ev_charging_icon_url", length = 1000)
    private String quickServiceEvChargingIconUrl;
    @Column(name = "quick_service_tyre_care_icon_url", length = 1000)
    private String quickServiceTyreCareIconUrl;
    @Column(name = "quick_service_minor_repair_icon_url", length = 1000)
    private String quickServiceMinorRepairIconUrl;
    @Column(name = "quick_service_battery_jump_icon_url", length = 1000)
    private String quickServiceBatteryJumpIconUrl;

    /** JSON map: problem id -> S3 icon URL for Book Mechanic "What's the problem?" e.g. {"tyre_puncture":"https://..."} */
    @Column(name = "problem_category_icons_json", length = 3000)
    private String problemCategoryIconsJson;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getAppLogoUrl() { return appLogoUrl; }
    public void setAppLogoUrl(String appLogoUrl) { this.appLogoUrl = appLogoUrl; }
    public String getSplashMediaUrl() { return splashMediaUrl; }
    public void setSplashMediaUrl(String splashMediaUrl) { this.splashMediaUrl = splashMediaUrl; }
    public String getSplashMediaType() { return splashMediaType; }
    public void setSplashMediaType(String splashMediaType) { this.splashMediaType = splashMediaType; }
    public String getWelcomeTitle() { return welcomeTitle; }
    public void setWelcomeTitle(String welcomeTitle) { this.welcomeTitle = welcomeTitle; }
    public String getWelcomePageMediaUrl() { return welcomePageMediaUrl; }
    public void setWelcomePageMediaUrl(String welcomePageMediaUrl) { this.welcomePageMediaUrl = welcomePageMediaUrl; }
    public String getWelcomePageMediaType() { return welcomePageMediaType; }
    public void setWelcomePageMediaType(String welcomePageMediaType) { this.welcomePageMediaType = welcomePageMediaType; }
    public String getWelcomePageGifUrl() { return welcomePageGifUrl; }
    public void setWelcomePageGifUrl(String welcomePageGifUrl) { this.welcomePageGifUrl = welcomePageGifUrl; }
    public String getLoadingMediaUrl() { return loadingMediaUrl; }
    public void setLoadingMediaUrl(String loadingMediaUrl) { this.loadingMediaUrl = loadingMediaUrl; }
    public String getLoadingMediaType() { return loadingMediaType; }
    public void setLoadingMediaType(String loadingMediaType) { this.loadingMediaType = loadingMediaType; }
    public String getNearestMechanicMarkerIconUrl() { return nearestMechanicMarkerIconUrl; }
    public void setNearestMechanicMarkerIconUrl(String nearestMechanicMarkerIconUrl) { this.nearestMechanicMarkerIconUrl = nearestMechanicMarkerIconUrl; }
    public String getUserLocationMarkerIconUrl() { return userLocationMarkerIconUrl; }
    public void setUserLocationMarkerIconUrl(String userLocationMarkerIconUrl) { this.userLocationMarkerIconUrl = userLocationMarkerIconUrl; }
    public String getCarServiceImageUrl() { return carServiceImageUrl; }
    public void setCarServiceImageUrl(String carServiceImageUrl) { this.carServiceImageUrl = carServiceImageUrl; }
    public String getBikeServiceImageUrl() { return bikeServiceImageUrl; }
    public void setBikeServiceImageUrl(String bikeServiceImageUrl) { this.bikeServiceImageUrl = bikeServiceImageUrl; }
    public String getQuickServiceNightServiceIconUrl() { return quickServiceNightServiceIconUrl; }
    public void setQuickServiceNightServiceIconUrl(String v) { this.quickServiceNightServiceIconUrl = v; }
    public String getQuickServiceTowingIconUrl() { return quickServiceTowingIconUrl; }
    public void setQuickServiceTowingIconUrl(String v) { this.quickServiceTowingIconUrl = v; }
    public String getQuickServiceFuelRefillIconUrl() { return quickServiceFuelRefillIconUrl; }
    public void setQuickServiceFuelRefillIconUrl(String v) { this.quickServiceFuelRefillIconUrl = v; }
    public String getQuickServiceEvChargingIconUrl() { return quickServiceEvChargingIconUrl; }
    public void setQuickServiceEvChargingIconUrl(String v) { this.quickServiceEvChargingIconUrl = v; }
    public String getQuickServiceTyreCareIconUrl() { return quickServiceTyreCareIconUrl; }
    public void setQuickServiceTyreCareIconUrl(String v) { this.quickServiceTyreCareIconUrl = v; }
    public String getQuickServiceMinorRepairIconUrl() { return quickServiceMinorRepairIconUrl; }
    public void setQuickServiceMinorRepairIconUrl(String v) { this.quickServiceMinorRepairIconUrl = v; }
    public String getQuickServiceBatteryJumpIconUrl() { return quickServiceBatteryJumpIconUrl; }
    public void setQuickServiceBatteryJumpIconUrl(String v) { this.quickServiceBatteryJumpIconUrl = v; }
    public String getProblemCategoryIconsJson() { return problemCategoryIconsJson; }
    public void setProblemCategoryIconsJson(String problemCategoryIconsJson) { this.problemCategoryIconsJson = problemCategoryIconsJson; }
}
