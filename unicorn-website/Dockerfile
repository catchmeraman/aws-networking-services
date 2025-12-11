FROM nginx:alpine

# Copy actual Amplify website files
COPY index.html /usr/share/nginx/html/
COPY about.html /usr/share/nginx/html/
COPY reports.html /usr/share/nginx/html/
COPY cost-report.html /usr/share/nginx/html/
COPY s3-vectors.html /usr/share/nginx/html/
COPY s3-vectors-implementation.html /usr/share/nginx/html/
COPY amplify-unicorn-architecture.png /usr/share/nginx/html/
COPY requirements.txt /usr/share/nginx/html/
COPY document_vector_storage.py /usr/share/nginx/html/
COPY query_document_vectors.py /usr/share/nginx/html/
COPY upload_vectors.py /usr/share/nginx/html/
COPY S3_VECTORS_README.md /usr/share/nginx/html/
COPY sample-documents/ /usr/share/nginx/html/sample-documents/

# Create nginx config
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    location /health { \
        return 200 "OK"; \
        add_header Content-Type text/plain; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
