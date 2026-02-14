package com.example.demo.repository;

import com.example.demo.model.UserAddress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserAddressRepo extends JpaRepository<UserAddress, Long> {
    List<UserAddress> findByUserEmailOrderByCreatedAtDesc(String userEmail);
    Optional<UserAddress> findByUserEmailAndIsSelected(String userEmail, Boolean isSelected);
    Optional<UserAddress> findByUserEmailAndId(String userEmail, Long id);
}
