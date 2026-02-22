package com.example.demo.repository;

import com.example.demo.model.SectionPoster;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SectionPosterRepo extends JpaRepository<SectionPoster, Long> {
    List<SectionPoster> findBySectionKeyOrderBySortOrderAsc(String sectionKey);
}
