from fastapi.testclient import TestClient
from fastapi_agent.main import app

def run_tests():
    print("--- Testing /command endpoint ---")
    
    with TestClient(app) as client:
        payload = {
            "operation_id": "op-test-123",
            "service": "test-service-1",
            "flake": "nixpkgs#hello"
        }
        
        print(f"Sending POST to /command with payload: {payload}")
        response = client.post("/command", json=payload)
        
        print("Status code:", response.status_code)
        print("Response JSON:", response.json())

if __name__ == "__main__":
    run_tests()
