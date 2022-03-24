FROM mcr.microsoft.com/planetary-computer/python:latest
SHELL ["conda", "run", "-n", "notebook", "/bin/bash", "-c"]
RUN pip3 install appdirs geojson_rewind geomet requests_cache matplotlib python-dotenv
RUN pip3 install git+https://github.com/sckott/pygbif.git#egg=pygbif

# The code to run when container is started:
RUN python
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "notebook"]
