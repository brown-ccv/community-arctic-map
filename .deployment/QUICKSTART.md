# Arctic Map Deployment - Quick Reference

## 🚀 Prerequisites Checklist

Before deploying, ensure you have:

- [ ] Docker installed and running
- [ ] Google Cloud SDK (gcloud) installed
- [ ] Active GCP project with billing enabled
- [ ] Required data files:
  - [ ] `backend/cpad.sqlite`
  - [ ] `backend/metadata.html`
  - [ ] `backend/zipped_shapefiles/` directory

## 🔑 Required Credentials

Obtain these before deployment:
1. **Mapbox Access Token**: https://account.mapbox.com/access-tokens/
2. **Google Sheet ID**: From your Google Sheet URL
3. **Google Sheet GID**: From your sheet tab URL parameter

## ⚡ Quick Deploy Commands

### 1. Setup (One-time)
```bash
# Set your project
export PROJECT_ID=your-project-id-here
gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable run.googleapis.com containerregistry.googleapis.com

# Authenticate Docker
gcloud auth configure-docker

# Create secrets
echo -n "YOUR_MAPBOX_TOKEN" | gcloud secrets create mapbox-access-token --data-file=-
echo -n "YOUR_SHEET_ID" | gcloud secrets create google-sheet-id --data-file=-
echo -n "YOUR_SHEET_GID" | gcloud secrets create google-sheet-gid --data-file=-
```

### 2. Build & Deploy
```bash
# Build image
docker build -f .deployment/Dockerfile -t gcr.io/$PROJECT_ID/arctic-map:latest .

# Push to GCR
docker push gcr.io/$PROJECT_ID/arctic-map:latest

# Deploy to Cloud Run
gcloud run deploy arctic-map \
  --image gcr.io/$PROJECT_ID/arctic-map:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080 \
  --memory 1Gi \
  --cpu 1 \
  --set-secrets="VITE_MAPBOX_ACCESS_TOKEN=mapbox-access-token:latest,GOOGLE_SHEET_ID=google-sheet-id:latest,GOOGLE_SHEET_GID=google-sheet-gid:latest"
```

### 3. Verify
```bash
# Get service URL
gcloud run services describe arctic-map --region us-central1 --format 'value(status.url)'

# Test health
curl $(gcloud run services describe arctic-map --region us-central1 --format 'value(status.url)')/health
```

## 📖 Full Documentation

For detailed instructions, troubleshooting, and advanced configuration:
- See `.deployment/DEPLOYMENT.md`

## 🆘 Common Issues

### Issue: Build fails with SSL errors
**Solution**: This is expected in sandboxed environments. The build will work correctly in Google Cloud Build.

### Issue: Service returns 502/503
**Solution**: Check logs: `gcloud run services logs read arctic-map --region us-central1 --limit 50`

### Issue: Missing data files
**Solution**: Ensure `cpad.sqlite`, `metadata.html`, and `zipped_shapefiles/` are in the `backend/` directory before building.

## 📞 Support

For issues or questions:
1. Check logs: `gcloud run services logs read arctic-map --region us-central1`
2. Review `.deployment/DEPLOYMENT.md`
3. Contact repository maintainers
