package com.example.demo.controller;

import com.example.demo.model.UserVehicle;
import com.example.demo.model.VehicleMake;
import com.example.demo.model.VehicleModel;
import com.example.demo.repository.UserVehicleRepo;
import com.example.demo.repository.VehicleMakeRepo;
import com.example.demo.repository.VehicleModelRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/vehicle")
@CrossOrigin(origins = "*")
public class VehicleController {

    @Autowired
    private VehicleMakeRepo vehicleMakeRepo;

    @Autowired
    private VehicleModelRepo vehicleModelRepo;

    @Autowired
    private UserVehicleRepo userVehicleRepo;

    /** GET /api/vehicle/makes?type=CAR or type=BIKE */
    @GetMapping("/makes")
    public ResponseEntity<List<VehicleMake>> getMakes(@RequestParam String type) {
        if (type == null || type.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        String t = type.toUpperCase();
        if (!"CAR".equals(t) && !"BIKE".equals(t)) {
            return ResponseEntity.badRequest().build();
        }
        List<VehicleMake> list = vehicleMakeRepo.findByTypeOrderByNameAsc(t);
        return ResponseEntity.ok(list);
    }

    /** GET /api/vehicle/models?makeId=1 */
    @GetMapping("/models")
    public ResponseEntity<List<VehicleModel>> getModels(@RequestParam Long makeId) {
        if (makeId == null) {
            return ResponseEntity.badRequest().build();
        }
        List<VehicleModel> list = vehicleModelRepo.findByMakeIdOrderByNameAsc(makeId);
        return ResponseEntity.ok(list);
    }

    /** GET /api/vehicle/my?email=user@example.com */
    @GetMapping("/my")
    public ResponseEntity<List<UserVehicle>> getMyVehicles(@RequestParam String email) {
        if (email == null || email.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        List<UserVehicle> list = userVehicleRepo.findByUserEmailIgnoreCaseOrderByCreatedAtDesc(email);
        return ResponseEntity.ok(list);
    }

    /** Indian plate format: 2 letters (state) + 2 digits (district) + 2 letters + 1-4 digits. Spaces optional. */
    private static final Pattern PLATE_PATTERN = Pattern.compile("^[A-Za-z]{2}\\s*\\d{1,2}\\s*[A-Za-z]{1,3}\\s*\\d{1,4}$");

    private boolean isValidPlate(String plate) {
        if (plate == null || plate.isBlank()) return false;
        return PLATE_PATTERN.matcher(plate.trim()).matches();
    }

    /** POST /api/vehicle/my - create user vehicle */
    @PostMapping("/my")
    public ResponseEntity<UserVehicle> createMyVehicle(@RequestBody UserVehicle body) {
        if (body.getUserEmail() == null || body.getUserEmail().isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        if (body.getType() == null || body.getMakeId() == null || body.getModelId() == null
                || body.getMakeName() == null || body.getModelName() == null) {
            return ResponseEntity.badRequest().build();
        }
        String plate = body.getPlateNumber() != null ? body.getPlateNumber().trim() : null;
        if (plate == null || plate.isEmpty()) {
            return ResponseEntity.badRequest().build(); // plate is required
        }
        if (!isValidPlate(plate)) {
            return ResponseEntity.badRequest().build(); // invalid format
        }
        body.setPlateNumber(plate);
        String fuelType = body.getFuelType() != null ? body.getFuelType().trim() : null;
        if (fuelType == null || fuelType.isEmpty()) {
            return ResponseEntity.badRequest().build(); // fuel type is required
        }
        body.setFuelType(fuelType);
        // If this is set default, unset others
        if (body.isDefault()) {
            userVehicleRepo.findByUserEmailIgnoreCaseOrderByCreatedAtDesc(body.getUserEmail())
                    .forEach(v -> { v.setDefault(false); userVehicleRepo.save(v); });
        }
        // If first vehicle, make it default
        List<UserVehicle> existing = userVehicleRepo.findByUserEmailIgnoreCaseOrderByCreatedAtDesc(body.getUserEmail());
        if (existing.isEmpty()) {
            body.setDefault(true);
        }
        UserVehicle saved = userVehicleRepo.save(body);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    /** PUT /api/vehicle/my/{id} - update user vehicle */
    @PutMapping("/my/{id}")
    public ResponseEntity<UserVehicle> updateMyVehicle(@PathVariable Long id, @RequestBody UserVehicle body) {
        Optional<UserVehicle> opt = userVehicleRepo.findById(id);
        if (opt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        UserVehicle v = opt.get();
        if (body.getPlateNumber() != null) {
            String plate = body.getPlateNumber().trim();
            if (!plate.isEmpty() && !isValidPlate(plate)) {
                return ResponseEntity.badRequest().build();
            }
            v.setPlateNumber(plate.isEmpty() ? v.getPlateNumber() : plate);
        }
        if (body.getYear() != null) v.setYear(body.getYear());
        if (body.getFuelType() != null) {
            String ft = body.getFuelType().trim();
            if (ft.isEmpty()) return ResponseEntity.badRequest().build();
            v.setFuelType(ft);
        }
        if (body.getPhotoUrl() != null) v.setPhotoUrl(body.getPhotoUrl());
        if (body.getModelImageUrl() != null) v.setModelImageUrl(body.getModelImageUrl());
        if (body.isDefault()) {
            userVehicleRepo.findByUserEmailIgnoreCaseOrderByCreatedAtDesc(v.getUserEmail())
                    .forEach(u -> { if (!u.getId().equals(id)) { u.setDefault(false); userVehicleRepo.save(u); } });
            v.setDefault(true);
        }
        UserVehicle saved = userVehicleRepo.save(v);
        return ResponseEntity.ok(saved);
    }

    /** DELETE /api/vehicle/my/{id} */
    @DeleteMapping("/my/{id}")
    public ResponseEntity<Void> deleteMyVehicle(@PathVariable Long id) {
        if (!userVehicleRepo.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        userVehicleRepo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    // ---------- Admin: add/delete catalog and set images ----------

    /** POST /api/vehicle/makes - add new make (brand). Body: { "name": "...", "type": "CAR"|"BIKE", "imageUrl": "..." optional } */
    @PostMapping("/makes")
    public ResponseEntity<VehicleMake> createMake(@RequestBody java.util.Map<String, String> body) {
        String name = body != null ? body.get("name") : null;
        String type = body != null ? body.get("type") : null;
        if (name == null || name.isBlank() || type == null || type.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        String t = type.toUpperCase();
        if (!"CAR".equals(t) && !"BIKE".equals(t)) {
            return ResponseEntity.badRequest().build();
        }
        VehicleMake m = new VehicleMake();
        m.setName(name.trim());
        m.setType(t);
        m.setImageUrl(body.get("imageUrl"));
        return ResponseEntity.status(HttpStatus.CREATED).body(vehicleMakeRepo.save(m));
    }

    /** DELETE /api/vehicle/makes/{id} - delete make and all its models */
    @DeleteMapping("/makes/{id}")
    public ResponseEntity<Void> deleteMake(@PathVariable Long id) {
        if (!vehicleMakeRepo.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        vehicleModelRepo.deleteByMakeId(id);
        vehicleMakeRepo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    /** POST /api/vehicle/models - add new model. Body: { "makeId": 1, "name": "...", "imageUrl": "..." optional } */
    @PostMapping("/models")
    public ResponseEntity<VehicleModel> createModel(@RequestBody java.util.Map<String, Object> body) {
        if (body == null) return ResponseEntity.badRequest().build();
        Object makeIdObj = body.get("makeId");
        String name = body.get("name") != null ? body.get("name").toString() : null;
        if (makeIdObj == null || name == null || name.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        Long makeId = makeIdObj instanceof Number ? ((Number) makeIdObj).longValue() : Long.parseLong(makeIdObj.toString());
        if (!vehicleMakeRepo.existsById(makeId)) {
            return ResponseEntity.badRequest().build();
        }
        VehicleModel m = new VehicleModel();
        m.setMakeId(makeId);
        m.setName(name.trim());
        if (body.get("imageUrl") != null) m.setImageUrl(body.get("imageUrl").toString());
        return ResponseEntity.status(HttpStatus.CREATED).body(vehicleModelRepo.save(m));
    }

    /** DELETE /api/vehicle/models/{id} - delete model */
    @DeleteMapping("/models/{id}")
    public ResponseEntity<Void> deleteModel(@PathVariable Long id) {
        if (!vehicleModelRepo.existsById(id)) {
            return ResponseEntity.notFound().build();
        }
        vehicleModelRepo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    /** PUT /api/vehicle/makes/{id}/image - set image URL for a make (brand). */
    @PutMapping("/makes/{id}/image")
    public ResponseEntity<VehicleMake> setMakeImage(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        String imageUrl = body != null ? body.get("imageUrl") : null;
        Optional<VehicleMake> opt = vehicleMakeRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        VehicleMake m = opt.get();
        m.setImageUrl(imageUrl);
        return ResponseEntity.ok(vehicleMakeRepo.save(m));
    }

    /** PUT /api/vehicle/models/{id}/image - set image URL for a model. Call this after you upload your image. */
    @PutMapping("/models/{id}/image")
    public ResponseEntity<VehicleModel> setModelImage(@PathVariable Long id, @RequestBody java.util.Map<String, String> body) {
        String imageUrl = body != null ? body.get("imageUrl") : null;
        Optional<VehicleModel> opt = vehicleModelRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        VehicleModel m = opt.get();
        m.setImageUrl(imageUrl);
        return ResponseEntity.ok(vehicleModelRepo.save(m));
    }
}
