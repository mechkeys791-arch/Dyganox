package com.example.demo.model;

import jakarta.persistence.*;
import java.time.Instant;

/**
 * Promotional strip ads (Night Service, etc.). Platform-owned or mechanic monthly promos.
 */
@Entity
@Table(name = "service_ads")
public class ServiceAd {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** NIGHT_SERVICE, ... */
    @Column(nullable = false, length = 40)
    private String placement = "NIGHT_SERVICE";

    /** PLATFORM or MECHANIC */
    @Column(nullable = false, length = 20)
    private String source = "PLATFORM";

    /** Set when source = MECHANIC */
    private Long mechanicId;

    @Column(length = 200)
    private String title;

    @Column(length = 400)
    private String subtitle;

    /** Shown on strip e.g. "{name} is ready — what's the problem?" */
    @Column(length = 500)
    private String headline;

    @Column(length = 2000, nullable = false)
    private String mediaUrl;

    /** IMAGE or VIDEO */
    @Column(nullable = false, length = 20)
    private String mediaType = "IMAGE";

    private String latitude;
    private String longitude;

    /** Geo targeting radius km; 0 = use default 50 for mechanic, unlimited for platform without coords */
    private Double radiusKm = 25.0;

    private boolean active = true;

    private Integer sortOrder = 0;

    private Instant startsAt;
    private Instant endsAt;

    /** YYYY-MM for mechanic promos (max one active row per mechanic per month) */
    @Column(length = 7)
    private String promoYearMonth;

    private Instant createdAt = Instant.now();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getPlacement() { return placement; }
    public void setPlacement(String placement) { this.placement = placement; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public Long getMechanicId() { return mechanicId; }
    public void setMechanicId(Long mechanicId) { this.mechanicId = mechanicId; }
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }
    public String getSubtitle() { return subtitle; }
    public void setSubtitle(String subtitle) { this.subtitle = subtitle; }
    public String getHeadline() { return headline; }
    public void setHeadline(String headline) { this.headline = headline; }
    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }
    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }
    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }
    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }
    public Double getRadiusKm() { return radiusKm; }
    public void setRadiusKm(Double radiusKm) { this.radiusKm = radiusKm; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
    public Instant getStartsAt() { return startsAt; }
    public void setStartsAt(Instant startsAt) { this.startsAt = startsAt; }
    public Instant getEndsAt() { return endsAt; }
    public void setEndsAt(Instant endsAt) { this.endsAt = endsAt; }
    public String getPromoYearMonth() { return promoYearMonth; }
    public void setPromoYearMonth(String promoYearMonth) { this.promoYearMonth = promoYearMonth; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
