package com.example.demo.repository;

import com.example.demo.model.MechanicRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MechanicRequestRepo extends JpaRepository<MechanicRequest, Long> {
    List<MechanicRequest> findByMechanicIdAndStatus(Long mechanicId, String status);
    List<MechanicRequest> findByMechanicIdOrderByRequestTimeDesc(Long mechanicId);
    List<MechanicRequest> findByAcceptedMechanicIdOrderByRequestTimeDesc(Long mechanicId);
    List<MechanicRequest> findByCustomerEmailOrderByRequestTimeDesc(String customerEmail);
    List<MechanicRequest> findByCustomerPhoneOrderByRequestTimeDesc(String customerPhone);
    List<MechanicRequest> findByStatus(String status);
    List<MechanicRequest> findByStatusAndAcceptedMechanicIdIsNull(String status);

    @Query("SELECT r FROM MechanicRequest r WHERE r.mechanicId = :mechanicId OR r.acceptedMechanicId = :mechanicId ORDER BY r.requestTime DESC")
    List<MechanicRequest> findByMechanicIdOrAcceptedMechanicIdOrderByRequestTimeDesc(@Param("mechanicId") Long mechanicId);
}
