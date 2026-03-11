package com.example.demo.model;

import jakarta.persistence.*;

/**
 * A pin shown on "See nearest mechanic" map only. No name/email/phone – not a mechanic profile.
 * Partners who login are in the mechanics table. These are just service locations with a custom icon from admin.
 */
@Entity
@Table(name = "nearest_mechanic_locations")
public class NearestMechanicLocation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 50)
    private String latitude;

    @Column(nullable = false, length = 50)
    private String longitude;

    public NearestMechanicLocation() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }
    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }
}
