# Kubernetes-dev-infra-tester

- helps to bootstrap the following to run in kubernetes(e.g Docker Desktop) for easy testing
  - kaka
  - postgres
  - redis

# To Run

## kafka
- ./kubernetes/kafka/run.sh single-node [topic1, topic2, topic3 ...]

note: it could be ./kubernetes/kafka/run.sh three-node [topic1, topic2, topic3 ...]

## postgres
```bash
kubectl apply -f kubernetes/postgres/postgres-deployment.yml
```

To retain data across pod restarts, use the persistent deployment instead:
```bash
kubectl apply -f kubernetes/postgres/persistent-postgres-deployment.yml
```

## redis
```bash
kubectl apply -f kubernetes/redis/redis-deployment.yml
```

To retain data across pod restarts, use the persistent deployment instead:
```bash
kubectl apply -f kubernetes/redis/persistent-redis-deployment.yml
```

Choose either the standard or persistent deployment for each service; do not apply both.

# To Use

## kafka  -- see kubernetes/kafka/README.md
```yaml
spring:
  kafka:
    bootstrap-servers: kafka:9092
schema:
  registry:
    url: http://schema-registry:8081
```

## postgres
For a Spring Boot application running in the same Kubernetes namespace, `postgres-service` is the host for Postgres.
```yaml
spring:
  datasource:
    url: jdbc:postgresql://postgres-service:5432/postgres
    username: postgres
    password: admin
```

For an application running on your laptop, use `localhost` as the host when the LoadBalancer exposes port `5432` locally (e.g. Docker Desktop).

## redis
For a Spring Boot application running in the same Kubernetes namespace, `redis-service` is the host for Redis. No password is configured.
```yaml
spring:
  data:
    redis:
      host: redis-service
      port: 6379
```

For an application running on your laptop, use `localhost` as the host when the LoadBalancer exposes port `6379` locally (e.g. Docker Desktop).
