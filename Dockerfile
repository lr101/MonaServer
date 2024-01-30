FROM maven:3.9.0-eclipse-temurin-17 AS build
COPY pom.xml /tmp/pom.xml
WORKDIR /tmp
RUN mvn -B -f /tmp/pom.xml dependency:resolve
COPY src /tmp/src
RUN mvn clean install

FROM eclipse-temurin:17
COPY --from=build /tmp/target/*jar /app/app.jar
ENTRYPOINT ["java","-jar","app.jar"]