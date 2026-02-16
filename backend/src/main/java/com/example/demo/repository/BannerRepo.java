package com.example.demo.repository;

import com.example.demo.model.Banner;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BannerRepo extends JpaRepository<Banner, Long> {
    List<Banner> findByActiveTrueOrderBySortOrderAsc();
    List<Banner> findAllByOrderBySortOrderAsc();
}
