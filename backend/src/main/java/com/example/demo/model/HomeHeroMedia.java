package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Config for transparent hero graphic on homepage red header (Lottie or GIF). Admin uploads file, app overlays on gradient.
 */
@Entity
@Table(name = "home_hero_media")
public class HomeHeroMedia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** lottie | gif */
    @Column(name = "media_type", length = 20)
    private String mediaType;

    @Column(name = "media_url", length = 1000)
    private String mediaUrl;

    private boolean active = true;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getMediaType() { return mediaType; }
    public void setMediaType(String mediaType) { this.mediaType = mediaType; }
    public String getMediaUrl() { return mediaUrl; }
    public void setMediaUrl(String mediaUrl) { this.mediaUrl = mediaUrl; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
}
