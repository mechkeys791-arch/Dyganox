package com.example.demo.repository;

import com.example.demo.model.MechanicRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MechanicRequestRepo extends JpaRepository<MechanicRequest, Long> {
    List<MechanicRequest> findByMechanicIdAndStatus(Long mechanicId, String status);
    List<MechanicRequest> findByMechanicIdOrderByRequestTimeDesc(Long mechanicId);
    List<MechanicRequest> findByCustomerEmailOrderByRequestTimeDesc(String customerEmail);
    List<MechanicRequest> findByCustomerPhoneOrderByRequestTimeDesc(String customerPhone);
    List<MechanicRequest> findByStatus(String status);
    List<MechanicRequest> findByAcceptedMechanicIdOrderByRequestTimeDesc(Long mechanicId);
    List<MechanicRequest> findByStatusAndAcceptedMechanicIdIsNull(String status);
}
