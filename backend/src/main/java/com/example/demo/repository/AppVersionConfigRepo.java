package com.example.demo.repository;

import com.example.demo.model.AppVersionConfig;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AppVersionConfigRepo extends JpaRepository<AppVersionConfig, Long> {
}
