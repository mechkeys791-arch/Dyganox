#!/bin/bash

# Test script for EV Charging Backend API

echo "Testing EV Charging Backend API..."

# Test POST request to create a new charging provider
echo "Creating a new charging provider..."
curl -X POST http://localhost:8081/api/person \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe Charging Station",
    "phone": "+1234567890",
    "address": "123 Main St, City, State",
    "chargerType": "Level 2",
    "rate": "$0.15/kWh",
    "availableHours": "24/7"
  }'

echo -e "\n\nTesting GET request to retrieve all providers..."
curl -X GET http://localhost:8081/api/person

echo -e "\n\nAPI test completed!"


