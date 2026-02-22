package com.example.demo.repository;

import com.example.demo.model.UserSupportPhotoPermission;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserSupportPhotoPermissionRepo extends JpaRepository<UserSupportPhotoPermission, Long> {
    Optional<UserSupportPhotoPermission> findByUserEmailIgnoreCase(String userEmail);
}
