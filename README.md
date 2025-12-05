# Arctic Map

For full documentation and setup instructions, please visit the [Wiki](https://github.com/soujanya957/arctic-map/wiki).

## 🚀 Deployment

This repository is configured for deployment to Google Cloud Run. For complete deployment instructions, see:

**[📖 Deployment Guide](.deployment/DEPLOYMENT.md)**

### Quick Start

1. **Prerequisites**: Google Cloud account, GitHub account, `gcloud` and `gh` CLI tools
2. **Setup**: Run `.deployment/scripts/gcp/setup-service-account.sh`
3. **Deploy**: Use GitHub Actions workflow or manual deployment

The application includes:
- React + Vite frontend
- Python FastAPI backend (2 services)
- SQLite database (4.3 GB) - requires separate upload to Cloud Storage

For detailed step-by-step instructions, see the [Deployment Guide](.deployment/DEPLOYMENT.md).

---

#### Developers:
Soujanya, Noreen
