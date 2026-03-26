# ── Stage 1: Build & Publish ───────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder

WORKDIR /app

# Restore dependencies first (layer cache optimisation)
COPY src/ECommerceAPI/ECommerceAPI.csproj src/ECommerceAPI/
RUN dotnet restore src/ECommerceAPI/ECommerceAPI.csproj \
    --runtime linux-musl-x64

# Copy source and publish
COPY . .
RUN dotnet publish src/ECommerceAPI/ECommerceAPI.csproj \
    --configuration Release \
    --runtime linux-musl-x64 \
    --self-contained false \
    --output /publish \
    -p:PublishSingleFile=false \
    -p:DebugType=None \
    -p:DebugSymbols=false

# ── Stage 2: Runtime ───────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

# Install ICU globalization (required by EF Core string comparisons)
RUN apk add --no-cache icu-libs tzdata

WORKDIR /app

# Non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

COPY --from=builder --chown=appuser:appgroup /publish .

USER appuser

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "ECommerceAPI.dll"]
