FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /workspace
COPY gradlew gradlew
COPY gradle gradle
COPY settings.gradle build.gradle ./
RUN chmod +x gradlew
COPY src src
RUN ./gradlew clean bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S taskly && adduser -S taskly -G taskly
WORKDIR /app
COPY --from=build /workspace/build/libs/*.jar app.jar
USER taskly
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
