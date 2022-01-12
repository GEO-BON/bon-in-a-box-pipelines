# This runs a build without the rest of the dockers running.
docker run --rm -u gradle -v "$PWD":/home/gradle/project -w /home/gradle/project gradle:6.9.2-jdk11-alpine gradle check assemble
