package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Single row: app version check. Admin sets latest/min version and update message.
 */
@Entity
@Table(name = "app_version_config")
public class AppVersionConfig {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Current store version e.g. 1.2.0 */
    private String latestVersion;
    /** Minimum required version; if user's version < this, show update. */
    private String minRequiredVersion;
    private String updateTitle;
    @Column(length = 2000)
    private String updateMessage;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getLatestVersion() { return latestVersion; }
    public void setLatestVersion(String latestVersion) { this.latestVersion = latestVersion; }
    public String getMinRequiredVersion() { return minRequiredVersion; }
    public void setMinRequiredVersion(String minRequiredVersion) { this.minRequiredVersion = minRequiredVersion; }
    public String getUpdateTitle() { return updateTitle; }
    public void setUpdateTitle(String updateTitle) { this.updateTitle = updateTitle; }
    public String getUpdateMessage() { return updateMessage; }
    public void setUpdateMessage(String updateMessage) { this.updateMessage = updateMessage; }
}
