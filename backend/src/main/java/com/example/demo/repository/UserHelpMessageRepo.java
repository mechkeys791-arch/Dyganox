package com.example.demo.repository;

import com.example.demo.model.UserHelpMessage;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserHelpMessageRepo extends JpaRepository<UserHelpMessage, Long> {
    List<UserHelpMessage> findByUserEmailIgnoreCaseOrderByCreatedAtAsc(String userEmail);
}
