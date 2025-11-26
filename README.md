# Arctic Map

For full documentation and setup instructions, please visit the [Wiki](https://github.com/soujanya957/arctic-map/wiki).

## 🚀 Deployment

The Arctic Map application is configured for deployment to Google Cloud Run. For detailed deployment instructions, see [.deployment/DEPLOYMENT.md](.deployment/DEPLOYMENT.md).

### Quick Deploy

```bash
# Build and push Docker image
docker build -f .deployment/Dockerfile -t gcr.io/YOUR_PROJECT_ID/arctic-map:latest .
docker push gcr.io/YOUR_PROJECT_ID/arctic-map:latest

# Deploy to Cloud Run
gcloud run deploy arctic-map \
  --image gcr.io/YOUR_PROJECT_ID/arctic-map:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 8080
```

See `.deployment/DEPLOYMENT.md` for comprehensive deployment instructions including:
- Prerequisites and setup
- Environment variable configuration
- Secret management
- Troubleshooting

## 🛠️ Local Development

### Frontend
```bash
cd frontend
npm install
npm run dev
```

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

For more details, see the [Wiki](https://github.com/soujanya957/arctic-map/wiki).

#### Developers:
Soujanya, Noreen

