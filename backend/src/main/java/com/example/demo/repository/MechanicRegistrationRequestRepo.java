package com.example.demo.repository;

import com.example.demo.model.MechanicRegistrationRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MechanicRegistrationRequestRepo extends JpaRepository<MechanicRegistrationRequest, Long> {
    List<MechanicRegistrationRequest> findByApprovalStatusOrderByCreatedAtDesc(String approvalStatus);
    List<MechanicRegistrationRequest> findByEmailOrderByCreatedAtDesc(String email);
    List<MechanicRegistrationRequest> findByEmailIgnoreCaseOrderByCreatedAtDesc(String email);
}
