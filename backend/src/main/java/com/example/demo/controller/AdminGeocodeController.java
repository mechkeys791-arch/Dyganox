package com.example.demo.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

/**
 * Resolve a place name to lat/lng for service-ad targeting (OpenStreetMap Nominatim).
 */
@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminGeocodeController {

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @GetMapping("/geocode")
    public ResponseEntity<?> geocode(@RequestParam("q") String q) {
        if (q == null || q.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Query required"));
        }
        try {
            URI uri = UriComponentsBuilder
                    .fromHttpUrl("https://nominatim.openstreetmap.org/search")
                    .queryParam("q", q.trim())
                    .queryParam("format", "json")
                    .queryParam("limit", "1")
                    .encode(StandardCharsets.UTF_8)
                    .build()
                    .toUri();

            HttpHeaders headers = new HttpHeaders();
            headers.set("User-Agent", "DyganoxAdmin/1.0 (service-ad geocoding)");
            headers.setAccept(List.of(MediaType.APPLICATION_JSON));
            HttpEntity<Void> entity = new HttpEntity<>(headers);

            ResponseEntity<String> resp = restTemplate.exchange(uri, HttpMethod.GET, entity, String.class);
            if (!resp.getStatusCode().is2xxSuccessful() || resp.getBody() == null) {
                return ResponseEntity.status(502).body(Map.of("error", "Geocoding failed"));
            }
            JsonNode arr = objectMapper.readTree(resp.getBody());
            if (!arr.isArray() || arr.isEmpty()) {
                return ResponseEntity.status(404).body(Map.of("error", "Place not found"));
            }
            JsonNode first = arr.get(0);
            String lat = first.get("lat").asText();
            String lon = first.get("lon").asText();
            String display = first.has("display_name") ? first.get("display_name").asText() : q.trim();
            return ResponseEntity.ok(Map.of(
                    "latitude", lat,
                    "longitude", lon,
                    "displayName", display
            ));
        } catch (Exception e) {
            String msg = e.getMessage() != null ? e.getMessage() : "Geocoding error";
            return ResponseEntity.status(502).body(Map.of("error", msg));
        }
    }
}
