package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Single active marketing poster shown when user opens the app (full-screen overlay until dismissed).
 */
@Entity
@Table(name = "marketing_posters")
public class MarketingPoster {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(length = 500)
    private String imageUrl;

    @Column(length = 500)
    private String linkUrl;  // optional

    private boolean active = true;

    /** Optional: show this poster only to users in this city (e.g. Moodbidri). Empty = any. */
    @Column(name = "target_city", length = 100)
    private String targetCity;

    /** Optional: show this poster only to users in this state (e.g. Karnataka). Empty = any. */
    @Column(name = "target_state", length = 100)
    private String targetState;

    /** Optional: center latitude for area targeting (circle). If set with targetLng and targetRadiusKm, poster is shown only to users within radius. */
    @Column(name = "target_lat")
    private Double targetLat;

    /** Optional: center longitude for area targeting. */
    @Column(name = "target_lng")
    private Double targetLng;

    /** Optional: radius in km. User must be within this distance of (targetLat, targetLng) to see poster. */
    @Column(name = "target_radius_km")
    private Double targetRadiusKm;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public String getLinkUrl() { return linkUrl; }
    public void setLinkUrl(String linkUrl) { this.linkUrl = linkUrl; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
    public String getTargetCity() { return targetCity; }
    public void setTargetCity(String targetCity) { this.targetCity = targetCity; }
    public String getTargetState() { return targetState; }
    public void setTargetState(String targetState) { this.targetState = targetState; }
    public Double getTargetLat() { return targetLat; }
    public void setTargetLat(Double targetLat) { this.targetLat = targetLat; }
    public Double getTargetLng() { return targetLng; }
    public void setTargetLng(Double targetLng) { this.targetLng = targetLng; }
    public Double getTargetRadiusKm() { return targetRadiusKm; }
    public void setTargetRadiusKm(Double targetRadiusKm) { this.targetRadiusKm = targetRadiusKm; }
}
