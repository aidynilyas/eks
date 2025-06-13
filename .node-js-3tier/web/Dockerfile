# Use a slim Node.js 18 image (node:18-alpine is generally better for production)
FROM node:18

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json first to leverage Docker layer caching
COPY package*.json .

# Install dependencies (use --production for production images)
RUN npm install --production

# Copy the rest of the application code
COPY . .

# Expose the port your application listens on (e.g., 3000)
# This is for informational purposes and doesn't publish the port.
EXPOSE 3000

# Command to run the application.
# Make sure your package.json has a "start" script that runs your web app.
CMD ["npm", "start"]