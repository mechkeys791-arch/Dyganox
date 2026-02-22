package com.example.demo.model;

import jakarta.persistence.*;

/**
 * Vehicle make (brand) - e.g. Maruti Suzuki, Hyundai, Honda. Type CAR or BIKE.
 */
@Entity
@Table(name = "vehicle_makes")
public class VehicleMake {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;       // e.g. "Maruti Suzuki"
    private String type;       // CAR, BIKE
    @Column(length = 500)
    private String imageUrl;  // logo or representative image

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }
}
