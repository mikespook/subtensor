
ARG BASE_IMAGE=ubuntu:20.04

FROM $BASE_IMAGE as builder
SHELL ["/bin/bash", "-c"]

# This is being set so that no interactive components are allowed when updating.
ARG DEBIAN_FRONTEND=noninteractive

LABEL ai.opentensor.image.authors="operations@opentensor.ai" \
  ai.opentensor.image.vendor="Opentensor Foundation" \
  ai.opentensor.image.title="opentensor/subtensor" \
  ai.opentensor.image.description="Opentensor Subtensor Blockchain" \
  ai.opentensor.image.revision="${VCS_REF}" \
  ai.opentensor.image.created="${BUILD_DATE}" \
  ai.opentensor.image.documentation="https://docs.bittensor.com"

# show backtraces
ENV RUST_BACKTRACE 1

# Necessary libraries for Rust execution
RUN apt-get update
RUN apt-get install -y curl build-essential protobuf-compiler clang git
RUN rm -rf /var/lib/apt/lists/*

# Install cargo and Rust
RUN set -o pipefail && curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN mkdir -p /subtensor && \
  mkdir /subtensor/scripts

# Scripts
COPY ./scripts/init.sh /subtensor/scripts/

# Capture dependencies
COPY Cargo.lock Cargo.toml /subtensor/

# Specs
COPY ./snapshot.json /subtensor/snapshot.json
COPY ./raw_spec_finney.json /subtensor/raw_spec_finney.json
COPY ./raw_testspec.json /subtensor/raw_testspec.json

# Copy our sources
COPY ./node /subtensor/node
COPY ./pallets /subtensor/pallets
COPY ./runtime /subtensor/runtime

# Update to nightly toolchain
COPY rust-toolchain.toml /subtensor/
RUN /subtensor/scripts/init.sh

# Cargo build
WORKDIR /subtensor
RUN cargo build --release --features runtime-benchmarks --locked
EXPOSE 30333 9933 9944


FROM $BASE_IMAGE AS subtensor

COPY --from=builder /subtensor/snapshot.json /
COPY --from=builder /subtensor/raw_spec_finney.json /
COPY --from=builder /subtensor/raw_testspec.json /
COPY --from=builder /subtensor/target/release/node-subtensor /usr/local/bin

ENTRYPOINT ["/usr/local/bin/node-subtensor", "--chain=/raw_spec_finney.json" , "--bootnodes=/ip4/13.58.175.193/tcp/30333/p2p/12D3KooWDe7g2JbNETiKypcKT1KsCEZJbTzEHCn8hpd4PHZ6pdz5"]
