FROM julia:1.11

COPY importEnvVars.sh /importEnvVars.sh
RUN chmod a+x /importEnvVars.sh

# Setting the depot path, since we are installing the dependencies as root
# but running with a yet unknown non-root user.
ENV JULIA_DEPOT_PATH="/julia_depot/"

# Pre-compiling Julia dependencies
RUN julia --project=${JULIA_DEPOT_PATH} -e 'using Pkg; \
    Pkg.add.(["SpeciesDistributionToolkit", "CairoMakie", "ArchGDAL", "JSON", "CSV", "DataFrames", "EvoTrees" ]);'

    # TODO: Precompilation and cleanup of temp files
# RUN julia --project=${JULIA_DEPOT_PATH} -e 'pwd(); using Pkg; Pkg.instantiate(); Pkg.precompile()'

RUN chmod -R 777 /julia_depot

RUN date +"%Y-%m-%d %R" > /version.txt
