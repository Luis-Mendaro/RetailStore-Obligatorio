FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
RUN useradd -m appuser && chown -R appuser:appuser /app
ENV CART_PERSISTENCE_PROVIDER=in-memory
ENV PORT=8080
EXPOSE 8080
USER appuser
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port $PORT"]
