FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

COPY ./pom.xml ./

COPY ./src ./src

RUN mvn clean package -DskipTests



FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=build /build/target/*.jar app.jar

EXPOSE 80

CMD ["java", "-jar", "app.jar"]