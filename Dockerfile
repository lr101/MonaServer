FROM openjdk:17-alpine
ARG JAR_FILE=target/*.jar
COPY target/MonaServer-2.jar MonaServer-2.jar
COPY keystore-ubuntu.p12 /keystore-ubuntu.p12
ENTRYPOINT exec java $JAVA_OPTS -jar /MonaServer-2.jar