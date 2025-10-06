package com.example.demo.controller;

import com.example.demo.model.Person;
import com.example.demo.repository.PersonRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@CrossOrigin(origins = "*") // allow Flutter requests
@RestController
@RequestMapping("/api/person")
public class PersonController {

    @Autowired
    private PersonRepo personRepo;

    @PostMapping
    public Person createPerson(@RequestBody Person person) {
        System.out.println("📥 Received Person data: " + person);
        System.out.println("📥 Name: " + person.getName());
        System.out.println("📥 Phone: " + person.getPhone());
        System.out.println("📥 Address: " + person.getAddress());
        System.out.println("📥 Charger Type: " + person.getChargerType());
        System.out.println("📥 Rate: " + person.getRate());
        System.out.println("📥 Available Hours: " + person.getAvailableHours());
        
        try {
            Person savedPerson = personRepo.save(person);
            System.out.println("✅ Person saved successfully with ID: " + savedPerson.getId());
            return savedPerson;
        } catch (Exception e) {
            System.err.println("❌ Error saving person: " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    @GetMapping
    public List<Person> getAllPersons() {
        System.out.println("📤 GET request received - fetching all persons");
        try {
            List<Person> persons = personRepo.findAll();
            System.out.println("📤 Found " + persons.size() + " persons in database");
            for (Person person : persons) {
                System.out.println("📤 Person: ID=" + person.getId() + ", Name=" + person.getName());
            }
            return persons;
        } catch (Exception e) {
            System.err.println("❌ Error fetching persons: " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    @GetMapping("/{id}")
    public Person getPersonById(@PathVariable Long id) {
        return personRepo.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Person updatePerson(@PathVariable Long id, @RequestBody Person person) {
        person.setId(id);
        return personRepo.save(person);
    }

    @DeleteMapping("/{id}")
    public void deletePerson(@PathVariable Long id) {
        personRepo.deleteById(id);
    }
}
