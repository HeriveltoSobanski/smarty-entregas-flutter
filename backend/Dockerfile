# Stage 1: compilar para binário nativo
FROM dart:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get --no-example

COPY . .

RUN dart pub get --offline
RUN dart compile exe bin/backend.dart -o bin/server

# Stage 2: imagem mínima de produção
FROM debian:bullseye-slim

WORKDIR /app

COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8081

CMD ["/app/bin/server"]
