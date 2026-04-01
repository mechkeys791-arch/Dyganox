package com.example.demo.repository;

import com.example.demo.model.ServiceAd;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ServiceAdRepo extends JpaRepository<ServiceAd, Long> {

    List<ServiceAd> findByPlacementAndActiveTrueOrderBySortOrderAscIdAsc(String placement);

    long countByMechanicIdAndPromoYearMonth(Long mechanicId, String promoYearMonth);

    java.util.Optional<ServiceAd> findFirstByMechanicIdAndPromoYearMonthOrderByIdDesc(Long mechanicId, String promoYearMonth);
}
