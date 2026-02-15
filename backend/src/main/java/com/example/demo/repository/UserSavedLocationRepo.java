package com.example.demo.repository;

import com.example.demo.model.UserSavedLocation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserSavedLocationRepo extends JpaRepository<UserSavedLocation, Long> {
    List<UserSavedLocation> findByUserEmailOrderByCreatedAtDesc(String userEmail);
    Optional<UserSavedLocation> findByUserEmailAndId(String userEmail, Long id);
}
