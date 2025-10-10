package com.example.demo.repository;

import com.example.demo.model.EVProvider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface EVProviderRepo extends JpaRepository<EVProvider, Long> {
}

