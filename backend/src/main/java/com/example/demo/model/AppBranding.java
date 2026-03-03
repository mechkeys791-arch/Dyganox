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
}
