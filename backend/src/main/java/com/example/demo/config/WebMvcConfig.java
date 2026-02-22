package com.example.demo.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    private final DashboardAuditInterceptor dashboardAuditInterceptor;

    public WebMvcConfig(DashboardAuditInterceptor dashboardAuditInterceptor) {
        this.dashboardAuditInterceptor = dashboardAuditInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(dashboardAuditInterceptor).addPathPatterns("/api/admin/**");
    }
}
