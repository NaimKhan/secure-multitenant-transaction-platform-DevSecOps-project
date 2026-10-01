import os
import time
from fastapi import FastAPI, Header, HTTPException, Response
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(title="Axiler Multi-Tenant Platform Stubs")

# Instrument Prometheus Metrics
Instrumentator().instrument(app).expose(app)

RELEASE_VERSION = os.getenv("RELEASE_VERSION", "v1.0.0")
FAILURE_MODE = os.getenv("FAILURE_MODE", "false").lower() == "true"

@app.middleware("http")
async def check_failure_mode_and_tenant(request, call_next):
    if FAILURE_MODE and request.url.path != "/health":
        # Simulate bad deployment failure
        time.sleep(2)
        return Response(content="Internal Server Error - Failure Mode Active", status_code=500)
    response = await call_next(request)
    response.headers["X-Release-Version"] = RELEASE_VERSION
    return response

@app.get("/health")
def health():
    if FAILURE_MODE:
        raise HTTPException(status_code=500, detail="Unhealthy - Failure Mode Active")
    return {"status": "healthy", "version": RELEASE_VERSION}

@app.get("/search")
def search(x_tenant_id: str = Header(None, alias="X-Tenant-ID")):
    if not x_tenant_id or x_tenant_id not in ["Alpha", "Beta"]:
        raise HTTPException(status_code=403, detail="Forbidden: Invalid or Missing Tenant Identity")
    return {
        "tenant": x_tenant_id,
        "action": "search",
        "result": [{"account_id": "ACC-001", "balance": 50000}],
        "version": RELEASE_VERSION
    }

@app.post("/transfer")
def transfer(payload: dict, x_tenant_id: str = Header(None, alias="X-Tenant-ID")):
    if not x_tenant_id or x_tenant_id not in ["Alpha", "Beta"]:
        raise HTTPException(status_code=403, detail="Forbidden: Invalid or Missing Tenant Identity")
    return {
        "tenant": x_tenant_id,
        "action": "transfer",
        "status": "INITIATED",
        "transaction_id": "TXN-998231",
        "version": RELEASE_VERSION
    }
AWS_SECRET_KEY='AKIAIOSFODNN7EXAMPLE'
AWS_SECRET_KEY='AKIAIOSFODNN7EXAMPLE'
AWS_SECRET_KEY='AKIAIOSFODNN7EXAMPLE'
