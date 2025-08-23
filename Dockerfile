FROM nginx:1.24
COPY . /usr/share/nginx/html

# Use nginx default port 80
ENV PORT=80
EXPOSE 80