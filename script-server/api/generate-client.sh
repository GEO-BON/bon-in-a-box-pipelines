
wget --no-clobber https://repo1.maven.org/maven2/io/swagger/codegen/v3/swagger-codegen-cli/3.0.30/swagger-codegen-cli-3.0.30.jar
java --add-opens=java.base/java.util=ALL-UNNAMED -jar swagger-codegen-cli-3.0.30.jar generate -l javascript -i openapi.yaml -o ../../ui/BonInABoxScriptService
