FROM python:3.11-buster as builder
WORKDIR /app
COPY . ./
# This is where one could build the application code as well.
RUN pip install -t . requests pysocks awslambdaric


FROM alpine:latest as tailscale
WORKDIR /app
COPY . ./
ENV TSFILE=tailscale_1.70.0_amd64.tgz
RUN wget https://pkgs.tailscale.com/stable/${TSFILE} && \
  tar xzf ${TSFILE} --strip-components=1
COPY . ./


FROM public.ecr.aws/lambda/python:3.11
# Copy binary to production image
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/local/bin/aws-lambda-rie
RUN chmod 755 /usr/local/bin/aws-lambda-rie
RUN pip3 install pysocks --target "${LAMBDA_TASK_ROOT}"
COPY --from=builder /app/bootstrap /var/runtime/bootstrap_ts.sh
COPY --from=builder /app/app.py ${LAMBDA_TASK_ROOT}
COPY --from=tailscale /app/tailscaled /var/runtime/tailscaled
COPY --from=tailscale /app/tailscale /var/runtime/tailscale
RUN mkdir -p /var/run && ln -s /tmp/tailscale /var/run/tailscale && \
    mkdir -p /var/cache && ln -s /tmp/tailscale /var/cache/tailscale && \
    mkdir -p /var/lib && ln -s /tmp/tailscale /var/lib/tailscale && \
    mkdir -p /var/task && ln -s /tmp/tailscale /var/task/tailscale

# Run on container startup.
ENTRYPOINT ["sh","/var/runtime/bootstrap_ts.sh"]
CMD [ "app.lambda_handler" ]
