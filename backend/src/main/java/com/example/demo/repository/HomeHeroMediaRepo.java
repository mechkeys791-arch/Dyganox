package com.example.demo.repository;

import com.example.demo.model.HomeHeroMedia;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface HomeHeroMediaRepo extends JpaRepository<HomeHeroMedia, Long> {
    Optional<HomeHeroMedia> findTop1ByOrderByIdDesc();
}
