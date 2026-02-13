@echo off
curl -X POST http://localhost:5000/api/notifications/hod-decision -H "Content-Type: application/json" -d @test_payload.json
