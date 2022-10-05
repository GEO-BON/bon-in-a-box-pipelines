<<<<<<< Updated upstream
docker run -v %cd%:"/scripts" navikt/yaml-validator:v4 "scripts/cerberusValidationSchema" "scripts/" "no" ".yml"
=======
docker run -v %cd%:"/scripts" navikt/yaml-validator:v4 "scripts/validationSchema" "scripts/" "no" ".yml"
>>>>>>> Stashed changes
pause