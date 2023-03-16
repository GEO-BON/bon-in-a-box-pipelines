# This runs a build without the rest of the dockers running.
docker run --rm -u gradle -v "$PWD":/home/gradle/project -w /home/gradle/project gradle:7.5.1-jdk11-alpine gradle build
