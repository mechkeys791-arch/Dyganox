package com.example.demo.model;

import jakarta.persistence.*;

@Entity
@Table(name = "ev_providers")
public class EVProvider {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String phone;
    private String address;
    private String chargerType;
    private String rate;
    private String availableHours;
    private String latitude;
    private String longitude;

    public EVProvider() {}

    public EVProvider(String name, String phone, String address, String chargerType, String rate, String availableHours, String latitude, String longitude) {
        this.name = name;
        this.phone = phone;
        this.address = address;
        this.chargerType = chargerType;
        this.rate = rate;
        this.availableHours = availableHours;
        this.latitude = latitude;
        this.longitude = longitude;
    }

    // Getters & Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public String getChargerType() { return chargerType; }
    public void setChargerType(String chargerType) { this.chargerType = chargerType; }

    public String getRate() { return rate; }
    public void setRate(String rate) { this.rate = rate; }

    public String getAvailableHours() { return availableHours; }
    public void setAvailableHours(String availableHours) { this.availableHours = availableHours; }

    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }

    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }

    @Override
    public String toString() {
        return "EVProvider{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", phone='" + phone + '\'' +
                ", address='" + address + '\'' +
                ", chargerType='" + chargerType + '\'' +
                ", rate='" + rate + '\'' +
                ", availableHours='" + availableHours + '\'' +
                ", latitude='" + latitude + '\'' +
                ", longitude='" + longitude + '\'' +
                '}';
    }
}

