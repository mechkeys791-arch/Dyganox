package com.example.demo.model;

import jakarta.persistence.*;

@Entity
@Table(name = "person")
public class Person {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String phone;
    private String address;
    private String chargerType;
    private String rate;
    private String availableHours;

    public Person() {}

    public Person(String name, String phone, String address, String chargerType, String rate, String availableHours) {
        this.name = name;
        this.phone = phone;
        this.address = address;
        this.chargerType = chargerType;
        this.rate = rate;
        this.availableHours = availableHours;
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
}
