# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore as distinct layers
COPY LoreshifterBackend/LoreshifterBackend.csproj ./
RUN dotnet restore "LoreshifterBackend.csproj"

# Copy everything else and build
COPY LoreshifterBackend/ .
RUN dotnet build "LoreshifterBackend.csproj" -c Release -o /app/build

# Publish the app
FROM build AS publish
RUN dotnet publish "LoreshifterBackend.csproj" -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the published app
COPY --from=publish /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://0.0.0.0:8000 \
    ASPNETCORE_ENVIRONMENT=Production

# Expose the port the app runs on
EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD wget -q -O - http://0.0.0.0:8000/api/v0/liveness || exit 1

# Set the entry point
ENTRYPOINT ["dotnet", "LoreshifterBackend.dll"]
