# EV Charging Backend

Spring Boot backend for EV Charging Service Provider App with AWS RDS integration.

## Prerequisites

- Java 17 or higher
- Maven 3.6 or higher
- AWS RDS MySQL instance

## Setup Instructions

### 1. AWS RDS Setup
1. Create a MySQL RDS instance in AWS
2. Note down the endpoint, port, database name, username, and password
3. Update `src/main/resources/application.properties` with your RDS credentials

### 2. Database Configuration
Update the following in `application.properties`:
```properties
spring.datasource.url=jdbc:mysql://your-rds-endpoint.region.rds.amazonaws.com:3306/ev_charging_db
spring.datasource.username=your_username
spring.datasource.password=your_password
```

### 3. Run the Application
```bash
# Navigate to backend directory
cd backend

# Install dependencies
mvn clean install

# Run the application
mvn spring-boot:run
```

The application will start on `http://localhost:8080`

## API Endpoints

### Person (EV Charging Provider) Management
- `POST /api/person` - Create a new charging provider
- `GET /api/person` - Get all charging providers
- `GET /api/person/{id}` - Get charging provider by ID
- `PUT /api/person/{id}` - Update charging provider
- `DELETE /api/person/{id}` - Delete charging provider

## Database Schema

The `person` table will be automatically created with the following fields:
- `id` (Long, Primary Key, Auto-generated)
- `name` (String) - Provider name
- `phone` (String) - Contact phone
- `address` (String) - Service address
- `chargerType` (String) - Type of charger
- `rate` (String) - Charging rate
- `availableHours` (String) - Available hours

## CORS Configuration

The application is configured to allow requests from any origin for development purposes. For production, update the CORS configuration in `corsconfig.java`.


