package com.example.demo.repository;

import com.example.demo.model.VehicleModel;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VehicleModelRepo extends JpaRepository<VehicleModel, Long> {
    List<VehicleModel> findByMakeIdOrderByNameAsc(Long makeId);
    void deleteByMakeId(Long makeId);
}
