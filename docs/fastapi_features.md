# Configure health check from backend/app/main.py
@app.get("/health")
async def health_check():
    return {"status": "healthy", "app": settings.APP_NAME}

# Provide Swagger UI (OpenAPI schema) based on your routes, decoratirs and Pydantic models by default when you initialize the FastAPI application.
app = FastAPI(
    title=settings.APP_NAME,
    description="Automated data reconciliation and compliance engine.",
    version="0.1.0",
)

# Example of custom path
app = FastAPI(docs_url="/api-docs")

# Example of disabling in production
app = FastAPI(docs_url=None if settings.ENVIRONMENT == "prod" else "/docs")


