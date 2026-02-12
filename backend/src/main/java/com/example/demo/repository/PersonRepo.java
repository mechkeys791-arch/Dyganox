package com.example.demo.repository;

import com.example.demo.model.Person;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface PersonRepo extends JpaRepository<Person, Long> {
    // Find user by email (for profile retrieval)
    Optional<Person> findByEmail(String email);
    
    // Check if email exists
    boolean existsByEmail(String email);
}
