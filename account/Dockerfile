FROM python

RUN apt-get update && \
    apt-get install -y \
    vim \
    openssh-client \
    iputils-ping && \
	apt-get clean

RUN mkdir -p /app
WORKDIR /app

COPY ./account/ /app
RUN pip install --no-cache-dir -r requirements.txt

RUN chmod +x init

EXPOSE 5000
