ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    bison flex autoconf automake perl libfl-dev help2man gcc g++ \
    && rm -rf /var/lib/apt/lists/*