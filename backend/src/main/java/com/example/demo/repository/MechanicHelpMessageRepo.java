package com.example.demo.repository;

import com.example.demo.model.MechanicHelpMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface MechanicHelpMessageRepo extends JpaRepository<MechanicHelpMessage, Long> {
    List<MechanicHelpMessage> findByMechanicEmailIgnoreCaseOrderByCreatedAtAsc(String mechanicEmail);
}
