FROM python:2.7

# Add sample application
ADD application.py /tmp/application.py

EXPOSE 8000

RUN mkdir /tmp/sample-app

# Run it
ENTRYPOINT ["python", "/tmp/application.py"]
