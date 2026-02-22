package com.example.demo.config;

import com.example.demo.model.VehicleMake;
import com.example.demo.model.VehicleModel;
import com.example.demo.repository.VehicleMakeRepo;
import com.example.demo.repository.VehicleModelRepo;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Seeds Indian car and bike makes/models on first run. Uses placeholder image URLs;
 * replace with real CDN URLs later.
 */
@Component
@Order(100)
public class VehicleSeedRunner implements ApplicationRunner {

    private static final String PLACEHOLDER = "https://via.placeholder.com/200?text=";

    private final VehicleMakeRepo vehicleMakeRepo;
    private final VehicleModelRepo vehicleModelRepo;

    public VehicleSeedRunner(VehicleMakeRepo vehicleMakeRepo, VehicleModelRepo vehicleModelRepo) {
        this.vehicleMakeRepo = vehicleMakeRepo;
        this.vehicleModelRepo = vehicleModelRepo;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (vehicleMakeRepo.count() > 0) return;
        seedCars();
        seedBikes();
    }

    private void seedCars() {
        List<Object[]> cars = List.of(
            new Object[]{"Maruti Suzuki", "Swift", "Dzire", "Alto", "Baleno", "Wagon R", "Ertiga", "Brezza", "Celerio", "Eeco", "S-Presso", "Ignis", "Ciaz", "XL6", "Fronx", "Invicto", "Grand Vitara"},
            new Object[]{"Hyundai", "i20", "i10", "Creta", "Venue", "Verna", "Tucson", "Santro", "Aura", "Alcazar", "Exter", "Kona"},
            new Object[]{"Tata", "Nexon", "Punch", "Harrier", "Safari", "Tiago", "Tigor", "Altroz", "Curvv", "Punch EV"},
            new Object[]{"Mahindra", "XUV700", "Scorpio", "Thar", "XUV300", "Bolero", "Marazzo", "XUV400", "Scorpio N"},
            new Object[]{"Toyota", "Innova", "Fortuner", "Glanza", "Urban Cruiser", "Hyryder", "Innova Hycross", "Rumion", "Hilux"},
            new Object[]{"Kia", "Seltos", "Sonet", "Carens", "EV6", "Carnival"},
            new Object[]{"Honda", "City", "Amaze", "Jazz", "WR-V", "Elevate"},
            new Object[]{"MG", "Hector", "ZS EV", "Gloster", "Hector Plus", "Comet"},
            new Object[]{"Skoda", "Slavia", "Kushaq", "Kodiaq", "Superb", "Octavia"},
            new Object[]{"Volkswagen", "Taigun", "Virtus", "Tiguan", "Polo", "T-Roc"},
            new Object[]{"Renault", "Duster", "Kiger", "Kwid", "Triber", "Kardian"},
            new Object[]{"Citroen", "C3", "C3 Aircross", "eC3", "C5 Aircross"},
            new Object[]{"Jeep", "Compass", "Meridian", "Wrangler", "Grand Cherokee"}
        );
        for (Object[] row : cars) {
            String makeName = (String) row[0];
            VehicleMake make = new VehicleMake();
            make.setName(makeName);
            make.setType("CAR");
            make.setImageUrl(PLACEHOLDER + makeName.replace(" ", "+"));
            make = vehicleMakeRepo.save(make);
            Long makeId = make.getId();
            for (int i = 1; i < row.length; i++) {
                String modelName = (String) row[i];
                VehicleModel m = new VehicleModel();
                m.setMakeId(makeId);
                m.setName(modelName);
                m.setImageUrl(PLACEHOLDER + modelName.replace(" ", "+"));
                vehicleModelRepo.save(m);
            }
        }
    }

    private void seedBikes() {
        List<Object[]> bikes = List.of(
            new Object[]{"Hero", "Splendor", "Passion", "Xtreme", "Karizma", "Xtec", "Destini", "Pleasure", "Mavrick"},
            new Object[]{"Honda", "Activa", "Shine", "Unicorn", "CB350", "CB300R", "Hornet", "Dio", "X Blade", "Africa Twin"},
            new Object[]{"Bajaj", "Pulsar", "Platina", "CT", "Dominar", "Avenger", "Chetak"},
            new Object[]{"TVS", "Apache", "Jupiter", "iQube", "Raider", "Ronin", "Sport", "NTorq"},
            new Object[]{"Royal Enfield", "Classic 350", "Hunter 350", "Meteor 350", "Himalayan", "Scram 411", "Bullet 350", "Interceptor 650", "Continental GT"},
            new Object[]{"Suzuki", "Access", "Burgman", "Gixxer", "V-Strom", "Avenis"},
            new Object[]{"Yamaha", "R15", "FZ", "MT-15", "Ray ZR", "Fascino", "Aerox"},
            new Object[]{"Ola", "S1", "S1 Pro", "S1 X"},
            new Object[]{"Ather", "450X", "450S", "450 Apex"}
        );
        for (Object[] row : bikes) {
            String makeName = (String) row[0];
            VehicleMake make = new VehicleMake();
            make.setName(makeName);
            make.setType("BIKE");
            make.setImageUrl(PLACEHOLDER + makeName.replace(" ", "+"));
            make = vehicleMakeRepo.save(make);
            Long makeId = make.getId();
            for (int i = 1; i < row.length; i++) {
                String modelName = (String) row[i];
                VehicleModel m = new VehicleModel();
                m.setMakeId(makeId);
                m.setName(modelName);
                m.setImageUrl(PLACEHOLDER + modelName.replace(" ", "+"));
                vehicleModelRepo.save(m);
            }
        }
    }
}
