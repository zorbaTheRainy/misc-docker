FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY programs/app/package*.json ./
COPY programs/app/index.js ./

# Install dependencies
RUN npm install

# Copy application code
COPY programs/app/index.js .

# Expose port
EXPOSE 3000

# Start the application
CMD ["npm", "start"]