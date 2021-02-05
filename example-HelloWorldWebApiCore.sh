dotnet --version
dotnet new webapi -o HelloWorldWebApiCore
cd HelloWorldWebApiCore
dotnet run --urls=http://localhost:8080 # new console, curl localhost:8080/weatherforcast
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
ENTRYPOINT ["dotnet", "HelloWorldWebApiCore.dll"]
EOT

docker build -t gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet-webapi:v1 .
docker images
docker run -p 8080:8080 gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet-webapi:v1 # new console, curl localhost:8080/weatherforcast
docker push gcr.io/${GOOGLE_CLOUD_PROJECT}/hello-dotnet-webapi:v1

cat <<EOT >> webapicore.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapicore-service
  labels:
    app: webapicore
spec:
  ports:
  - port: 8080
    name: http
  selector:
    app: webapicore
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapicore-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapicore
      version: v1
  template:
    metadata:
      labels:
        app: webapicore
        version: v1
    spec:
      containers:
      - name: webapicore
        image: gcr.io/sixth-edition-102118/hello-dotnet-webapi:v1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
EOT

kubectl apply -f webapicore.yaml

# browse to http://34.66.146.243:8080/weatherforecast
