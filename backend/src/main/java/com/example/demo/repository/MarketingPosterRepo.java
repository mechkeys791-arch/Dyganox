package com.example.demo.repository;

import com.example.demo.model.MarketingPoster;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MarketingPosterRepo extends JpaRepository<MarketingPoster, Long> {
    Optional<MarketingPoster> findFirstByActiveTrue();
    Optional<MarketingPoster> findFirstByOrderByIdDesc();
    List<MarketingPoster> findAllByActiveTrueOrderByIdDesc();
}
