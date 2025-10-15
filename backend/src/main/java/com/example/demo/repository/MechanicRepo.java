package com.example.demo.repository;

import com.example.demo.model.Mechanic;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MechanicRepo extends JpaRepository<Mechanic, Long> {
    // Custom query methods can be added here if needed
}
