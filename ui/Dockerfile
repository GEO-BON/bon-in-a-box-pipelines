FROM node:16.13.1-alpine3.13

WORKDIR /app
ENV PATH /app/node_modules/.bin:$PATH

# Workaround with [] for file that is not always there : https://stackoverflow.com/a/46801962/3519951
COPY package.json package-lock.jso[n] ./
RUN npm install

COPY BonInABoxScriptService ./BonInABoxScriptService
RUN npm install ./BonInABoxScriptService

# Without this line, we get " EACCES: permission denied, open '/app/node_modules/.cache/.eslintcache' "
#RUN chown -R node:node ./node_modules

CMD ["npm", "start"]