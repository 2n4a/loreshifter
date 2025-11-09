# Use .NET 8 SDK for development
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS development

# Set working directory
WORKDIR /app

# Install development tools
RUN dotnet tool install --tool-path /dotnet-tools dotnet-ef
ENV PATH="$PATH:/dotnet-tools"

# Copy project file and restore dependencies
COPY ["LoreshifterBackend/LoreshifterBackend.csproj", "."]
RUN dotnet restore "LoreshifterBackend.csproj"

# Copy everything else
COPY ["LoreshifterBackend/", "."]
COPY .env /

# Expose ports for the app and debugging
EXPOSE 8000

# Set environment variables for development
ENV ASPNETCORE_ENVIRONMENT=Development \
    ASPNETCORE_URLS="http://0.0.0.0:8000" \
    DOTNET_USE_POLLING_FILE_WATCHER=1 \
    DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    DB_HOST=db \
    DB_PORT=5432

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    procps \
    && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD wget -q -O - http://localhost:8000/api/v0/liveness || exit 1

# Set the entry point for development with hot reload
ENTRYPOINT ["dotnet", "run", "--project", "LoreshifterBackend.csproj", "--urls", "http://0.0.0.0:8000"]