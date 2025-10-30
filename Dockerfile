# # Stage 1: Build stage
# FROM maven:3.9-eclipse-temurin-17 AS build

# # Set working directory
# WORKDIR /app

# # Copy pom.xml and download dependencies (cache this layer)
# COPY pom.xml .
# RUN mvn dependency:go-offline -B

# # Copy source code
# COPY src ./src

# # Build the application (skip tests for faster builds, tests run in CI)
# RUN mvn clean package -DskipTests -B

# # Stage 2: Runtime stage
# FROM eclipse-temurin:17-jre-alpine

# # Add metadata
# LABEL maintainer="vinothbalakrish"
# LABEL application="spring-petclinic"
# LABEL version="1.0"

# # Create non-root user for security
# RUN addgroup -S spring && adduser -S spring -G spring

# # Set working directory
# WORKDIR /app

# # Copy the JAR from build stage
# COPY --from=build /app/target/*.jar app.jar

# # Change ownership to non-root user
# RUN chown -R spring:spring /app

# # Switch to non-root user
# USER spring

# # Expose port 8080
# EXPOSE 8080

# # Health check
# HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
#   CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# # Run the application
# ENTRYPOINT ["java", "-jar", "app.jar"]


# Multi-stage build for smaller image size
FROM eclipse-temurin:25-jre-jammy as builder
WORKDIR /app
COPY target/*.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract

FROM eclipse-temurin:25-jre-jammy
WORKDIR /app

# Create non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

# Copy extracted layers from builder stage
COPY --from=builder /app/dependencies/ ./
COPY --from=builder /app/spring-boot-loader/ ./
COPY --from=builder /app/snapshot-dependencies/ ./
COPY --from=builder /app/application/ ./

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
