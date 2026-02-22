package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Images shown in a specific section of the app (e.g. below "Our Services").
 * Not the same as the top carousel or the full-screen marketing poster.
 */
@Entity
@Table(name = "section_posters")
public class SectionPoster {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Section identifier, e.g. BELOW_SERVICES */
    @Column(name = "section_key", length = 64, nullable = false)
    private String sectionKey = "BELOW_SERVICES";

    @Column(length = 500)
    private String imageUrl;

    @Column(length = 500)
    private String linkUrl;

    private int sortOrder = 0;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getSectionKey() { return sectionKey; }
    public void setSectionKey(String sectionKey) { this.sectionKey = sectionKey; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
    public String getLinkUrl() { return linkUrl; }
    public void setLinkUrl(String linkUrl) { this.linkUrl = linkUrl; }
    public int getSortOrder() { return sortOrder; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
}
