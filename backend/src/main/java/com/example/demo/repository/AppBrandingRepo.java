package com.example.demo.repository;

import com.example.demo.model.AppBranding;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AppBrandingRepo extends JpaRepository<AppBranding, Long> {
    Optional<AppBranding> findTop1ByOrderByIdDesc();
}
