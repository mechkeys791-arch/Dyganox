package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Single config for login/signup background video (S3 URL). Admin uploads MP4 and sets URL here.
 */
@Entity
@Table(name = "auth_background_video")
public class AuthBackgroundVideo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Public S3 URL of the MP4 video (e.g. https://bucket.s3.amazonaws.com/auth-video/xxx.mp4). */
    @Column(name = "video_url", length = 1000)
    private String videoUrl;

    private boolean active = true;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
}
