FROM python:3.12

RUN pip install pandas

COPY *.py /

CMD ["python", "/testing.py"]