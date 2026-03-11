package com.example.demo.repository;

import com.example.demo.model.NearestMechanicLocation;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NearestMechanicLocationRepo extends JpaRepository<NearestMechanicLocation, Long> {
    List<NearestMechanicLocation> findAllByOrderByIdAsc();
}
