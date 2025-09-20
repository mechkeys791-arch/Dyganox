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
        return personRepo.save(person);
    }

    @GetMapping
    public List<Person> getAllPersons() {
        return personRepo.findAll();
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
