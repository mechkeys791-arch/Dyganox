package com.example.demo.repository;

import com.example.demo.model.UserVehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserVehicleRepo extends JpaRepository<UserVehicle, Long> {
    List<UserVehicle> findByUserEmailIgnoreCaseOrderByCreatedAtDesc(String userEmail);
    Optional<UserVehicle> findByUserEmailIgnoreCaseAndIsDefaultTrue(String userEmail);
}
