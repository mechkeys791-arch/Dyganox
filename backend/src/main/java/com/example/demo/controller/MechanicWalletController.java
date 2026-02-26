package com.example.demo.controller;

import com.example.demo.model.MechanicWallet;
import com.example.demo.repository.MechanicWalletRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Optional;

@RestController
@RequestMapping("/api/mechanic-wallet")
@CrossOrigin(origins = "*")
public class MechanicWalletController {

    @Autowired
    private MechanicWalletRepo mechanicWalletRepo;

    @GetMapping("/{mechanicId}")
    public ResponseEntity<MechanicWallet> getWallet(@PathVariable Long mechanicId) {
        Optional<MechanicWallet> opt = mechanicWalletRepo.findByMechanicId(mechanicId);
        if (opt.isPresent()) return ResponseEntity.ok(opt.get());
        MechanicWallet w = new MechanicWallet(mechanicId);
        w = mechanicWalletRepo.save(w);
        return ResponseEntity.ok(w);
    }
}
