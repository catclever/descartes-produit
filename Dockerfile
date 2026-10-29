FROM ruby:3.3-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

# Install dependencies (descartes, llm_json and ruby_llm will be fetched from GitHub if not local)
RUN bundle install

EXPOSE 8089

HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8089/healthz || exit 1

CMD ["bundle", "exec", "bin/descartes-produit", "--port", "8089", "--host", "0.0.0.0"]
