import pytest
from fastapi.testclient import TestClient
from main import app, service_locks, service_pids
import asyncio

@pytest.fixture
def client():
    # Clean up state before each test
    service_locks.clear()
    service_pids.clear()
    with TestClient(app) as test_client:
        yield test_client

def test_command_success(client):
    """Test normal successful subprocess spawn."""
    payload = {
        "operation_id": "op-1",
        "service": "success-svc",
        "flake": "nixpkgs#hello"
    }
    res = client.post("/command", json=payload)
    
    assert res.status_code == 200
    assert res.json() == {"status": "accepted"}
    assert "success-svc" in service_pids

def test_command_already_running(client):
    """Test already running rejection."""
    class MockLockedLock:
        def locked(self):
            return True
            
    service_locks["locked-svc"] = MockLockedLock()
    
    payload = {
        "operation_id": "op-3",
        "service": "locked-svc",
        "flake": "nixpkgs#long-running"
    }
    res = client.post("/command", json=payload)
    
    assert res.status_code == 200
    assert res.json() == {"status": "already running"}
