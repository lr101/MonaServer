FROM maven:3.9.9-eclipse-temurin-17 AS build
COPY pom.xml /tmp/pom.xml
WORKDIR /tmp
RUN mvn -B -f /tmp/pom.xml dependency:resolve
COPY src /tmp/src
COPY openapi /tmp/openapi
RUN mvn clean install

FROM eclipse-temurin:17
WORKDIR /app
COPY --from=build /tmp/target/*jar /app/app.jar
ENTRYPOINT ["java","-jar","app.jar"]