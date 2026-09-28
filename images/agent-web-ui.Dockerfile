FROM oven/bun:1-alpine

WORKDIR /src
COPY examples/agent-web-ui ./examples/agent-web-ui
RUN cd examples/agent-web-ui \
    && sed -i 's|"file:../../client-sdk/typescript"|"^0.5.2"|' package.json \
    && rm bun.lock \
    && bun install \
    && bun run build

WORKDIR /src/examples/agent-web-ui
ENV HOME=/home/bun
USER bun
EXPOSE 3300
CMD ["bun", "run", "start", "--host", "0.0.0.0"]
