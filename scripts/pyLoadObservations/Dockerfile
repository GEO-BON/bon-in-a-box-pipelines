FROM mcr.microsoft.com/planetary-computer/python:latest
SHELL ["conda", "run", "-n", "notebook", "/bin/bash", "-c"]
RUN pip3 install appdirs geojson_rewind geomet requests_cache matplotlib
RUN pip3 install git+git://github.com/sckott/pygbif.git#egg=pygbif

# Demonstrate the environment is activated:
RUN echo "Make sure pygbif is installed:"
RUN python -c "import pygbif"

# The code to run when container is started:
RUN python
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "notebook"]
