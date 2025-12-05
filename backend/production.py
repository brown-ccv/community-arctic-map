# Production startup configuration for serving frontend and API together
# This file is used in production to serve both the React frontend and FastAPI backend

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import sys

# Import the main app from main.py
sys.path.insert(0, os.path.dirname(__file__))
from main import app as main_app

# Check if running in production (frontend dist files exist)
FRONTEND_DIST = os.path.join(os.path.dirname(__file__), "..", "frontend", "dist")
IS_PRODUCTION = os.path.exists(FRONTEND_DIST)

if IS_PRODUCTION:
    print(f"[INFO] Running in PRODUCTION mode - serving frontend from {FRONTEND_DIST}")
    
    # Mount static files (assets like JS, CSS, images)
    main_app.mount("/assets", StaticFiles(directory=os.path.join(FRONTEND_DIST, "assets")), name="assets")
    
    # Serve index.html for all non-API routes (SPA routing)
    @main_app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        # If the path starts with /api, let FastAPI handle it
        if full_path.startswith("api/"):
            # FastAPI will handle this with existing routes
            return
        
        # Check if it's a static file request
        file_path = os.path.join(FRONTEND_DIST, full_path)
        if os.path.isfile(file_path):
            return FileResponse(file_path)
        
        # Otherwise serve index.html (for client-side routing)
        return FileResponse(os.path.join(FRONTEND_DIST, "index.html"))

else:
    print("[INFO] Running in DEVELOPMENT mode - frontend should be served separately via Vite")

# Export the app
app = main_app
