FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
ENV CART_PERSISTENCE_PROVIDER=in-memory
ENV PORT=8080
EXPOSE 8080
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port $PORT"]
