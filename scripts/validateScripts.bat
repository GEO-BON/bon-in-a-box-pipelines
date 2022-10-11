docker run -v %cd%:"/scripts" navikt/yaml-validator:v4 "scripts/cerberusValidationSchema" "scripts/" "no" ".yml"
pause