FROM maven:3-amazoncorretto-17-alpine AS build
COPY pom.xml /tmp/pom.xml
WORKDIR /tmp
RUN mvn -B -f /tmp/pom.xml dependency:resolve
COPY src /tmp/src
COPY openapi /tmp/openapi
RUN mvn clean package

FROM eclipse-temurin:21
WORKDIR /app
COPY --from=build /tmp/target/*jar /app/app.jar
ENTRYPOINT ["java","-jar","app.jar"]