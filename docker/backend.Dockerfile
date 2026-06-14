# =============================================================================
# Production Backend Dockerfile Override
# =============================================================================
# Extends the base expense-backend/Dockerfile for OCI ARM deployment.
# Key differences:
#   - Optimized for ARM64 (oci Ampere A1)
#   - Production JVM tuning (Java 21)
#   - Non-root user security hardening
#
# Build:
#   docker build -t expense-backend:latest \
#     -f oci-deployment/docker/backend.Dockerfile \
#     expense-backend/
# =============================================================================

FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app

# Copy Maven wrapper and pom.xml for dependency caching
COPY pom.xml mvnw ./
COPY .mvn .mvn
RUN chmod +x mvnw && ./mvnw dependency:go-offline -B -q || true

# Copy source and build
COPY src ./src
RUN ./mvnw clean package -DskipTests -P prod -B -q

# Production runtime
FROM eclipse-temurin:21-jre
WORKDIR /app

# Create non-root user
RUN groupadd -r spring && useradd -r -g spring spring

# Copy built JAR
COPY --from=builder /app/target/*.jar /app/app.jar

# Copy Prometheus JMX exporter agent
COPY --from=builder /app/prometheus.yml /app/prometheus.yml 2>/dev/null || true

# Set ownership
RUN chown -R spring:spring /app

# Switch to non-root
USER spring:spring

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", \
    "-XX:+UseG1GC", \
    "-XX:MaxGCPauseMillis=200", \
    "-XX:+HeapDumpOnOutOfMemoryError", \
    "-XX:HeapDumpPath=/tmp/backend-heapdump.hprof", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-jar", "/app/app.jar" \
]