package com.example.demo.config;

import com.example.demo.service.DashboardAuthService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
public class DashboardSeedRunner implements ApplicationRunner {

    private final DashboardAuthService dashboardAuthService;

    @Value("${dashboard.owner.password:}")
    private String ownerPassword;

    public DashboardSeedRunner(DashboardAuthService dashboardAuthService) {
        this.dashboardAuthService = dashboardAuthService;
    }

    @Override
    public void run(ApplicationArguments args) {
        dashboardAuthService.seedOwnerIfNeeded(ownerPassword);
    }
}
