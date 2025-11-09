# base image, alpine for smaller size
FROM node:22-alpine 

WORKDIR /app

# install dependencies
COPY package*.json ./
RUN npm install --production

# copy rest of the application
COPY . .

# expose the port
EXPOSE 3000

# start
CMD ["npm", "start"]