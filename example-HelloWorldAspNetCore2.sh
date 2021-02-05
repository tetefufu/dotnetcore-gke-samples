dotnet --version
dotnet new mvc -o HelloWorldAspNetCore
cd HelloWorldAspNetCore
dotnet run --urls=http://localhost:8080
touch Dockerfile

cat <<EOT >> Dockerfile
# Use Microsoft's official build .NET image.
# https://hub.docker.com/_/microsoft-dotnet-core-sdk/
FROM mcr.microsoft.com/dotnet/core/sdk:3.1-alpine AS build
WORKDIR /app

# Install production dependencies.
# Copy csproj and restore as distinct layers.
COPY *.csproj ./
RUN dotnet restore

# Copy local code to the container image.
COPY . ./
WORKDIR /app

# Build a release artifact.
RUN dotnet publish -c Release -o out

# Use Microsoft's official runtime .NET image.
# https://hub.docker.com/_/microsoft-dotnet-core-aspnet/
FROM mcr.microsoft.com/dotnet/core/aspnet:3.1-alpine AS runtime
WORKDIR /app
COPY --from=build /app/out ./

# Make sure the app binds to port 8080
ENV ASPNETCORE_URLS http://*:8080

# Run the web service on container startup.
ENTRYPOINT ["dotnet", "HelloWorldAspNetCore.dll"]
EOT

docker build -t gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet:v1 .
docker images
docker run -p 8080:8080 gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet:v1
docker push gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet:v1

cat <<EOT >> aspnetcore.yaml
apiVersion: v1
kind: Service
metadata:
  name: aspnetcore-service
  labels:
    app: aspnetcore
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: aspnetcore
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aspnetcore-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aspnetcore
      version: v1
  template:
    metadata:
      labels:
        app: aspnetcore
        version: v1
    spec:
      containers:
      - name: aspnetcore
        image: gcr.io/sixth-edition-102118/hello-dotnet:v1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
EOT

kubectl apply -f aspnetcore.yaml
