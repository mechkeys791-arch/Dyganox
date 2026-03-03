package com.example.demo.repository;

import com.example.demo.model.AuthBackgroundVideo;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AuthBackgroundVideoRepo extends JpaRepository<AuthBackgroundVideo, Long> {
    Optional<AuthBackgroundVideo> findTop1ByOrderByIdDesc();
}
