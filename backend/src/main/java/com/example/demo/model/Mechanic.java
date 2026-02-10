package com.example.demo.model;

import jakarta.persistence.*;

@Entity
@Table(name = "mechanics")
public class Mechanic {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email;
    private String phone;
    private String specialty;
    private String experience;
    private boolean nightTimeAvailable;
    private String latitude;
    private String longitude;
    private String status = "Available"; // Available, Busy, Offline

    public Mechanic() {}

    public Mechanic(String name, String email, String phone, String specialty, String experience, boolean nightTimeAvailable, String latitude, String longitude) {
        this.name = name;
        this.email = email;
        this.phone = phone;
        this.specialty = specialty;
        this.experience = experience;
        this.nightTimeAvailable = nightTimeAvailable;
        this.latitude = latitude;
        this.longitude = longitude;
        this.status = "Available"; // Default status
    }

    // Getters & Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getSpecialty() { return specialty; }
    public void setSpecialty(String specialty) { this.specialty = specialty; }

    public String getExperience() { return experience; }
    public void setExperience(String experience) { this.experience = experience; }

    public boolean isNightTimeAvailable() { return nightTimeAvailable; }
    public void setNightTimeAvailable(boolean nightTimeAvailable) { this.nightTimeAvailable = nightTimeAvailable; }

    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }

    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    @Override
    public String toString() {
        return "Mechanic{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", phone='" + phone + '\'' +
                ", specialty='" + specialty + '\'' +
                ", experience='" + experience + '\'' +
                ", nightTimeAvailable=" + nightTimeAvailable +
                ", latitude='" + latitude + '\'' +
                ", longitude='" + longitude + '\'' +
                ", status='" + status + '\'' +
                '}';
    }
}
