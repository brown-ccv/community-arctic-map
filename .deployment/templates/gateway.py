"""
Community Arctic Map - Gateway Service
=======================================
This FastAPI application serves as a gateway that:
1. Serves the built React frontend as static files
2. Proxies API requests to backend services (main.py and zip_downloads.py)
3. Provides health check endpoint for Cloud Run
"""

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, JSONResponse
import httpx
import os

app = FastAPI(title="Community Arctic Map Gateway")

# Backend service URLs (internal)
BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://localhost:8000")
DOWNLOAD_API_URL = os.getenv("DOWNLOAD_API_URL", "http://localhost:8001")

# Create HTTP client for proxying requests
http_client = httpx.AsyncClient(timeout=30.0)


@app.get("/health")
async def health_check():
    """Health check endpoint for Cloud Run"""
    return {"status": "healthy", "service": "community-arctic-map"}


@app.api_route("/api/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy_api(path: str, request: Request):
    """Proxy all /api/* requests to the appropriate backend service"""
    
    # Determine which backend to proxy to based on path
    if path.startswith("shapefiles/"):
        target_url = f"{DOWNLOAD_API_URL}/api/{path}"
    else:
        target_url = f"{BACKEND_API_URL}/api/{path}"
    
    # Forward the request
    try:
        # Get query parameters
        query_params = dict(request.query_params)
        
        # Get request body if present
        body = None
        if request.method in ["POST", "PUT", "PATCH"]:
            body = await request.body()
        
        # Make the proxied request
        response = await http_client.request(
            method=request.method,
            url=target_url,
            params=query_params,
            content=body,
            headers={k: v for k, v in request.headers.items() 
                    if k.lower() not in ['host', 'content-length']},
        )
        
        # Return the response
        return JSONResponse(
            content=response.json() if response.headers.get('content-type', '').startswith('application/json') else response.text,
            status_code=response.status_code,
            headers=dict(response.headers)
        )
    except Exception as e:
        return JSONResponse(
            content={"error": str(e)},
            status_code=500
        )


# Mount static files for frontend (must be last)
app.mount("/assets", StaticFiles(directory="/app/frontend/dist/assets"), name="assets")


@app.get("/{full_path:path}")
async def serve_frontend(full_path: str):
    """Serve the React frontend for all non-API routes"""
    # Serve index.html for all routes (React Router will handle routing)
    return FileResponse("/app/frontend/dist/index.html")


@app.on_event("shutdown")
async def shutdown_event():
    """Close HTTP client on shutdown"""
    await http_client.aclose()
