package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Vehicle model under a make - e.g. Swift, Alto, Creta.
 */
@Entity
@Table(name = "vehicle_models")
public class VehicleModel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long makeId;
    private String name;       // e.g. "Swift", "Alto"
    @Column(length = 500)
    private String imageUrl;   // photo of this model

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getMakeId() { return makeId; }
    public void setMakeId(Long makeId) { this.makeId = makeId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
}
