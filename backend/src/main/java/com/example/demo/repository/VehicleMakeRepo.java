package com.example.demo.repository;

import com.example.demo.model.VehicleMake;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VehicleMakeRepo extends JpaRepository<VehicleMake, Long> {
    List<VehicleMake> findByTypeOrderByNameAsc(String type);
}
