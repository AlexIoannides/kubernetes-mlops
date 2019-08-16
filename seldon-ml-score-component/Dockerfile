FROM python:3.6-slim
COPY . /app
WORKDIR /app
RUN pip install pipenv
RUN pipenv install
EXPOSE 5000

# Define environment variable
ENV MODEL_NAME MLScore
ENV API_TYPE REST
ENV SERVICE_TYPE MODEL
ENV PERSISTENCE 0

CMD pipenv run seldon-core-microservice $MODEL_NAME $API_TYPE --service-type $SERVICE_TYPE --persistence $PERSISTENCE
