package com.example.dyganox

/**
 * Backend base URL for Accept/Reject API calls from native notification actions.
 * Must match the backend used by the Flutter app (see lib/services/api_config.dart).
 */
object ApiConstants {
    const val BASE_URL = "http://34.228.113.212:8081"
    const val MECHANIC_REQUESTS_PATH = "/api/mechanic-requests"
}
